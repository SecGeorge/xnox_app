import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_linea.dart';

/// Detalle de una rutina: lista de ejercicios, agregar ejercicios y
/// registrar la marca (peso/reps) de cada uno, con su PR y progreso.
class DetalleRutinaScreen extends StatefulWidget {
  final int rutinaId;
  const DetalleRutinaScreen({super.key, required this.rutinaId});

  @override
  State<DetalleRutinaScreen> createState() => _DetalleRutinaScreenState();
}

class _DetalleRutinaScreenState extends State<DetalleRutinaScreen> {
  final _controlador = ControladorRutinas();

  Rutina? get _rutina => _controlador.obtenerRutina(widget.rutinaId);

  @override
  Widget build(BuildContext context) {
    final rutina = _rutina;
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: Text(rutina?.nombre ?? 'Rutina')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarEjercicio,
        backgroundColor: AppColores.primario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Ejercicio',
            style: TextStyle(color: Colors.white)),
      ),
      body: rutina == null
          ? const EstadoVacio(
              icono: Icons.error_outline, mensaje: 'Rutina no encontrada')
          : rutina.ejercicios.isEmpty
              ? const EstadoVacio(
                  icono: Icons.fitness_center_outlined,
                  mensaje:
                      'Esta rutina no tiene ejercicios.\nAgrega uno con el botón +',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                      AppEspaciado.md, AppEspaciado.md, 90),
                  children: [
                    Text(rutina.dia,
                        style: const TextStyle(
                            fontSize: 14,
                            color: AppColores.textoSecundario)),
                    const SizedBox(height: AppEspaciado.md),
                    ...rutina.ejercicios.map(_buildEjercicio),
                  ],
                ),
    );
  }

  Widget _buildEjercicio(Ejercicio e) {
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
                    ],
                  ),
                ),
                if (pr != null)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text('PR',
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
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
            GraficoLinea(valores: progreso),
            const SizedBox(height: AppEspaciado.sm),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  e.ultimaMarca != null
                      ? 'Última: ${_num(e.ultimaMarca!.peso)} kg × ${e.ultimaMarca!.repeticiones} · ${DateFormat('d MMM', 'es').format(e.ultimaMarca!.fecha)}'
                      : 'Sin marcas aún',
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textoSecundario),
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

  Future<void> _agregarEjercicio() async {
    final nombreCtrl = TextEditingController();
    final seriesCtrl = TextEditingController(text: '4');
    final repsCtrl = TextEditingController(text: '10');

    final ok = await _formSheet(
      titulo: 'Agregar ejercicio',
      campos: [
        _Campo(nombreCtrl, 'Nombre del ejercicio',
            capitalizar: true),
        _Campo(seriesCtrl, 'Series', numerico: true),
        _Campo(repsCtrl, 'Repeticiones', numerico: true),
      ],
      validar: () => nombreCtrl.text.trim().isNotEmpty,
    );

    if (ok == true) {
      _controlador.agregarEjercicio(
        widget.rutinaId,
        nombreCtrl.text.trim(),
        int.tryParse(seriesCtrl.text) ?? 0,
        int.tryParse(repsCtrl.text) ?? 0,
      );
      setState(() {});
    }
  }

  Future<void> _registrarMarca(Ejercicio e) async {
    final pesoCtrl = TextEditingController();
    final repsCtrl = TextEditingController(text: '${e.repeticiones}');

    final ok = await _formSheet(
      titulo: 'Registrar marca · ${e.nombre}',
      campos: [
        _Campo(pesoCtrl, 'Peso (kg)', numerico: true, decimal: true),
        _Campo(repsCtrl, 'Repeticiones', numerico: true),
      ],
      validar: () => double.tryParse(pesoCtrl.text) != null,
    );

    if (ok == true) {
      _controlador.registrarMarca(
        e.id,
        double.tryParse(pesoCtrl.text) ?? 0,
        int.tryParse(repsCtrl.text) ?? 0,
      );
      setState(() {});
    }
  }

  Future<bool?> _formSheet({
    required String titulo,
    required List<_Campo> campos,
    required bool Function() validar,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
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
                        ? TextInputType.numberWithOptions(decimal: c.decimal)
                        : TextInputType.text,
                    textCapitalization: c.capitalizar
                        ? TextCapitalization.sentences
                        : TextCapitalization.none,
                    decoration: InputDecoration(labelText: c.etiqueta),
                  ),
                )),
            const SizedBox(height: AppEspaciado.sm),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (!validar()) return;
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
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
