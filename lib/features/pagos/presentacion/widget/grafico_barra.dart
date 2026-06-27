import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';

/// Gráfico de barras dibujado con [CustomPainter] (sin dependencias externas),
/// al estilo de [GraficoDona]/[GraficoLinea] del resto de la app.
///
/// Muestra una serie de [BarraPago] con etiqueta inferior y el valor encima de
/// cada barra. Equivalente a los gráficos de barras de `InicioComponent.vue`.
class GraficoBarra extends StatelessWidget {
  final List<BarraPago> datos;
  final Color colorInicio;
  final Color colorFin;
  final double altura;

  /// Formatea el valor mostrado encima de cada barra (p. ej. "S/ 540").
  final String Function(double) formatoValor;

  const GraficoBarra({
    super.key,
    required this.datos,
    required this.formatoValor,
    this.colorInicio = AppColores.verde,
    this.colorFin = AppColores.activo,
    this.altura = 200,
  });

  @override
  Widget build(BuildContext context) {
    final sinDatos = datos.isEmpty || datos.every((d) => d.total <= 0);
    if (sinDatos) {
      return SizedBox(
        height: altura,
        child: const Center(
          child: Text(
            'Sin pagos en el periodo',
            style: TextStyle(fontSize: 13, color: AppColores.textoSecundario),
          ),
        ),
      );
    }

    return SizedBox(
      height: altura,
      width: double.infinity,
      child: CustomPaint(
        painter: _BarraPainter(
          datos: datos,
          colorInicio: colorInicio,
          colorFin: colorFin,
          formatoValor: formatoValor,
        ),
      ),
    );
  }
}

class _BarraPainter extends CustomPainter {
  final List<BarraPago> datos;
  final Color colorInicio;
  final Color colorFin;
  final String Function(double) formatoValor;

  _BarraPainter({
    required this.datos,
    required this.colorInicio,
    required this.colorFin,
    required this.formatoValor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;

    const padSuperior = 18.0; // espacio para la etiqueta de valor
    const padInferior = 22.0; // espacio para la etiqueta del eje X
    final areaAlto = size.height - padSuperior - padInferior;
    final baseY = padSuperior + areaAlto;

    final maxVal = datos
        .map((d) => d.total)
        .fold<double>(0, (a, b) => b > a ? b : a);
    final maxSeguro = maxVal <= 0 ? 1.0 : maxVal;

    final slot = size.width / datos.length;
    final anchoBarra = (slot * 0.5).clamp(6.0, 46.0);

    // Línea base.
    canvas.drawLine(
      Offset(0, baseY),
      Offset(size.width, baseY),
      Paint()
        ..color = AppColores.borde
        ..strokeWidth = 1,
    );

    for (var i = 0; i < datos.length; i++) {
      final d = datos[i];
      final centroX = slot * i + slot / 2;
      final alturaBarra = (d.total / maxSeguro) * areaAlto;
      final izquierda = centroX - anchoBarra / 2;
      final arriba = baseY - alturaBarra;

      if (alturaBarra > 0) {
        final rect = Rect.fromLTWH(izquierda, arriba, anchoBarra, alturaBarra);
        final rrect = RRect.fromRectAndCorners(
          rect,
          topLeft: const Radius.circular(5),
          topRight: const Radius.circular(5),
        );
        final pintura = Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colorInicio, colorFin],
          ).createShader(rect);
        canvas.drawRRect(rrect, pintura);

        // Valor encima de la barra.
        _dibujarTexto(
          canvas,
          formatoValor(d.total),
          centroX,
          arriba - 14,
          fontSize: 9.5,
          peso: FontWeight.w600,
          maxWidth: slot,
        );
      }

      // Etiqueta del eje X.
      _dibujarTexto(
        canvas,
        d.etiqueta,
        centroX,
        baseY + 6,
        fontSize: 10.5,
        peso: FontWeight.w500,
        maxWidth: slot,
      );
    }
  }

  void _dibujarTexto(
    Canvas canvas,
    String texto,
    double centroX,
    double top, {
    required double fontSize,
    required FontWeight peso,
    required double maxWidth,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          color: AppColores.textoSecundario,
          fontSize: fontSize,
          fontWeight: peso,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(centroX - tp.width / 2, top));
  }

  @override
  bool shouldRepaint(_BarraPainter old) =>
      old.datos != datos ||
      old.colorInicio != colorInicio ||
      old.colorFin != colorFin;
}
