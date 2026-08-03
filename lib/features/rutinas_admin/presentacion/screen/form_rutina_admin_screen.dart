import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ejercicios/presentacion/widget/hoja_agregar_ejercicio.dart';
import 'package:xnox_app/features/rutinas_admin/datos/repositorio_rutinas_admin.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

/// Crear o editar una rutina personalizada de un miembro: cabecera + días +
/// ejercicios (con el selector del catálogo del gimnasio). Guarda contra el
/// backend (rutinas.php, metodo guardar). Devuelve `true` al Navigator si guardó.
class FormRutinaAdminScreen extends StatefulWidget {
  final int miembroId;

  /// Si viene, se edita esa rutina; si es null, se crea una nueva.
  final int? rutinaId;

  const FormRutinaAdminScreen({
    super.key,
    required this.miembroId,
    this.rutinaId,
  });

  @override
  State<FormRutinaAdminScreen> createState() => _FormRutinaAdminScreenState();
}

class _FormRutinaAdminScreenState extends State<FormRutinaAdminScreen> {
  static const _diasSemana = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  final _repo = RepositorioRutinasAdmin();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();

  RutinaAdmin _rutina = RutinaAdmin();
  bool _cargando = false;
  bool _guardando = false;

  bool get _esEdicion => widget.rutinaId != null;

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargar();
    } else {
      _rutina = RutinaAdmin(miembroId: widget.miembroId);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final rutina = await _repo.obtener(widget.rutinaId!);
    if (!mounted) return;
    if (rutina == null) {
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudo cargar la rutina',
          tipo: TipoMensaje.error);
      return;
    }
    // Aseguramos que quede asociada al miembro al guardar.
    rutina.miembroId = widget.miembroId;
    _nombreCtrl.text = rutina.nombre;
    _descripcionCtrl.text = rutina.descripcion;
    setState(() {
      _rutina = rutina;
      _cargando = false;
    });
  }

  Future<void> _agregarDia() async {
    final usados = _rutina.dias.map((d) => d.diaSemana).toSet();
    final disponibles = _diasSemana.where((d) => !usados.contains(d)).toList();
    if (disponibles.isEmpty) {
      mostrarMensaje(context, 'Ya agregaste todos los días de la semana',
          tipo: TipoMensaje.advertencia);
      return;
    }
    final elegido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppEspaciado.md),
              child: Text('Elegir día',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal)),
            ),
            for (final d in disponibles)
              ListTile(
                leading: const Icon(Icons.event, color: AppColores.primario),
                title: Text(d),
                onTap: () => Navigator.pop(ctx, d),
              ),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
    if (elegido == null) return;
    setState(() => _rutina.dias.add(DiaAdmin(diaSemana: elegido)));
  }

  Future<void> _agregarEjercicio(DiaAdmin dia) async {
    final elegido = await mostrarHojaAgregarEjercicio(context);
    if (elegido == null) return;
    setState(() {
      dia.ejercicios.add(EjercicioAdmin(
        nombre: elegido.nombre,
        series: elegido.series,
        repeticiones: elegido.repeticiones,
        observaciones: elegido.observaciones,
        catalogoId: elegido.catalogoId,
        imagenUrl: elegido.imagenUrl,
      ));
    });
  }

  Future<void> _guardar() async {
    _rutina.nombre = _nombreCtrl.text.trim();
    _rutina.descripcion = _descripcionCtrl.text.trim();

    if (_rutina.nombre.isEmpty) {
      mostrarMensaje(context, 'Ingresa el nombre de la rutina',
          tipo: TipoMensaje.advertencia);
      return;
    }
    if (_rutina.dias.isEmpty) {
      mostrarMensaje(context, 'Agrega al menos un día con ejercicios',
          tipo: TipoMensaje.advertencia);
      return;
    }
    if (_rutina.dias.any((d) => d.ejercicios.isEmpty)) {
      mostrarMensaje(context, 'Cada día debe tener al menos un ejercicio',
          tipo: TipoMensaje.advertencia);
      return;
    }

    setState(() => _guardando = true);
    final error = await _repo.guardar(_rutina);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error == null) {
      mostrarMensaje(context, 'Rutina guardada correctamente',
          tipo: TipoMensaje.exito);
      Navigator.of(context).pop(true);
    } else {
      mostrarMensaje(context, error, tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar rutina' : 'Nueva rutina'),
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                    AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, 96),
                children: [
                  TextField(
                    controller: _nombreCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      labelText: 'Nombre de la rutina',
                      hintText: 'Ej. Fuerza - Nivel 1',
                    ),
                  ),
                  const SizedBox(height: AppEspaciado.md),
                  TextField(
                    controller: _descripcionCtrl,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Descripción (opcional)',
                    ),
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  const EncabezadoSeccion(
                    titulo: 'Días y ejercicios',
                    subtitulo: 'Arma la semana del cliente',
                  ),
                  const SizedBox(height: AppEspaciado.sm),
                  for (final dia in _rutina.dias) _tarjetaDia(dia),
                  const SizedBox(height: AppEspaciado.sm),
                  OutlinedButton.icon(
                    onPressed: _agregarDia,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar día'),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md),
          child: ElevatedButton.icon(
            onPressed: _guardando ? null : _guardar,
            icon: _guardando
                ? const SizedBox.shrink()
                : const Icon(Icons.save_outlined),
            label: _guardando
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5),
                  )
                : const Text('Guardar rutina'),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaDia(DiaAdmin dia) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event, size: 20, color: AppColores.primario),
              const SizedBox(width: AppEspaciado.sm),
              Expanded(
                child: Text(
                  dia.diaSemana,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Quitar día',
                icon: const Icon(Icons.delete_outline, color: AppColores.moroso),
                onPressed: () => setState(() => _rutina.dias.remove(dia)),
              ),
            ],
          ),
          if (dia.ejercicios.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Text('Sin ejercicios todavía',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColores.textoSecundario)),
            )
          else
            for (final ej in dia.ejercicios) _filaEjercicio(dia, ej),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _agregarEjercicio(dia),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar ejercicio'),
            ),
          ),
        ],
      ),
      ),
    );
  }

  Widget _filaEjercicio(DiaAdmin dia, EjercicioAdmin ej) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          _miniatura(ej.imagenUrl),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ej.nombre,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColores.textoPrincipal)),
                Text(
                  '${ej.series} series × ${ej.repeticiones} reps'
                  '${ej.observaciones != null ? ' · ${ej.observaciones}' : ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textoSecundario),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Quitar',
            icon: const Icon(Icons.close, size: 18, color: AppColores.moroso),
            onPressed: () => setState(() => dia.ejercicios.remove(ej)),
          ),
        ],
      ),
    );
  }

  Widget _miniatura(String? url) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.fitness_center,
              size: 18, color: AppColores.textoSecundario)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.fitness_center,
                  size: 18, color: AppColores.textoSecundario),
            ),
    );
  }
}
