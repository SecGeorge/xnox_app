import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';

class MiembrosScreen extends StatefulWidget {
  const MiembrosScreen({super.key});

  @override
  State<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends State<MiembrosScreen> {
  final _controlador = ControladorMiembros();

  List<Miembro> _miembros = [];
  bool _cargando = true;
  String? _error;

  // null = "Todos"
  EstadoMiembro? _filtro;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarMiembros();
  }

  Future<void> _cargarMiembros() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final miembros = await _controlador.buscarMiembros();
      if (!mounted) return;
      setState(() {
        _miembros = miembros;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los miembros';
        _cargando = false;
      });
      mostrarMensaje(context, 'Error al cargar miembros: $e',
          tipo: TipoMensaje.error);
    }
  }

  List<Miembro> get _filtrados {
    return _miembros.where((m) {
      final coincideEstado = _filtro == null || m.estado == _filtro;
      final coincideBusqueda = _busqueda.isEmpty ||
          m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          m.documento.contains(_busqueda);
      return coincideEstado && coincideBusqueda;
    }).toList();
  }

  int _conteo(EstadoMiembro? estado) {
    if (estado == null) return _miembros.length;
    return _miembros.where((m) => m.estado == estado).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros'),
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, AppEspaciado.sm),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o documento',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          // Filtros de estado
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
              children: [
                _chipFiltro('Todos', null),
                _chipFiltro('Activos', EstadoMiembro.activo),
                _chipFiltro('Deudores', EstadoMiembro.deudor),
                _chipFiltro('Morosos', EstadoMiembro.moroso),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Expanded(child: _buildContenido(filtrados)),
        ],
      ),
    );
  }

  Widget _buildContenido(List<Miembro> filtrados) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return RefreshIndicator(
        onRefresh: _cargarMiembros,
        child: ListView(
          children: [
            const SizedBox(height: 120),
            const EstadoVacio(
              icono: Icons.cloud_off_outlined,
              mensaje: 'No se pudieron cargar los miembros.\nDesliza para reintentar.',
            ),
          ],
        ),
      );
    }
    if (filtrados.isEmpty) {
      return RefreshIndicator(
        onRefresh: _cargarMiembros,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            EstadoVacio(
              icono: Icons.people_outline,
              mensaje: 'No hay miembros en esta categoría',
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _cargarMiembros,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppEspaciado.md, 0, AppEspaciado.md, AppEspaciado.lg),
        itemCount: filtrados.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppEspaciado.sm + 4),
        itemBuilder: (_, i) => _tarjetaMiembro(filtrados[i]),
      ),
    );
  }

  Widget _chipFiltro(String etiqueta, EstadoMiembro? estado) {
    final seleccionado = _filtro == estado;
    final color = estado?.color ?? AppColores.primario;
    return Padding(
      padding: const EdgeInsets.only(right: AppEspaciado.sm),
      child: ChoiceChip(
        label: Text('$etiqueta (${_conteo(estado)})'),
        selected: seleccionado,
        onSelected: (_) => setState(() => _filtro = estado),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColores.textoSecundario,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        backgroundColor: AppColores.superficie,
        selectedColor: color,
        side: BorderSide(
          color: seleccionado ? color : AppColores.borde,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _tarjetaMiembro(Miembro m) {
    final fecha = m.fechaVencimiento != null
        ? DateFormat('dd MMM yyyy', 'es').format(m.fechaVencimiento!)
        : 'Sin contrato';
    return TarjetaApp(
      onTap: () {},
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: m.estado.color.withValues(alpha: 0.15),
            child: Text(
              m.iniciales,
              style: TextStyle(
                color: m.estado.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${m.plan} · DNI ${m.documento}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                // Wrap y no Row: con nombres largos la columna se estrecha y
                // "Vence + saldo" no entraban en una línea (desbordaba). Así el
                // saldo baja a la siguiente línea en vez de recortarse.
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.event,
                            size: 14, color: AppColores.textoSecundario),
                        const SizedBox(width: 4),
                        Text(
                          'Vence: $fecha',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                    if (m.saldoPendiente > 0)
                      Text(
                        'S/ ${m.saldoPendiente.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: m.estado.color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          EtiquetaEstado(texto: m.etiquetaEstado, color: m.estado.color),
        ],
      ),
    );
  }
}
