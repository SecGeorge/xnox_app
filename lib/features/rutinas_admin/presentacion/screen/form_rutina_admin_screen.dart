import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
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
      mostrarMensaje(
        context,
        'No se pudo cargar la rutina',
        tipo: TipoMensaje.error,
      );
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

  /// Agrega el día en su lugar de la semana (L→D). Si ya está, no hace nada:
  /// se quita con el tacho de su tarjeta.
  void _agregarDia(String dia) {
    if (_rutina.dias.any((d) => d.diaSemana == dia)) return;
    setState(() {
      _rutina.dias.add(DiaAdmin(diaSemana: dia));
      _rutina.dias.sort(
        (a, b) => _diasSemana
            .indexOf(a.diaSemana)
            .compareTo(_diasSemana.indexOf(b.diaSemana)),
      );
    });
  }

  /// Tira L–D: los días de la rutina van rellenos; toca uno libre para
  /// agregarlo.
  Widget _semana() {
    final usados = _rutina.dias.map((d) => d.diaSemana).toSet();
    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 12),
      child: Column(
        children: [
          Row(
            children: [
              for (final d in _diasSemana)
                Expanded(
                  child: GestureDetector(
                    onTap: () => _agregarDia(d),
                    child: Column(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: usados.contains(d)
                                ? AppColores.degradadoRelleno
                                : null,
                            color: usados.contains(d)
                                ? null
                                : AppColores.primario.withValues(alpha: 0.06),
                            shape: BoxShape.circle,
                            border: usados.contains(d)
                                ? AppColores.bordeCabecera
                                : Border.all(
                                    color: AppColores.primario.withValues(
                                      alpha: 0.18,
                                    ),
                                  ),
                          ),
                          child: usados.contains(d)
                              ? Icon(
                                  Icons.check_rounded,
                                  size: 18,
                                  color: AppColores.sobreRelleno,
                                )
                              : Icon(
                                  Icons.add_rounded,
                                  size: 18,
                                  color: AppColores.primario,
                                ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          d.substring(0, 3),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: usados.contains(d)
                                ? FontWeight.w800
                                : FontWeight.w500,
                            color: usados.contains(d)
                                ? AppColores.primario
                                : AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            usados.isEmpty
                ? 'Toca los días que entrenará el socio'
                : '${usados.length} ${usados.length == 1 ? 'día' : 'días'} de entrenamiento',
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _agregarEjercicio(DiaAdmin dia) async {
    final elegido = await mostrarHojaAgregarEjercicio(context);
    if (elegido == null) return;
    setState(() {
      dia.ejercicios.add(
        EjercicioAdmin(
          nombre: elegido.nombre,
          series: elegido.series,
          repeticiones: elegido.repeticiones,
          observaciones: elegido.observaciones,
          catalogoId: elegido.catalogoId,
          imagenUrl: elegido.imagenUrl,
        ),
      );
    });
  }

  Future<void> _guardar() async {
    _rutina.nombre = _nombreCtrl.text.trim();
    _rutina.descripcion = _descripcionCtrl.text.trim();

    if (_rutina.nombre.isEmpty) {
      mostrarMensaje(
        context,
        'Ingresa el nombre de la rutina',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    if (_rutina.dias.isEmpty) {
      mostrarMensaje(
        context,
        'Agrega al menos un día con ejercicios',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    if (_rutina.dias.any((d) => d.ejercicios.isEmpty)) {
      mostrarMensaje(
        context,
        'Cada día debe tener al menos un ejercicio',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    setState(() => _guardando = true);
    final error = await _repo.guardar(_rutina);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (error == null) {
      mostrarMensaje(
        context,
        'Rutina guardada correctamente',
        tipo: TipoMensaje.exito,
      );
      Navigator.of(context).pop(true);
    } else {
      mostrarMensaje(context, error, tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: _cargando
          ? null
          : PieBoton(
              texto: 'Guardar rutina',
              icono: Icons.check_rounded,
              cargando: _guardando,
              onPressed: _guardar,
            ),
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppEspaciado.md),
                children: [
                  CabeceraApp(
                    titulo: _esEdicion ? 'Editar rutina' : 'Nueva rutina',
                    subtitulo: 'Rutina semanal del socio',
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  const TituloSeccion(
                    icono: Icons.edit_note_rounded,
                    titulo: 'Datos',
                  ),
                  TarjetaPlana(
                    child: Column(
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
                      ],
                    ),
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  const TituloSeccion(
                    icono: Icons.calendar_view_week_rounded,
                    titulo: 'Semana',
                  ),
                  _semana(),
                  const SizedBox(height: AppEspaciado.lg),
                  if (_rutina.dias.isNotEmpty) ...[
                    const TituloSeccion(
                      icono: Icons.fitness_center_rounded,
                      titulo: 'Ejercicios por día',
                    ),
                    for (final dia in _rutina.dias) _tarjetaDia(dia),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _tarjetaDia(DiaAdmin dia) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: TarjetaPlana(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: AppColores.degradadoRelleno,
                    border: AppColores.bordeCabecera,
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  ),
                  child: Text(
                    dia.diaSemana.substring(0, 2).toUpperCase(),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: AppColores.sobreRelleno,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    dia.diaSemana,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar día',
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColores.moroso,
                  ),
                  onPressed: () => setState(() => _rutina.dias.remove(dia)),
                ),
              ],
            ),
            if (dia.ejercicios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Sin ejercicios todavía',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
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
                Text(
                  ej.nombre,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  '${ej.series} series × ${ej.repeticiones} reps'
                  '${ej.observaciones != null ? ' · ${ej.observaciones}' : ''}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
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
          ? const Icon(
              Icons.fitness_center,
              size: 18,
              color: AppColores.textoSecundario,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.fitness_center,
                size: 18,
                color: AppColores.textoSecundario,
              ),
            ),
    );
  }
}
