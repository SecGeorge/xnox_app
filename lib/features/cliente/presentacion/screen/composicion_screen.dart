import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/composicion_corporal.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// IMC, clasificación (bajo peso … obesidad III), peso ideal y masa muscular
/// estimada. La usan el socio (Mis medidas) y el personal (ficha del socio):
/// con [propio] = false los textos hablan "del socio" en vez de "a ti".
class ComposicionScreen extends StatelessWidget {
  final ComposicionCorporal composicion;

  /// Registros de peso, del más antiguo al más reciente.
  final List<PuntoEvolucion> pesos;
  final bool propio;
  final String? nombre;

  /// Abre "Tus datos" para completar el sexo (sin él no hay masa muscular).
  final VoidCallback? onCompletarDatos;

  const ComposicionScreen({
    super.key,
    required this.composicion,
    this.pesos = const [],
    this.propio = true,
    this.nombre,
    this.onCompletarDatos,
  });

  static const fotoCuerpo = 'assets/imagenes/medidas/cuerpo.jpg';

  @override
  Widget build(BuildContext context) {
    final c = composicion;
    final k = c.kilosParaSaludable;
    return PantallaApp(
      espacioAbajo: AppEspaciado.lg,
      children: [
        CabeceraApp(
          titulo: propio ? 'Mi IMC' : 'IMC y peso ideal',
          subtitulo: propio
              ? 'Tu peso, tu peso ideal y tu masa muscular'
              : nombre,
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaNutricion(
          foto: fotoCuerpo,
          alineacion: const Alignment(0, -0.35),
          icono: Icons.monitor_weight_rounded,
          chip: 'Índice de masa corporal',
          alto: 170,
          titulo: 'IMC ${numeroMedida(c.imc)} · ${c.nivel.nombre}',
          detalle: c.consejoPeso(propio: propio),
          pie: [
            DatoPie(
              icono: Icons.monitor_weight_rounded,
              valor: '${numeroMedida(c.pesoKg)} kg',
              pie: 'peso actual',
            ),
            DatoPie(
              icono: Icons.flag_rounded,
              valor: '${numeroMedida(c.pesoIdeal)} kg',
              pie: 'peso ideal',
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.speed_rounded,
          titulo: propio ? '¿Dónde estás?' : '¿Dónde está?',
        ),
        TarjetaPlana(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EscalaImc(imc: c.imc),
              const SizedBox(height: AppEspaciado.md),
              for (final n in NivelImc.values) _filaNivel(n, n == c.nivel),
            ],
          ),
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(icono: Icons.flag_rounded, titulo: 'Peso ideal'),
        TarjetaPlana(
          child: Column(
            children: [
              Row(
                children: [
                  _dato('Mínimo', '${numeroMedida(c.pesoMinSaludable)} kg'),
                  _dato(
                    'Ideal',
                    '${numeroMedida(c.pesoIdeal)} kg',
                    destacar: true,
                  ),
                  _dato('Máximo', '${numeroMedida(c.pesoMaxSaludable)} kg'),
                ],
              ),
              const SizedBox(height: AppEspaciado.md),
              _AvisoColor(
                color: k == 0 ? AppColores.activo : c.nivel.color,
                icono: k == 0
                    ? Icons.check_circle_rounded
                    : k > 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
                texto: c.consejoPeso(propio: propio),
              ),
              const SizedBox(height: AppEspaciado.sm),
              Text(
                'Con ${numeroMedida(c.alturaCm)} cm el peso saludable va de '
                '${numeroMedida(c.pesoMinSaludable)} a '
                '${numeroMedida(c.pesoMaxSaludable)} kg (IMC 18.5 a 24.9).',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.35,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.fitness_center_rounded,
          titulo: 'Masa muscular',
          detalle: 'estimada',
        ),
        _masaMuscular(),
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.show_chart_rounded,
          titulo: 'Evolución del peso',
          detalle: pesos.isEmpty ? null : '${pesos.length}',
        ),
        GraficoEvolucion(
          puntos: [
            for (final p in pesos)
              PuntoEvolucion(
                p.fecha,
                p.valor,
                detalle: 'IMC ${numeroMedida(c.imcDe(p.valor))}',
              ),
          ],
          unidad: 'kg',
          mejorSiSube: k == 0 ? null : k > 0,
          textoVacio: 'Registra el peso y aparecerá aquí',
          textoUnPunto: 'Con otro registro de peso verás la curva',
        ),
        const SizedBox(height: AppEspaciado.md),
        const Text(
          'IMC = peso ÷ (altura × altura). Es una guía general: en personas '
          'muy musculosas puede marcar sobrepeso sin haber exceso de grasa.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _masaMuscular() {
    final c = composicion;
    if (!c.puedeEstimarMusculo) {
      final falta = [
        if (c.sexo == null) 'el sexo',
        if (c.edad == null) 'la fecha de nacimiento',
      ].join(' y ');
      return TarjetaPlana(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const IconoSuave(Icons.info_outline_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Para calcularla falta $falta.',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
            if (c.edad == null) ...[
              const SizedBox(height: 6),
              const Text(
                'La fecha de nacimiento se registra en recepción.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
            if (c.sexo == null && onCompletarDatos != null) ...[
              const SizedBox(height: AppEspaciado.sm + 4),
              BotonFoto(
                'Completar datos',
                icono: Icons.edit_rounded,
                onTap: onCompletarDatos!,
              ),
            ],
          ],
        ),
      );
    }
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _TarjetaEstimado(
                icono: Icons.fitness_center_rounded,
                titulo: 'Masa muscular',
                valor: '${numeroMedida(c.masaMagraKg!)} kg',
                nivel: c.nivelMusculo!,
                pie: 'Índice ${numeroMedida(c.indiceMasaMuscular!)}',
              ),
            ),
            const SizedBox(width: AppEspaciado.sm + 4),
            Expanded(
              child: _TarjetaEstimado(
                icono: Icons.water_drop_rounded,
                titulo: 'Grasa corporal',
                valor: '${numeroMedida(c.grasaPct!)} %',
                nivel: c.nivelGrasa!,
                pie: '${numeroMedida(c.masaGrasaKg!)} kg de grasa',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.sm),
        const Text(
          'Calculado con el peso, la altura, la edad y el sexo. Para un dato '
          'exacto usa una balanza de bioimpedancia.',
          style: TextStyle(
            fontSize: 12,
            height: 1.35,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _filaNivel(NivelImc n, bool actual) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(color: n.color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: Text(
              n.nombre,
              style: TextStyle(
                fontSize: 14,
                fontWeight: actual ? FontWeight.w800 : FontWeight.w500,
                color: actual ? n.color : AppColores.textoPrincipal,
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Text(
              n.rango,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: actual ? FontWeight.w800 : FontWeight.w500,
                color: actual ? n.color : AppColores.textoSecundario,
              ),
            ),
          ),
          SizedBox(
            width: 28,
            child: actual
                ? Icon(Icons.arrow_left_rounded, color: n.color, size: 26)
                : null,
          ),
        ],
      ),
    );
  }

  Widget _dato(String titulo, String valor, {bool destacar = false}) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: destacar ? 19 : 15,
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
}

/// Barra de colores con los 6 niveles del IMC y una marca donde está el socio.
class EscalaImc extends StatelessWidget {
  final double imc;

  const EscalaImc({super.key, required this.imc});

  // Cada nivel ocupa lo mismo en la barra (si fuera proporcional al IMC,
  // "normal" y "sobrepeso" quedarían muy chicos).
  static const _limiteVisual = 45.0;
  static const _cortes = ['18.5', '25', '30', '35', '40'];

  double get _posicion {
    final niveles = NivelImc.values;
    final n = NivelImc.de(imc);
    final i = niveles.indexOf(n);
    final desde = n == NivelImc.bajoPeso ? 14.0 : n.desde;
    final hasta = n == NivelImc.obesidad3 ? _limiteVisual : n.hasta;
    final dentro = ((imc - desde) / (hasta - desde)).clamp(0.0, 1.0);
    return (i + dentro) / niveles.length;
  }

  @override
  Widget build(BuildContext context) {
    final nivel = NivelImc.de(imc);
    return LayoutBuilder(
      builder: (context, c) {
        final ancho = c.maxWidth;
        const burbuja = 64.0;
        final x = (_posicion * ancho - burbuja / 2).clamp(0.0, ancho - burbuja);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.only(left: x),
              child: Container(
                width: burbuja,
                padding: const EdgeInsets.symmetric(vertical: 4),
                decoration: BoxDecoration(
                  color: nivel.color,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  numeroMedida(imc),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.only(left: x + burbuja / 2 - 6),
              child: Icon(
                Icons.arrow_drop_down_rounded,
                color: nivel.color,
                size: 22,
              ),
            ),
            Row(
              children: [
                for (final n in NivelImc.values) ...[
                  if (n != NivelImc.bajoPeso) const SizedBox(width: 3),
                  Expanded(
                    child: Container(
                      height: n == nivel ? 12 : 8,
                      decoration: BoxDecoration(
                        color: n == nivel
                            ? n.color
                            : n.color.withValues(alpha: 0.45),
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: 14,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (final (i, t) in _cortes.indexed)
                    Positioned(
                      left: ancho * (i + 1) / NivelImc.values.length - 16,
                      width: 32,
                      child: Text(
                        t,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AvisoColor extends StatelessWidget {
  final Color color;
  final IconData icono;
  final String texto;

  const _AvisoColor({
    required this.color,
    required this.icono,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        children: [
          Icon(icono, color: color, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaEstimado extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String valor;
  final NivelEstimado nivel;
  final String pie;

  const _TarjetaEstimado({
    required this.icono,
    required this.titulo,
    required this.valor,
    required this.nivel,
    required this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaPlana(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconoSuave(icono, color: nivel.color),
          const SizedBox(height: 10),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColores.textoSecundario,
            ),
          ),
          Text(
            valor,
            style: TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: nivel.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              nivel.nombre,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: nivel.color,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            pie,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}
