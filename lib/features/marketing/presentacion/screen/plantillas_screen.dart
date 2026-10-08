import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/plantilla_mensaje.dart';
import 'package:xnox_app/features/marketing/presentacion/controlador/controlador_mensajeria.dart';

class PlantillasScreen extends StatefulWidget {
  const PlantillasScreen({super.key});

  @override
  State<PlantillasScreen> createState() => _PlantillasScreenState();
}

class _PlantillasScreenState extends State<PlantillasScreen> {
  final _controlador = ControladorMensajeria();
  List<PlantillaMensaje> _plantillas = [];
  bool _cargando = true;
  String? _tipoFiltro; // null = todas

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final lista = await _controlador.listarPlantillas();
      if (!mounted) return;
      setState(() {
        _plantillas = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(
        context,
        'No se pudieron cargar las plantillas',
        tipo: TipoMensaje.error,
      );
    }
  }

  List<PlantillaMensaje> get _filtradas {
    if (_tipoFiltro == null) return _plantillas;
    return _plantillas.where((p) => p.tipo == _tipoFiltro).toList();
  }

  Future<void> _abrirFormulario([PlantillaMensaje? plantilla]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _FormPlantillaScreen(plantilla: plantilla),
      ),
    );
    if (guardado == true) _cargar();
  }

  Future<void> _eliminar(PlantillaMensaje p) async {
    final ok = await confirmarDialog(
      context,
      titulo: '¿Eliminar plantilla?',
      mensaje: p.nombre,
      icono: Icons.delete_outline,
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok || p.id == null) return;
    final eliminado = await _controlador.eliminarPlantilla(p.id!);
    if (!mounted) return;
    if (eliminado) {
      mostrarMensaje(context, 'Plantilla eliminada', tipo: TipoMensaje.exito);
      _cargar();
    } else {
      mostrarMensaje(context, 'No se pudo eliminar', tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _abrirFormulario(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Nueva'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppEspaciado.md,
                AppEspaciado.md,
                AppEspaciado.md,
                0,
              ),
              child: CabeceraApp(
                titulo: 'Plantillas',
                subtitulo: 'Mensajes de WhatsApp listos para usar',
              ),
            ),
            _buildFiltros(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _filtradas.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(AppEspaciado.md),
                      child: VacioApp(
                        icono: Icons.text_snippet_rounded,
                        titulo: 'No hay plantillas en esta categoría',
                        texto: 'Crea una con el botón "Nueva".',
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _cargar,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppEspaciado.md,
                          AppEspaciado.sm,
                          AppEspaciado.md,
                          96,
                        ),
                        itemCount: _filtradas.length,
                        separatorBuilder: (_, _) =>
                            const SizedBox(height: AppEspaciado.sm + 4),
                        itemBuilder: (_, i) => _tarjeta(_filtradas[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltros() {
    final tipos = <String?>[null, ...kTiposPlantilla];
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md,
          AppEspaciado.md,
          AppEspaciado.md,
          8,
        ),
        itemCount: tipos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = tipos[i];
          final sel = _tipoFiltro == t;
          return ChipApp(
            texto: t ?? 'Todas',
            activo: sel,
            onTap: () => setState(() => _tipoFiltro = t),
          );
        },
      ),
    );
  }

  Widget _tarjeta(PlantillaMensaje p) {
    return TarjetaApp(
      onTap: () => _abrirFormulario(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.nombre,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              EtiquetaEstado(texto: p.tipo, color: colorTipoPlantilla(p.tipo)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            p.contenido,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 13,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _abrirFormulario(p),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Editar'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColores.primario,
                ),
              ),
              TextButton.icon(
                onPressed: () => _eliminar(p),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Eliminar'),
                style: TextButton.styleFrom(foregroundColor: AppColores.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ===========================================================================
// Formulario de creación / edición de plantilla
// ===========================================================================
class _FormPlantillaScreen extends StatefulWidget {
  final PlantillaMensaje? plantilla;
  const _FormPlantillaScreen({this.plantilla});

  @override
  State<_FormPlantillaScreen> createState() => _FormPlantillaScreenState();
}

class _FormPlantillaScreenState extends State<_FormPlantillaScreen> {
  final _controlador = ControladorMensajeria();
  final _nombreCtrl = TextEditingController();
  final _contenidoCtrl = TextEditingController();
  String _tipo = 'Recordatorio';
  bool _guardando = false;

  bool get _esEdicion => widget.plantilla != null;

  @override
  void initState() {
    super.initState();
    final p = widget.plantilla;
    if (p != null) {
      _nombreCtrl.text = p.nombre;
      _contenidoCtrl.text = p.contenido;
      _tipo = p.tipo;
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _contenidoCtrl.dispose();
    super.dispose();
  }

  /// Inserta una variable en la posición del cursor del campo contenido.
  void _insertarVariable(String variable) {
    final texto = _contenidoCtrl.text;
    final sel = _contenidoCtrl.selection;
    final inicio = sel.start < 0 ? texto.length : sel.start;
    final fin = sel.end < 0 ? texto.length : sel.end;
    final nuevo = texto.replaceRange(inicio, fin, variable);
    _contenidoCtrl.value = TextEditingValue(
      text: nuevo,
      selection: TextSelection.collapsed(offset: inicio + variable.length),
    );
  }

  Future<void> _guardar() async {
    if (_nombreCtrl.text.trim().isEmpty || _contenidoCtrl.text.trim().isEmpty) {
      mostrarMensaje(
        context,
        'Nombre y contenido son obligatorios',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    setState(() => _guardando = true);
    final plantilla = PlantillaMensaje(
      id: widget.plantilla?.id,
      nombre: _nombreCtrl.text.trim(),
      contenido: _contenidoCtrl.text.trim(),
      tipo: _tipo,
    );
    final ok = await _controlador.guardarPlantilla(plantilla);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (ok) {
      mostrarMensaje(context, 'Plantilla guardada', tipo: TipoMensaje.exito);
      Navigator.pop(context, true);
    } else {
      mostrarMensaje(context, 'No se pudo guardar', tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: PieBoton(
        texto: _guardando ? 'Guardando…' : 'Guardar plantilla',
        icono: Icons.check_rounded,
        cargando: _guardando,
        onPressed: _guardar,
      ),
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.all(AppEspaciado.md),
          children: [
            CabeceraApp(
              titulo: _esEdicion ? 'Editar plantilla' : 'Nueva plantilla',
              subtitulo: 'Usa los datos del cliente para personalizarla',
            ),
            const SizedBox(height: AppEspaciado.lg),
            TextField(
              controller: _nombreCtrl,
              decoration: const InputDecoration(labelText: 'Nombre'),
            ),
            const SizedBox(height: AppEspaciado.md),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo'),
              items: kTiposPlantilla
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (v) => setState(() => _tipo = v ?? 'Recordatorio'),
            ),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: _contenidoCtrl,
              maxLines: 7,
              decoration: const InputDecoration(
                labelText: 'Contenido',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: AppEspaciado.sm),
            const Text(
              'Insertar dato del cliente:',
              style: TextStyle(
                fontSize: 12.5,
                color: AppColores.textoSecundario,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: kVariablesPlantilla
                  .map(
                    (v) => ActionChip(
                      avatar: Icon(
                        Icons.add,
                        size: 16,
                        color: AppColores.primario,
                      ),
                      label: Text(v.etiqueta),
                      onPressed: () => _insertarVariable(v.valor),
                      backgroundColor: AppColores.superficie,
                      side: BorderSide(color: AppColores.borde),
                      labelStyle: TextStyle(
                        color: AppColores.primario,
                        fontSize: 12.5,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
