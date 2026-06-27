import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_linea.dart';

/// Reporte del progreso del cliente: resumen y evolución de marcas por ejercicio.
class ReporteEjerciciosScreen extends StatefulWidget {
  const ReporteEjerciciosScreen({super.key});

  @override
  State<ReporteEjerciciosScreen> createState() =>
      _ReporteEjerciciosScreenState();
}

class _ReporteEjerciciosScreenState extends State<ReporteEjerciciosScreen> {
  final _controlador = ControladorRutinas();

  @override
  void initState() {
    super.initState();
    // Los datos viven en SQLite: aseguramos que la caché esté cargada para
    // poder leerla de forma síncrona en build().
    _controlador.asegurarCargado().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final ejercicios = _controlador.obtenerTodosLosEjercicios();
    final conMarcas = ejercicios.where((e) => e.marcas.isNotEmpty).toList();
    final totalMarcas =
        ejercicios.fold<int>(0, (s, e) => s + e.marcas.length);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: () async => setState(() {}),
        child: ListView(
          padding: const EdgeInsets.all(AppEspaciado.md),
          children: [
            const SizedBox(height: AppEspaciado.sm),
            const Text(
              'Reporte de Ejercicios',
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColores.textoPrincipal),
            ),
            const SizedBox(height: 4),
            const Text('Tu progreso registrado',
                style: TextStyle(
                    fontSize: 13.5, color: AppColores.textoSecundario)),
            const SizedBox(height: AppEspaciado.lg),
            Row(
              children: [
                _resumen('Ejercicios', '${ejercicios.length}',
                    Icons.fitness_center, AppColores.azul),
                const SizedBox(width: AppEspaciado.sm + 4),
                _resumen('Marcas', '$totalMarcas', Icons.show_chart,
                    AppColores.verde),
              ],
            ),
            const SizedBox(height: AppEspaciado.lg),
            if (conMarcas.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 40),
                child: EstadoVacio(
                  icono: Icons.insights_outlined,
                  mensaje:
                      'Aún no hay marcas registradas.\nRegistra marcas en tus rutinas para ver tu progreso.',
                ),
              )
            else
              ...conMarcas.map(_buildEjercicio),
          ],
        ),
      ),
    );
  }

  Widget _resumen(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
              ),
              child: Icon(icono, color: color, size: 20),
            ),
            const SizedBox(height: AppEspaciado.sm),
            Text(valor,
                style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal)),
            Text(titulo,
                style: const TextStyle(
                    fontSize: 12.5, color: AppColores.textoSecundario)),
          ],
        ),
      ),
    );
  }

  Widget _buildEjercicio(Ejercicio e) {
    final pr = e.mejorMarca!;
    final primera = e.marcasOrdenadas.first;
    final mejora = pr.peso - primera.peso;
    final progreso = e.marcasOrdenadas.map((m) => m.peso).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.md),
      child: TarjetaApp(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(e.nombre,
                      style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal)),
                ),
                if (mejora > 0)
                  EtiquetaEstado(
                      texto: '+${_num(mejora)} kg', color: AppColores.activo),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
            GraficoLinea(valores: progreso, color: AppColores.acento),
            const SizedBox(height: AppEspaciado.sm),
            Text(
              'PR ${_num(pr.peso)} kg · ${e.marcas.length} registros · desde ${DateFormat('d MMM', 'es').format(primera.fecha)}',
              style: const TextStyle(
                  fontSize: 12, color: AppColores.textoSecundario),
            ),
          ],
        ),
      ),
    );
  }

  String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
