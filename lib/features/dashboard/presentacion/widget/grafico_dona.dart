import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Un segmento del gráfico de dona.
class SegmentoDona {
  final String etiqueta;
  final int valor;
  final Color color;

  const SegmentoDona(this.etiqueta, this.valor, this.color);
}

/// Gráfico de dona dibujado con [CustomPainter] (sin dependencias externas).
///
/// Muestra el desglose de [segmentos] y, en el centro, un valor con su
/// etiqueta (por ejemplo, el total de miembros).
class GraficoDona extends StatelessWidget {
  final List<SegmentoDona> segmentos;
  final double tamano;
  final double grosor;
  final String centroValor;
  final String centroEtiqueta;

  const GraficoDona({
    super.key,
    required this.segmentos,
    required this.centroValor,
    required this.centroEtiqueta,
    this.tamano = 130,
    this.grosor = 18,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: tamano,
      height: tamano,
      child: CustomPaint(
        painter: _DonaPainter(segmentos: segmentos, grosor: grosor),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                centroValor,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
              Text(
                centroEtiqueta,
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonaPainter extends CustomPainter {
  final List<SegmentoDona> segmentos;
  final double grosor;

  _DonaPainter({required this.segmentos, required this.grosor});

  @override
  void paint(Canvas canvas, Size size) {
    final total = segmentos.fold<int>(0, (s, e) => s + e.valor);
    final centro = Offset(size.width / 2, size.height / 2);
    final radio = (size.width - grosor) / 2;
    final rect = Rect.fromCircle(center: centro, radius: radio);

    // Pista de fondo.
    final fondo = Paint()
      ..color = AppColores.borde
      ..style = PaintingStyle.stroke
      ..strokeWidth = grosor;
    canvas.drawCircle(centro, radio, fondo);

    if (total == 0) return;

    const espacio = 0.04; // separación entre segmentos (radianes)
    double inicio = -math.pi / 2; // arrancar arriba

    for (final seg in segmentos) {
      if (seg.valor == 0) continue;
      final barrido = (seg.valor / total) * (2 * math.pi) - espacio;
      final pintura = Paint()
        ..color = seg.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = grosor
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, inicio + espacio / 2, barrido, false, pintura);
      inicio += (seg.valor / total) * (2 * math.pi);
    }
  }

  @override
  bool shouldRepaint(_DonaPainter old) =>
      old.segmentos != segmentos || old.grosor != grosor;
}
