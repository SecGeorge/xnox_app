import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
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
                    children: const [
                      Icon(Icons.lock_outline,
                          size: 16, color: AppColores.textoSecundario),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Rutina sugerida (solo lectura). Puedes registrar tus marcas.',
                          style: TextStyle(
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
                  child: Text(
                    e.ultimaMarca != null
                        ? 'Última: ${_num(e.ultimaMarca!.peso)} kg × ${e.ultimaMarca!.repsTexto} reps · ${DateFormat('d MMM', 'es').format(e.ultimaMarca!.fecha)}'
                        : 'Sin marcas aún',
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.textoSecundario),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _registrarMarca(e),
                  icon: const Icon(Icons.add_chart, size: 18),
                  label: const Text('Marca'),
                ),
              ],
            ),
          ],
        ),
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

  Future<void> _registrarMarca(Ejercicio e) async {
    final pesoCtrl = TextEditingController();
    // Un campo de repeticiones por cada serie del ejercicio.
    final nSeries = e.series > 0 ? e.series : 1;
    final repsCtrls = List.generate(
      nSeries,
      (_) => TextEditingController(text: '${e.repeticiones}'),
    );

    final ok = await _formSheet(
      titulo: 'Registrar marca · ${e.nombre}',
      campos: [
        _Campo(pesoCtrl, 'Peso (kg)', numerico: true, decimal: true),
        for (var i = 0; i < nSeries; i++)
          _Campo(repsCtrls[i], 'Reps serie ${i + 1}', numerico: true),
      ],
      validar: () {
        if (pesoCtrl.text.trim().isEmpty) {
          return 'Ingresa el peso (kg)';
        }
        final peso = double.tryParse(pesoCtrl.text.trim().replaceAll(',', '.'));
        if (peso == null) {
          return 'El peso debe ser un número válido';
        }
        if (peso <= 0) {
          return 'El peso debe ser mayor a 0';
        }
        for (var i = 0; i < nSeries; i++) {
          final reps = int.tryParse(repsCtrls[i].text.trim());
          if (reps == null || reps <= 0) {
            return 'Serie ${i + 1}: ingresa las repeticiones (mayor a 0)';
          }
        }
        return null;
      },
    );

    if (ok != true) return;
    await _controlador.registrarMarca(
      e.id,
      double.tryParse(pesoCtrl.text.trim().replaceAll(',', '.')) ?? 0,
      repsCtrls.map((c) => int.tryParse(c.text.trim()) ?? 0).toList(),
    );
    if (!mounted) return;
    setState(() {});
  }

  Future<bool> _confirmar(String titulo, String mensaje) async {
    final r = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: Text(mensaje),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColores.moroso),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    return r == true;
  }

  /// Hoja de formulario reutilizable. [validar] devuelve `null` si todo está
  /// correcto, o el mensaje de alerta a mostrar cuando un campo es inválido.
  Future<bool?> _formSheet({
    required String titulo,
    required List<_Campo> campos,
    required String? Function() validar,
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
                ...campos.map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: AppEspaciado.md),
                      child: TextField(
                        controller: c.controlador,
                        keyboardType: c.numerico
                            ? TextInputType.numberWithOptions(
                                decimal: c.decimal)
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
                      color: AppColores.error.withValues(alpha: 0.10),
                      borderRadius:
                          BorderRadius.circular(AppEspaciado.radioSm),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline,
                            size: 18, color: AppColores.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(error!,
                              style: const TextStyle(
                                  color: AppColores.error, fontSize: 13)),
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
        );
      },
    );
  }
}

class _Campo {
  final TextEditingController controlador;
  final String etiqueta;
  final bool numerico;
  final bool decimal;
  final bool capitalizar;
  _Campo(this.controlador, this.etiqueta,
      {this.numerico = false, this.decimal = false, this.capitalizar = false});
}
