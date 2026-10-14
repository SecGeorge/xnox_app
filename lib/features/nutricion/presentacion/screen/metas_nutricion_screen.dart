import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Mis metas: cuánto llevo hoy contra cada meta y mis datos (altura, peso,
/// IMC, objetivo), que son de donde salen las metas.
class MetasNutricionScreen extends StatelessWidget {
  final ControladorNutricion controlador;

  const MetasNutricionScreen({super.key, required this.controlador});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controlador,
      builder: (context, _) {
        final r = controlador.resumen;
        if (r == null) return const SizedBox.shrink();
        final hoy = isoFecha(DateTime.now());
        final totales = sumarAportes(r.consumosDe(hoy).map((c) => c.aporte));
        return PantallaApp(
          onRefresh: controlador.cargar,
          espacioAbajo: AppEspaciado.lg,
          children: [
            const CabeceraApp(
              titulo: 'Mis metas',
              subtitulo: 'Cuánto llevas hoy y cuánto te toca',
            ),
            const SizedBox(height: AppEspaciado.md),
            _portada(r, totales),
            const SizedBox(height: AppEspaciado.md),
            TarjetaMetasDia(
              resumen: r,
              totales: totales,
              cumpleDia: r.dia(hoy)?.cumpleDia == true,
            ),
            const SizedBox(height: AppEspaciado.lg),
            const TituloSeccion(
              icono: Icons.accessibility_new_rounded,
              titulo: 'Mis datos',
            ),
            _datos(context, r.perfil),
            const SizedBox(height: AppEspaciado.md),
            const Text(
              'Tus metas se calculan con tu peso, altura, edad y objetivo. '
              'Si tu entrenador fija alguna, se usa la suya. '
              '"Mínimo" es llegar; "máximo", no pasarse; "objetivo", '
              'acercarte (±10 %).',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColores.textoSecundario,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Foto con la proteína de hoy contra su meta (lo que más cuenta).
  Widget _portada(ResumenNutricion r, Map<String, double> t) {
    final meta = r.meta('proteina');
    final valor = t['proteina'] ?? 0;
    final segmentos = meta == null || meta.cantidad <= 0
        ? null
        : (valor / meta.cantidad * 10).round().clamp(0, 10);
    final grasa = r.meta('grasa');
    return PortadaNutricion(
      foto: FotosNutricion.metas,
      icono: Icons.flag_rounded,
      chip: 'Metas de hoy',
      alto: 168,
      titulo: meta == null
          ? 'Sin metas aún'
          : 'Proteína ${Nutriente.proteina.formato(valor)} '
                'de ${Nutriente.proteina.formato(meta.cantidad)}',
      detalle: grasa == null
          ? 'Agrega tu altura y peso para calcularlas'
          : 'Grasas ${Nutriente.grasa.formato(t['grasa'] ?? 0)} '
                'de ${Nutriente.grasa.formato(grasa.cantidad)} como máximo',
      hechos: segmentos,
      total: segmentos == null ? null : 10,
    );
  }

  Widget _datos(BuildContext context, PerfilNutricion p) {
    Future<void> editar() async {
      if (await editarPerfilNutricion(context, perfil: p)) {
        await controlador.cargar();
      }
    }

    return PortadaNutricion(
      foto: FotosNutricion.plato,
      icono: Icons.accessibility_new_rounded,
      chip: PerfilNutricion.objetivos[p.objetivo] ?? 'Tus datos',
      alto: 160,
      onTap: editar,
      titulo: p.alturaCm == null
          ? 'Falta tu altura'
          : [
              '${p.alturaCm!.round()} cm',
              if (p.peso != null) '${p.peso} kg',
            ].join(' · '),
      detalle: p.imc == null
          ? 'Agrega altura y peso para calcular tus metas'
          : 'IMC ${p.imc} · ${p.categoriaImc}',
      accion: BotonFoto(
        'Editar mis datos',
        icono: Icons.edit_rounded,
        onTap: editar,
      ),
    );
  }
}
