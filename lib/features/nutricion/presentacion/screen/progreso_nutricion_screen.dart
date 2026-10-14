import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Mi progreso: racha, récord, gráficos de proteínas y grasas de 2 semanas y
/// el historial de días (cumplió o no).
class ProgresoNutricionScreen extends StatelessWidget {
  final ControladorNutricion controlador;

  const ProgresoNutricionScreen({super.key, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final r = controlador.resumen;
        if (r == null) return const SizedBox.shrink();
        return PantallaApp(
          onRefresh: controlador.cargar,
          espacioAbajo: AppEspaciado.lg,
          children: [
            const CabeceraApp(
              titulo: 'Mi progreso',
              subtitulo: 'Días cumpliendo proteínas y grasas',
            ),
            const SizedBox(height: AppEspaciado.md + 4),
            PortadaNutricion(
              foto: FotosNutricion.mesa,
              icono: Icons.local_fire_department_rounded,
              chip: 'Racha actual',
              alto: 170,
              titulo:
                  '${r.racha.actual} ${r.racha.actual == 1 ? 'día' : 'días'}',
              pie: [
                DatoPie(
                  icono: Icons.emoji_events_rounded,
                  valor: '${r.racha.mejor}',
                  pie: 'récord de días',
                ),
                DatoPie(
                  icono: Icons.check_circle_rounded,
                  valor: '${r.racha.diasCumplidos}/${r.racha.diasConRegistro}',
                  pie: 'días cumplidos (90)',
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.lg),
            const TituloSeccion(
              icono: Icons.bar_chart_rounded,
              titulo: 'Últimas 2 semanas',
            ),
            GraficosNutricion(resumen: r),
            const SizedBox(height: AppEspaciado.md),
            const TituloSeccion(
              icono: Icons.history_rounded,
              titulo: 'Día a día',
            ),
            HistorialDias(resumen: r),
          ],
        );
      },
    );
  }
}
