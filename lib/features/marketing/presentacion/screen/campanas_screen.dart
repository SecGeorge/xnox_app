import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/cliente_destinatario.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/plantilla_mensaje.dart';
import 'package:xnox_app/features/marketing/presentacion/controlador/controlador_mensajeria.dart';
import 'package:xnox_app/features/marketing/presentacion/screen/cola_envio_screen.dart';
import 'package:xnox_app/features/marketing/presentacion/screen/historial_campanas_screen.dart';
import 'package:xnox_app/features/marketing/presentacion/screen/plantillas_screen.dart';

class CampanasScreen extends StatefulWidget {
  const CampanasScreen({super.key});

  @override
  State<CampanasScreen> createState() => _CampanasScreenState();
}

class _CampanasScreenState extends State<CampanasScreen> {
  final _controlador = ControladorMensajeria();
  final _mensajeCtrl = TextEditingController();

  // Datasets cargados bajo demanda.
  List<ClienteDestinatario> _generales = []; // estado 0 (activos/deudores/sin contrato)
  List<ClienteDestinatario> _vencidos = []; // estado 7
  bool _vencidosCargados = false;

  List<PlantillaMensaje> _plantillas = [];
  bool _cargando = true; // carga inicial (generales + plantillas)
  bool _cargandoDataset = false; // carga perezosa de vencidos

  FiltroCampania _filtro = FiltroCampania.todos;
  String? _tipoFiltro;
  PlantillaMensaje? _plantillaSel;
  String _busqueda = '';
  final Set<int> _seleccionados = {};

  // Paginación
  static const int _porPagina = 50;
  int _pagina = 0;

  @override
  void initState() {
    super.initState();
    _cargarInicial();
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarInicial() async {
    setState(() => _cargando = true);
    try {
      final resultados = await Future.wait([
        _controlador.buscarClientes(estado: 0),
        _controlador.listarPlantillas(),
      ]);
      if (!mounted) return;
      setState(() {
        _generales = resultados[0] as List<ClienteDestinatario>;
        _plantillas = resultados[1] as List<PlantillaMensaje>;
        _cargando = false;
      });
      _seleccionarTodosVisibles();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudieron cargar los datos',
          tipo: TipoMensaje.error);
    }
  }

  /// Carga los vencidos solo la primera vez que se necesitan.
  Future<void> _cargarVencidos() async {
    if (_vencidosCargados) return;
    setState(() => _cargandoDataset = true);
    try {
      final lista = await _controlador.buscarClientes(estado: 7);
      if (!mounted) return;
      setState(() {
        _vencidos = lista;
        _vencidosCargados = true;
        _cargandoDataset = false;
      });
      _seleccionarTodosVisibles();
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargandoDataset = false);
      mostrarMensaje(context, 'No se pudieron cargar los vencidos',
          tipo: TipoMensaje.error);
    }
  }

  DateTime get _hoy {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  /// Dataset activo según el filtro (los vencidos viven en su propia consulta).
  List<ClienteDestinatario> get _dataset =>
      _filtro == FiltroCampania.vencidos ? _vencidos : _generales;

  List<ClienteDestinatario> get _clientesFiltrados {
    final q = _busqueda.toLowerCase();
    return _dataset.where((c) {
      final coincideFiltro = c.coincideFiltro(_filtro, _hoy);
      final coincideBusqueda = q.isEmpty ||
          c.nombre.toLowerCase().contains(q) ||
          c.telefono.contains(q);
      return coincideFiltro && coincideBusqueda;
    }).toList();
  }

  int _conteoFiltro(FiltroCampania f) {
    final base = f == FiltroCampania.vencidos ? _vencidos : _generales;
    return base.where((c) => c.coincideFiltro(f, _hoy)).length;
  }

  List<PlantillaMensaje> get _plantillasFiltradas {
    if (_tipoFiltro == null) return _plantillas;
    return _plantillas.where((p) => p.tipo == _tipoFiltro).toList();
  }

  List<ClienteDestinatario> get _destinatarios => _clientesFiltrados
      .where((c) => _seleccionados.contains(c.id) && c.tieneTelefono)
      .toList();

  // -- Paginación de la lista filtrada --
  int get _totalPaginas {
    final n = _clientesFiltrados.length;
    return n == 0 ? 1 : ((n - 1) ~/ _porPagina) + 1;
  }

  List<ClienteDestinatario> get _clientesPagina {
    final filtrados = _clientesFiltrados;
    final inicio = _pagina * _porPagina;
    if (inicio >= filtrados.length) return [];
    final fin = (inicio + _porPagina).clamp(0, filtrados.length);
    return filtrados.sublist(inicio, fin);
  }

  ClienteDestinatario? get _clienteMuestra {
    final visibles = _clientesFiltrados;
    final sel = visibles.where((c) => _seleccionados.contains(c.id));
    if (sel.isNotEmpty) return sel.first;
    return visibles.isNotEmpty ? visibles.first : null;
  }

  String get _mensajePreview {
    final base = _mensajeCtrl.text;
    if (base.trim().isEmpty) return 'Escribe un mensaje o elige una plantilla…';
    final c = _clienteMuestra;
    return c != null ? c.generarMensaje(base) : base;
  }

  void _seleccionarTodosVisibles() {
    setState(() {
      _seleccionados
        ..clear()
        ..addAll(_clientesFiltrados.map((c) => c.id).whereType<int>());
    });
  }

  Future<void> _cambiarFiltro(FiltroCampania f) async {
    setState(() {
      _filtro = f;
      _pagina = 0;
    });
    if (f == FiltroCampania.vencidos && !_vencidosCargados) {
      await _cargarVencidos();
    } else {
      _seleccionarTodosVisibles();
    }
  }

  void _iniciarEnvio() {
    final destinatarios = _destinatarios;
    if (destinatarios.isEmpty) {
      mostrarMensaje(context, 'Selecciona al menos un cliente con teléfono',
          tipo: TipoMensaje.advertencia);
      return;
    }
    if (_mensajeCtrl.text.trim().isEmpty) {
      mostrarMensaje(context, 'Escribe un mensaje', tipo: TipoMensaje.advertencia);
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ColaEnvioScreen(
          clientes: destinatarios,
          mensajeBase: _mensajeCtrl.text,
          plantilla: _plantillaSel,
          filtroEtiqueta: _filtro.etiqueta,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Envío de mensajes'),
        actions: [
          IconButton(
            tooltip: 'Plantillas',
            icon: const Icon(Icons.text_snippet_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PlantillasScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Historial',
            icon: const Icon(Icons.history),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const HistorialCampanasScreen()),
            ),
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(child: _buildContenido()),
                _buildBarraInferior(),
              ],
            ),
    );
  }

  Widget _buildContenido() {
    final pagina = _clientesPagina;
    final totalFiltrados = _clientesFiltrados.length;
    // itemCount: header + clientes de la página + footer de paginación
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: pagina.length + 2,
      itemBuilder: (ctx, i) {
        if (i == 0) return _buildSecciones(totalFiltrados);
        if (i <= pagina.length) return _buildClienteTile(pagina[i - 1]);
        return _buildPaginacion(totalFiltrados);
      },
    );
  }

  // -------------------------------------------------------- Secciones (header)
  Widget _buildSecciones(int totalFiltrados) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tituloPaso('1', 'Filtrar clientes'),
          const SizedBox(height: AppEspaciado.sm),
          _buildFiltros(),
          const SizedBox(height: AppEspaciado.lg),

          _tituloPaso('2', 'Plantilla y mensaje'),
          const SizedBox(height: AppEspaciado.sm),
          _buildTiposPlantilla(),
          const SizedBox(height: AppEspaciado.sm),
          _buildSelectorPlantilla(),
          const SizedBox(height: AppEspaciado.sm + 4),
          TextField(
            controller: _mensajeCtrl,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'Mensaje',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          _buildPreview(),
          const SizedBox(height: AppEspaciado.lg),

          _tituloPaso('3', 'Seleccionar clientes'),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              Text('${_destinatarios.length} seleccionados de $totalFiltrados',
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColores.textoPrincipal)),
              const Spacer(),
              TextButton(
                onPressed: _seleccionados.isEmpty
                    ? _seleccionarTodosVisibles
                    : () => setState(() => _seleccionados.clear()),
                child: Text(
                    _seleccionados.isEmpty ? 'Seleccionar todos' : 'Quitar todos'),
              ),
            ],
          ),
          TextField(
            onChanged: (v) => setState(() {
              _busqueda = v;
              _pagina = 0;
            }),
            decoration: const InputDecoration(
              hintText: 'Buscar cliente',
              prefixIcon: Icon(Icons.search),
              isDense: true,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          if (_cargandoDataset)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppEspaciado.lg),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (totalFiltrados == 0)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppEspaciado.lg),
              child: EstadoVacio(
                  icono: Icons.people_outline,
                  mensaje: 'No hay clientes para este filtro.'),
            ),
        ],
      ),
    );
  }

  Widget _tituloPaso(String n, String titulo) {
    return Row(
      children: [
        CircleAvatar(
          radius: 13,
          backgroundColor: AppColores.primario,
          child: Text(n,
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        const SizedBox(width: AppEspaciado.sm),
        Text(titulo,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColores.primario)),
      ],
    );
  }

  Widget _buildFiltros() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: FiltroCampania.values.map((f) {
        final sel = _filtro == f;
        final esVencidosSinCargar =
            f == FiltroCampania.vencidos && !_vencidosCargados;
        final etiqueta =
            esVencidosSinCargar ? f.etiqueta : '${f.etiqueta}  ${_conteoFiltro(f)}';
        return FilterChip(
          selected: sel,
          onSelected: (_) => _cambiarFiltro(f),
          showCheckmark: false,
          avatar: esVencidosSinCargar
              ? Icon(Icons.cloud_download_outlined,
                  size: 16, color: sel ? Colors.white : AppColores.primario)
              : null,
          label: Text(etiqueta),
          selectedColor: AppColores.primario,
          backgroundColor: AppColores.superficie,
          side: const BorderSide(color: AppColores.borde),
          labelStyle: TextStyle(
            color: sel ? Colors.white : AppColores.primario,
            fontWeight: FontWeight.w600,
            fontSize: 12.5,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTiposPlantilla() {
    final tipos = <String?>[null, ...kTiposPlantilla];
    return Wrap(
      spacing: 8,
      children: tipos.map((t) {
        final sel = _tipoFiltro == t;
        return ChoiceChip(
          label: Text(t ?? 'Todas'),
          selected: sel,
          onSelected: (_) => setState(() {
            _tipoFiltro = t;
            if (_plantillaSel != null && t != null && _plantillaSel!.tipo != t) {
              _plantillaSel = null;
            }
          }),
          selectedColor: AppColores.primario,
          backgroundColor: AppColores.superficie,
          side: const BorderSide(color: AppColores.borde),
          labelStyle: TextStyle(
            color: sel ? Colors.white : AppColores.primario,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSelectorPlantilla() {
    return DropdownButtonFormField<PlantillaMensaje>(
      initialValue:
          _plantillasFiltradas.contains(_plantillaSel) ? _plantillaSel : null,
      isExpanded: true,
      decoration: const InputDecoration(labelText: 'Plantilla', isDense: true),
      hint: const Text('Elegir plantilla'),
      items: _plantillasFiltradas
          .map((p) => DropdownMenuItem(
                value: p,
                child: Row(
                  children: [
                    Expanded(
                        child: Text(p.nombre, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 6),
                    EtiquetaEstado(
                        texto: p.tipo, color: colorTipoPlantilla(p.tipo)),
                  ],
                ),
              ))
          .toList(),
      onChanged: (p) => setState(() {
        _plantillaSel = p;
        if (p != null) _mensajeCtrl.text = p.contenido;
      }),
    );
  }

  Widget _buildPreview() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: const Color(0xFFE5DDD5),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('Vista previa',
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF5A6B7B))),
              const Spacer(),
              if (_clienteMuestra != null)
                Text('ej: ${_clienteMuestra!.nombre}',
                    style:
                        const TextStyle(fontSize: 11, color: Color(0xFF5A6B7B))),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              constraints: const BoxConstraints(maxWidth: 320),
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              decoration: BoxDecoration(
                color: const Color(0xFFDCF8C6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(_mensajePreview,
                  style: const TextStyle(fontSize: 14, height: 1.35)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClienteTile(ClienteDestinatario c) {
    final sel = _seleccionados.contains(c.id);
    void toggle() => setState(() {
          if (sel) {
            _seleccionados.remove(c.id);
          } else if (c.id != null) {
            _seleccionados.add(c.id!);
          }
        });
    return Padding(
      padding:
          const EdgeInsets.symmetric(horizontal: AppEspaciado.md, vertical: 3),
      child: Material(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
          onTap: toggle,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
              border: Border.all(
                  color: sel ? AppColores.primario : AppColores.borde,
                  width: sel ? 1.4 : 1),
            ),
            child: Row(
              children: [
                Checkbox(
                  value: sel,
                  activeColor: AppColores.primario,
                  onChanged: (_) => toggle(),
                ),
                CircleAvatar(
                  radius: 16,
                  backgroundColor: AppColores.fondo,
                  child: Text(c.iniciales,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColores.primario)),
                ),
                const SizedBox(width: AppEspaciado.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(c.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      Row(
                        children: [
                          Icon(
                            c.tieneTelefono ? Icons.phone : Icons.phone_disabled,
                            size: 12,
                            color: c.tieneTelefono
                                ? AppColores.textoSecundario
                                : AppColores.error,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            c.tieneTelefono ? c.telefono : 'Sin teléfono',
                            style: TextStyle(
                              fontSize: 12,
                              color: c.tieneTelefono
                                  ? AppColores.textoSecundario
                                  : AppColores.error,
                            ),
                          ),
                          if (c.debe > 0) ...[
                            const SizedBox(width: 8),
                            Text('S/ ${c.debe.toStringAsFixed(2)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: AppColores.error)),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPaginacion(int totalFiltrados) {
    if (totalFiltrados <= _porPagina) return const SizedBox(height: 8);
    final desde = _pagina * _porPagina + 1;
    final hasta = (_pagina * _porPagina + _porPagina).clamp(0, totalFiltrados);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, AppEspaciado.sm, AppEspaciado.md, AppEspaciado.md),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            onPressed:
                _pagina > 0 ? () => setState(() => _pagina--) : null,
            icon: const Icon(Icons.chevron_left),
            color: AppColores.primario,
          ),
          Text('$desde–$hasta de $totalFiltrados   ·   pág. ${_pagina + 1}/$_totalPaginas',
              style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColores.textoSecundario)),
          IconButton(
            onPressed: _pagina + 1 < _totalPaginas
                ? () => setState(() => _pagina++)
                : null,
            icon: const Icon(Icons.chevron_right),
            color: AppColores.primario,
          ),
        ],
      ),
    );
  }

  Widget _buildBarraInferior() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: const BoxDecoration(
        color: AppColores.superficie,
        border: Border(top: BorderSide(color: AppColores.borde)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _iniciarEnvio,
            icon: const Icon(Icons.send),
            label: Text('Iniciar envío (${_destinatarios.length})'),
          ),
        ),
      ),
    );
  }
}
