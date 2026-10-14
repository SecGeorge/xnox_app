import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Mi plan: lo que el entrenador asignó comer cada día, con la foto de cada
/// alimento. "Lo comí" lo registra en el diario de hoy con la cantidad del
/// plan.
class PlanNutricionScreen extends StatelessWidget {
  final ControladorNutricion controlador;

  const PlanNutricionScreen({super.key, required this.controlador});

  Future<void> _comi(BuildContext context, ItemPlan i) async {
    final error = await controlador.comiDelPlan(DateTime.now(), i);
    if (!context.mounted) return;
    mostrarMensaje(
      context,
      error ?? '¡Bien! ${i.alimento.nombre} registrado',
      tipo: error == null ? TipoMensaje.exito : TipoMensaje.error,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final r = controlador.resumen;
        final plan = r?.plan;
        final deHoy = r?.consumosDe(isoFecha(DateTime.now())) ?? const [];
        return PantallaApp(
          onRefresh: controlador.cargar,
          espacioAbajo: AppEspaciado.lg,
          children: [
            const CabeceraApp(
              titulo: 'Mi plan',
              subtitulo: 'Lo que te asignó tu entrenador para cada día',
            ),
            const SizedBox(height: AppEspaciado.md + 4),
            if (plan == null || plan.items.isEmpty)
              const VacioApp(
                icono: Icons.assignment_outlined,
                titulo: 'Aún no tienes plan',
                texto:
                    'Cuando tu entrenador te asigne uno, aparecerá aquí con '
                    'lo que te toca en cada comida.',
              )
            else ...[
              _portada(plan, deHoy),
              const SizedBox(height: AppEspaciado.md),
              _aporte(plan),
              if (plan.notas != null) ...[
                const SizedBox(height: AppEspaciado.md),
                NotasPlan(plan.notas!),
              ],
              const SizedBox(height: AppEspaciado.lg),
              PlanPorComidas(
                plan: plan,
                consumosDelDia: deHoy,
                onComi: (i) => _comi(context, i),
              ),
              const Text(
                'Fotos de alimentos: Wikimedia Commons y Open Food Facts.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// Foto con el nombre del plan y cuánto lleva hoy.
  Widget _portada(PlanNutricion plan, List<Consumo> deHoy) {
    final ids = plan.items.map((i) => i.id).toSet();
    final hechos = deHoy
        .where((c) => c.planItemId != null && ids.contains(c.planItemId))
        .map((c) => c.planItemId)
        .toSet()
        .length;
    final total = plan.items.length;
    return PortadaNutricion(
      foto: FotosNutricion.mesa,
      icono: Icons.assignment_rounded,
      chip: 'Tu plan de hoy',
      alto: 170,
      titulo: plan.nombre,
      detalle: hechos == total
          ? '¡Completaste tu plan de hoy!'
          : '$hechos de $total alimentos comidos',
      hechos: hechos,
      total: total,
    );
  }

  /// Lo que suma el plan en el día.
  Widget _aporte(PlanNutricion plan) {
    final t = plan.totales;
    // Cada columna es un cuarto del ancho: "Carbohidratos" o "1933 kcal" no
    // siempre caben, así que se achican un poco en vez de desbordarse.
    Widget dato(Nutriente n) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                n.formato(t[n.clave] ?? 0),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: ColoresNutricion.de(n.clave),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    n.nombre,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 14),
      child: Column(
        children: [
          const Text(
            'EL PLAN TE DA AL DÍA',
            style: TextStyle(
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              dato(Nutriente.kcal),
              dato(Nutriente.proteina),
              dato(Nutriente.carbohidrato),
              dato(Nutriente.grasa),
            ],
          ),
        ],
      ),
    );
  }
}
