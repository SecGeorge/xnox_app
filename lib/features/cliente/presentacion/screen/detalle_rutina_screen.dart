import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_linea.dart';

/// Detalle de una rutina: días de entrenamiento con sus ejercicios. Permite,
/// solo en las rutinas del cliente, agregar días y ejercicios. Registrar marcas
/// (peso/reps) está disponible en cualquier rutina como seguimiento del avance.
class DetalleRutinaScreen extends StatefulWidget {
  final int rutinaId;
  const DetalleRutinaScreen({super.key, required this.rutinaId});

  @override
  State<DetalleRutinaScreen> createState() => _DetalleRutinaScreenState();
}

const _diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

class _DetalleRutinaScreenState extends State<DetalleRutinaScreen> {
  final _controlador = ControladorRutinas();

  Rutina? get _rutina => _controlador.obtenerRutina(widget.rutinaId);

  @override
  Widget build(BuildContext context) {
    final rutina = _rutina;
    final editable = rutina != null && !rutina.esSugerida;

    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: Text(rutina?.nombre ?? 'Rutina'),
      ),
      floatingActionButton: editable
          ? FloatingActionButton.extended(
              onPressed: _agregarDia,
              backgroundColor: AppColores.primario,
              icon: const Icon(Icons.calendar_today, color: Colors.white),
              label: const Text('Agregar día',
                  style: TextStyle(color: Colors.white)),
            )
          : null,
      body: rutina == null
          ? const EstadoVacio(
              icono: Icons.error_outline, mensaje: 'Rutina no encontrada')
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                  AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, 90),
              children: [
                if (rutina.descripcion.isNotEmpty) ...[
                  Text(rutina.descripcion,
                      style: const TextStyle(
                          fontSize: 14, color: AppColores.textoSecundario)),
                  const SizedBox(height: AppEspaciado.md),
                ],
                if (rutina.esSugerida) ...[
                  Row(
                    children: [
                      const Icon(Icons.lock_outline,
                          size: 16, color: AppColores.textoSecundario),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          rutina.personalizada
                              ? 'Rutina que tu gimnasio armó para ti (solo lectura). Puedes registrar tus marcas.'
                              : 'Rutina sugerida (solo lectura). Puedes registrar tus marcas.',
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColores.textoSecundario),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppEspaciado.md),
                ],
                if (rutina.dias.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: EstadoVacio(
                      icono: Icons.event_busy_outlined,
                      mensaje: editable
                          ? 'Esta rutina no tiene días.\nAgrega uno con el botón.'
                          : 'Esta rutina no tiene días.',
                    ),
                  )
                else
                  ...rutina.dias.map((d) => _buildDia(d, editable)),
              ],
            ),
    );
  }

  Widget _buildDia(DiaRutina dia, bool editable) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: AppEspaciado.sm),
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColores.primario,
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
              ),
              child: Text(dia.diaSemana,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14)),
            ),
            const Spacer(),
            if (editable)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    size: 20, color: AppColores.textoSecundario),
                tooltip: 'Eliminar día',
                onPressed: () => _eliminarDia(dia),
              ),
          ],
        ),
        const SizedBox(height: AppEspaciado.sm),
        if (dia.ejercicios.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text('Sin ejercicios en este día',
                style: TextStyle(
                    fontSize: 13, color: AppColores.textoSecundario)),
          )
        else
          ...dia.ejercicios.map((e) => _buildEjercicio(e, editable)),
        if (editable)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _agregarEjercicio(dia.id),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Agregar ejercicio'),
            ),
          ),
        const SizedBox(height: AppEspaciado.sm),
      ],
    );
  }

  Widget _buildEjercicio(Ejercicio e, bool editable) {
    final pr = e.mejorMarca;
    final progreso =
        e.marcasOrdenadas.map((m) => m.peso).toList(growable: false);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.md),
      child: TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.nombre,
                          style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppColores.textoPrincipal)),
                      const SizedBox(height: 2),
                      Text('${e.series} series × ${e.repeticiones} reps',
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColores.textoSecundario)),
                      if (e.observaciones != null &&
                          e.observaciones!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('📝 ${e.observaciones!}',
                            style: const TextStyle(
                                fontSize: 12.5,
                                fontStyle: FontStyle.italic,
                                color: AppColores.textoSecundario)),
                      ],
                    ],
                  ),
                ),
                if (pr != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const Text('PR',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColores.acento)),
                      Text('${_num(pr.peso)} kg',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColores.textoPrincipal)),
                    ],
                  ),
                if (editable)
                  IconButton(
                    icon: const Icon(Icons.delete_outline,
                        size: 20, color: AppColores.textoSecundario),
                    tooltip: 'Eliminar ejercicio',
                    onPressed: () => _eliminarEjercicio(e),
                  ),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
            GraficoLinea(valores: progreso),
            const SizedBox(height: AppEspaciado.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.ultimaMarca != null
                            ? 'Última: ${_num(e.ultimaMarca!.peso)} kg × ${e.ultimaMarca!.repsTexto} reps · ${DateFormat('d MMM', 'es').format(e.ultimaMarca!.fecha)}'
                            : 'Sin marcas aún',
                        style: const TextStyle(
                            fontSize: 12, color: AppColores.textoSecundario),
                      ),
                      if (e.marcaAnterior != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Sesión anterior: ${_num(e.marcaAnterior!.peso)} kg × ${e.marcaAnterior!.repsTexto} reps · ${DateFormat('d MMM', 'es').format(e.marcaAnterior!.fecha)}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColores.vencido),
                          ),
                        ),
                    ],
                  ),
                ),
                if (e.marcas.isNotEmpty)
                  IconButton(
                    onPressed: () => _verHistorial(e),
                    icon: const Icon(Icons.history, size: 20),
                    color: AppColores.textoSecundario,
                    tooltip: 'Ver historial',
                  ),
                TextButton.icon(
                  onPressed: () => _editarSesionHoy(e),
                  icon: const Icon(Icons.fitness_center, size: 18),
                  label: const Text('Sesión'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Muestra el historial completo de marcas del ejercicio, una por sesión,
  /// de la más reciente a la más antigua (Sesión N = orden cronológico).
  void _verHistorial(Ejercicio e) {
    final ordenadas = e.marcasOrdenadas; // antiguas -> recientes
    final total = ordenadas.length;
    final pr = e.mejorMarca;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (ctx, scroll) => Padding(
          padding: const EdgeInsets.fromLTRB(AppEspaciado.lg, AppEspaciado.md,
              AppEspaciado.lg, AppEspaciado.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppEspaciado.md),
                  decoration: BoxDecoration(
                    color: AppColores.borde,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Text('Historial · ${e.nombre}',
                  style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal)),
              Text('$total sesiones registradas',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColores.textoSecundario)),
              const SizedBox(height: AppEspaciado.md),
              Expanded(
                child: ListView.separated(
                  controller: scroll,
                  itemCount: total,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, color: AppColores.borde),
                  itemBuilder: (_, i) {
                    // i=0 -> más reciente; numeración cronológica.
                    final m = ordenadas[total - 1 - i];
                    final numeroSesion = total - i;
                    final esPr = pr != null &&
                        m.peso == pr.peso &&
                        m.fecha == pr.fecha;
                    return _filaHistorial(m, numeroSesion, esPr);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filaHistorial(Marca m, int numeroSesion, bool esPr) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColores.acento.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text('$numeroSesion',
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColores.acento,
                    fontSize: 14)),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('${_num(m.peso)} kg',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: AppColores.textoPrincipal)),
                    if (esPr) ...[
                      const SizedBox(width: 6),
                      const EtiquetaEstado(texto: 'PR', color: AppColores.acento),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text('${m.repsTexto} reps',
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColores.textoSecundario)),
              ],
            ),
          ),
          Text(DateFormat('d MMM y', 'es').format(m.fecha),
              style: const TextStyle(
                  fontSize: 12, color: AppColores.textoSecundario)),
        ],
      ),
    );
  }

  String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  Future<void> _agregarDia() async {
    final rutina = _rutina;
    if (rutina == null) return;
    // Días aún no usados en la rutina.
    final usados = rutina.dias.map((d) => d.diaSemana).toSet();
    final disponibles =
        _diasSemana.where((d) => !usados.contains(d)).toList();
    if (disponibles.isEmpty) {
      mostrarMensaje(context, 'Ya agregaste los 7 días',
          tipo: TipoMensaje.advertencia);
      return;
    }

    final elegido = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppEspaciado.md),
              child: Text('Elige el día',
                  style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal)),
            ),
            ...disponibles.map((d) => ListTile(
                  leading: const Icon(Icons.calendar_today,
                      color: AppColores.primario),
                  title: Text(d),
                  onTap: () => Navigator.of(ctx).pop(d),
                )),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );

    if (elegido == null) return;
    await _controlador.agregarDia(rutina.id, elegido);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _eliminarDia(DiaRutina dia) async {
    final confirmar = await _confirmar(
        'Eliminar día', '¿Eliminar "${dia.diaSemana}" y sus ejercicios?');
    if (!confirmar) return;
    await _controlador.eliminarDia(dia.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _eliminarEjercicio(Ejercicio e) async {
    final confirmar =
        await _confirmar('Eliminar ejercicio', '¿Eliminar "${e.nombre}"?');
    if (!confirmar) return;
    await _controlador.eliminarEjercicio(e.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _agregarEjercicio(int diaId) async {
    final nombreCtrl = TextEditingController();
    final seriesCtrl = TextEditingController(text: '4');
    final repsCtrl = TextEditingController(text: '10');
    final obsCtrl = TextEditingController();

    final ok = await _formSheet(
      titulo: 'Agregar ejercicio',
      campos: [
        _Campo(nombreCtrl, 'Nombre del ejercicio', capitalizar: true),
        _Campo(seriesCtrl, 'Series', numerico: true),
        _Campo(repsCtrl, 'Repeticiones', numerico: true),
        _Campo(obsCtrl, 'Observaciones (opcional)', capitalizar: true),
      ],
      validar: () {
        if (nombreCtrl.text.trim().isEmpty) {
          return 'Ingresa el nombre del ejercicio';
        }
        final series = int.tryParse(seriesCtrl.text.trim());
        if (series == null || series <= 0) {
          return 'Las series deben ser un número mayor a 0';
        }
        final reps = int.tryParse(repsCtrl.text.trim());
        if (reps == null || reps <= 0) {
          return 'Las repeticiones deben ser un número mayor a 0';
        }
        return null;
      },
    );

    if (ok != true) return;
    await _controlador.agregarEjercicio(
      diaId,
      nombreCtrl.text.trim(),
      int.tryParse(seriesCtrl.text) ?? 0,
      int.tryParse(repsCtrl.text) ?? 0,
      observaciones:
          obsCtrl.text.trim().isEmpty ? null : obsCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {});
  }

  /// La sesión de HOY del ejercicio (única editable serie por serie), o null.
  Marca? _sesionHoy(Ejercicio e) {
    Marca? s;
    for (final m in e.marcas) {
      if (m.esHoy && (s == null || m.fecha.isAfter(s.fecha))) s = m;
    }
    return s;
  }

  /// Editor de la sesión de hoy: agrega/edita/borra cada serie una por una.
  Future<void> _editarSesionHoy(Ejercicio e) async {
    final sesion = _sesionHoy(e);
    int? marcaId = sesion?.id;
    final reps = <int>[...?sesion?.repsPorSerie];
    // Referencia: si ya hay sesión hoy, la anterior; si no, la última registrada.
    final referencia = sesion != null ? e.marcaAnterior : e.ultimaMarca;
    final pesoCtrl = TextEditingController(
      text: sesion != null
          ? _num(sesion.peso)
          : (e.ultimaMarca != null ? _num(e.ultimaMarca!.peso) : ''),
    );

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            double? pesoValido() =>
                double.tryParse(pesoCtrl.text.trim().replaceAll(',', '.'));

            Future<void> agregar() async {
              final peso = pesoValido();
              if (peso == null || peso <= 0) {
                setSheet(() => error = 'Ingresa el peso de trabajo (kg)');
                return;
              }
              final r = await _pedirEntero(
                'Reps · serie ${reps.length + 1}',
                inicial: reps.isNotEmpty ? '${reps.last}' : '${e.repeticiones}',
              );
              if (r == null) return;
              marcaId = await _controlador.agregarSerie(e.id, peso, r);
              setSheet(() {
                reps.add(r);
                error = null;
              });
            }

            Future<void> editar(int i) async {
              if (marcaId == null) return;
              final r = await _pedirEntero('Editar serie ${i + 1}',
                  inicial: '${reps[i]}');
              if (r == null) return;
              await _controlador.editarSerie(marcaId!, i + 1, r);
              setSheet(() => reps[i] = r);
            }

            Future<void> borrar(int i) async {
              if (marcaId == null) return;
              final ok = await confirmarDialog(
                context,
                titulo: 'Eliminar serie ${i + 1}',
                mensaje: '¿Quitar esta serie de la sesión de hoy?',
                icono: Icons.delete_outline,
                textoConfirmar: 'Eliminar',
                peligro: true,
              );
              if (!ok) return;
              await _controlador.eliminarSerie(marcaId!, i + 1);
              setSheet(() {
                reps.removeAt(i);
                if (reps.isEmpty) marcaId = null;
              });
            }

            Future<void> guardarPeso() async {
              final peso = pesoValido();
              if (peso != null && peso > 0 && marcaId != null) {
                await _controlador.editarPesoSesion(marcaId!, peso);
              }
            }

            return Padding(
              padding: EdgeInsets.only(
                left: AppEspaciado.lg,
                right: AppEspaciado.lg,
                top: AppEspaciado.md,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + AppEspaciado.lg,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: AppEspaciado.md),
                        decoration: BoxDecoration(
                          color: AppColores.borde,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    Text('Sesión de hoy · ${e.nombre}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColores.textoPrincipal)),
                    Text(DateFormat('EEEE d MMM', 'es').format(DateTime.now()),
                        style: const TextStyle(
                            fontSize: 12.5, color: AppColores.textoSecundario)),
                    const SizedBox(height: AppEspaciado.md),
                    if (referencia != null) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColores.azul.withValues(alpha: 0.08),
                          borderRadius:
                              BorderRadius.circular(AppEspaciado.radioSm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.history,
                                size: 18, color: AppColores.azul),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Última vez: ${_num(referencia.peso)} kg · ${referencia.repsTexto} reps',
                                style: const TextStyle(
                                    color: AppColores.azul,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppEspaciado.md),
                    ],
                    TextField(
                      controller: pesoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      decoration:
                          const InputDecoration(labelText: 'Peso de trabajo (kg)'),
                      onSubmitted: (_) => guardarPeso(),
                    ),
                    const SizedBox(height: AppEspaciado.md),
                    const Text('Series de hoy',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: AppColores.textoPrincipal)),
                    const SizedBox(height: AppEspaciado.sm),
                    if (reps.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: Text(
                          'Aún no registras series hoy. Agrega la primera.',
                          style: TextStyle(
                              color: AppColores.textoSecundario, fontSize: 13),
                        ),
                      )
                    else
                      ...List.generate(
                          reps.length, (i) => _filaSerieEditable(i, reps[i],
                              () => editar(i), () => borrar(i))),
                    if (error != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppColores.advertencia.withValues(alpha: 0.12),
                          borderRadius:
                              BorderRadius.circular(AppEspaciado.radioSm),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.warning_amber_rounded,
                                size: 18, color: AppColores.advertencia),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(error!,
                                  style: const TextStyle(
                                      color: AppColores.advertencia,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const SizedBox(height: AppEspaciado.md),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: agregar,
                        icon: const Icon(Icons.add),
                        label: Text(reps.isEmpty
                            ? 'Agregar primera serie'
                            : 'Agregar serie ${reps.length + 1}'),
                      ),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Listo'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {});
  }

  Widget _filaSerieEditable(
      int i, int reps, VoidCallback onEditar, VoidCallback onBorrar) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.sm),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColores.acento.withValues(alpha: 0.12),
            child: Text('${i + 1}',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AppColores.acento)),
          ),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text('$reps reps',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal)),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            color: AppColores.textoSecundario,
            tooltip: 'Editar',
            onPressed: onEditar,
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColores.moroso,
            tooltip: 'Quitar',
            onPressed: onBorrar,
          ),
        ],
      ),
    );
  }

  /// Diálogo pequeño para capturar un entero positivo (reps).
  Future<int?> _pedirEntero(String titulo, {String? inicial}) {
    final ctrl = TextEditingController(text: inicial ?? '');
    return showDialog<int>(
      context: context,
      builder: (ctx) {
        String? err;
        return StatefulBuilder(
          builder: (ctx, setD) {
            void aceptar() {
              final n = int.tryParse(ctrl.text.trim());
              if (n == null || n <= 0) {
                setD(() => err = 'Ingresa un número mayor a 0');
                return;
              }
              Navigator.pop(ctx, n);
            }

            return AlertDialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppEspaciado.radio)),
              title: Text(titulo,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
              content: TextField(
                controller: ctrl,
                autofocus: true,
                keyboardType: TextInputType.number,
                decoration:
                    InputDecoration(labelText: 'Repeticiones', errorText: err),
                onSubmitted: (_) => aceptar(),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancelar')),
                ElevatedButton(
                    onPressed: aceptar, child: const Text('Guardar')),
              ],
            );
          },
        );
      },
    );
  }

  Future<bool> _confirmar(String titulo, String mensaje) {
    return confirmarDialog(
      context,
      titulo: titulo,
      mensaje: mensaje,
      icono: Icons.delete_outline,
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
  }

  /// Hoja de formulario reutilizable. [validar] devuelve `null` si todo está
  /// correcto, o el mensaje de alerta a mostrar cuando un campo es inválido.
  Future<bool?> _formSheet({
    required String titulo,
    required List<_Campo> campos,
    required String? Function() validar,
    String? nota,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setSheet) => Padding(
            padding: EdgeInsets.only(
              left: AppEspaciado.lg,
              right: AppEspaciado.lg,
              top: AppEspaciado.lg,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + AppEspaciado.lg,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(titulo,
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal)),
                  const SizedBox(height: AppEspaciado.md),
                  if (nota != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColores.azul.withValues(alpha: 0.08),
                        borderRadius:
                            BorderRadius.circular(AppEspaciado.radioSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.history,
                              size: 18, color: AppColores.azul),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(nota,
                                style: const TextStyle(
                                    color: AppColores.azul,
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppEspaciado.md),
                  ],
                  ...campos.map((c) => Padding(
                        padding:
                            const EdgeInsets.only(bottom: AppEspaciado.md),
                        child: TextField(
                          controller: c.controlador,
                          keyboardType: c.numerico
                              ? TextInputType.number
                              : TextInputType.text,
                          textCapitalization: c.capitalizar
                              ? TextCapitalization.sentences
                              : TextCapitalization.none,
                          decoration: InputDecoration(labelText: c.etiqueta),
                        ),
                      )),
                  if (error != null)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: AppEspaciado.sm),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        // Validación = alerta (amarillo), no error de sistema.
                        color: AppColores.advertencia.withValues(alpha: 0.12),
                        borderRadius:
                            BorderRadius.circular(AppEspaciado.radioSm),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded,
                              size: 18, color: AppColores.advertencia),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(error!,
                                style: const TextStyle(
                                    color: AppColores.advertencia,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: AppEspaciado.sm),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        final err = validar();
                        if (err != null) {
                          setSheet(() => error = err);
                          return;
                        }
                        Navigator.of(ctx).pop(true);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Campo {
  final TextEditingController controlador;
  final String etiqueta;
  final bool numerico;
  final bool capitalizar;
  _Campo(this.controlador, this.etiqueta,
      {this.numerico = false, this.capitalizar = false});
}
