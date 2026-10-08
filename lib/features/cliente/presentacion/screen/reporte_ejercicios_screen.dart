import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
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
    final totalMarcas = ejercicios.fold<int>(0, (s, e) => s + e.marcas.length);
    // Lo que más subió primero: motiva ver arriba el mayor avance.
    conMarcas.sort((a, b) => _mejora(b).compareTo(_mejora(a)));
    final ganado = conMarcas.fold<double>(
      0,
      (s, e) => s + (_mejora(e) > 0 ? _mejora(e) : 0),
    );

    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async => setState(() {}),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppEspaciado.md,
              AppEspaciado.md,
              AppEspaciado.md,
              120,
            ),
            children: [
              const CabeceraApp(
                titulo: 'Mi avance',
                subtitulo: 'Tus pesos y marcas registradas',
                atras: false,
              ),
              const SizedBox(height: AppEspaciado.md + 4),
              PortadaFoto(
                foto: FotosApp.progreso,
                alineacion: const Alignment(0.4, -0.2),
                altura: 170,
                etiqueta: 'Fuerza ganada',
                titulo: ganado > 0 ? '+${_num(ganado)} kg' : 'Empieza hoy',
                pie: Row(
                  children: [
                    DatoPortada(
                      icono: Icons.fitness_center_rounded,
                      valor: '${conMarcas.length}',
                      pie: conMarcas.length == 1 ? 'ejercicio' : 'ejercicios',
                    ),
                    const SizedBox(width: 18),
                    DatoPortada(
                      icono: Icons.show_chart_rounded,
                      valor: '$totalMarcas',
                      pie: totalMarcas == 1 ? 'registro' : 'registros',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppEspaciado.lg),
              TituloSeccion(
                icono: Icons.emoji_events_rounded,
                titulo: 'Tus ejercicios',
                detalle: conMarcas.isEmpty ? null : '${conMarcas.length}',
              ),
              if (conMarcas.isEmpty)
                const VacioApp(
                  icono: Icons.insights_rounded,
                  titulo: 'Aún no hay marcas registradas',
                  texto:
                      'Registra la carga en tus rutinas y aquí verás '
                      'cómo vas subiendo.',
                )
              else
                ...conMarcas.map(_buildEjercicio),
            ],
          ),
        ),
      ),
    );
  }

  double _mejora(Ejercicio e) {
    if (e.marcas.isEmpty) return 0;
    return e.mejorMarca!.peso - e.marcasOrdenadas.first.peso;
  }

  Widget _buildEjercicio(Ejercicio e) {
    final pr = e.mejorMarca!;
    final primera = e.marcasOrdenadas.first;
    final mejora = pr.peso - primera.peso;
    final progreso = e.marcasOrdenadas.map((m) => m.peso).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.md),
      child: TarjetaPlana(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColores.degradadoRelleno,
                    border: AppColores.bordeCabecera,
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  ),
                  child: Icon(
                    Icons.fitness_center_rounded,
                    color: AppColores.sobreRelleno,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      Text(
                        '${e.marcas.length} registros · desde '
                        '${DateFormat('d MMM', 'es').format(primera.fecha)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                if (mejora > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColores.activo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.trending_up_rounded,
                          size: 15,
                          color: AppColores.activo,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          '+${_num(mejora)} kg',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: AppColores.activo,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            GraficoLinea(valores: progreso, color: AppColores.primario),
            const SizedBox(height: AppEspaciado.sm + 2),
            Row(
              children: [
                _datoMarca('Inicio', '${_num(primera.peso)} kg'),
                _datoMarca(
                  'Mejor marca',
                  '${_num(pr.peso)} kg',
                  destacar: true,
                ),
                _datoMarca('Última', '${_num(progreso.last)} kg'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _datoMarca(String titulo, String valor, {bool destacar = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: destacar ? AppColores.primario : AppColores.textoPrincipal,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  String _num(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}
