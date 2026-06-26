import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Mini gráfico de línea dibujado con [CustomPainter] (sin dependencias).
///
/// Pensado para mostrar la progresión de marcas (peso) de un ejercicio.
class GraficoLinea extends StatelessWidget {
  final List<double> valores;
  final Color color;
  final double altura;

  const GraficoLinea({
    super.key,
    required this.valores,
    this.color = AppColores.acento,
    this.altura = 70,
  });

  @override
  Widget build(BuildContext context) {
    if (valores.length < 2) {
      return SizedBox(
        height: altura,
        child: Center(
          child: Text(
            valores.isEmpty
                ? 'Sin marcas registradas'
                : 'Registra otra marca para ver tu progreso',
            style: const TextStyle(
              fontSize: 12,
              color: AppColores.textoSecundario,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: altura,
      width: double.infinity,
      child: CustomPaint(
        painter: _LineaPainter(valores: valores, color: color),
      ),
    );
  }
}

class _LineaPainter extends CustomPainter {
  final List<double> valores;
  final Color color;

  _LineaPainter({required this.valores, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final minimo = valores.reduce((a, b) => a < b ? a : b);
    final maximo = valores.reduce((a, b) => a > b ? a : b);
    final rango = (maximo - minimo).abs() < 0.001 ? 1.0 : maximo - minimo;

    const padInferior = 6.0;
    const padSuperior = 6.0;
    final alto = size.height - padInferior - padSuperior;
    final paso = valores.length > 1 ? size.width / (valores.length - 1) : 0;

    Offset puntoEn(int i) {
      final x = paso * i;
      final norm = (valores[i] - minimo) / rango;
      final y = padSuperior + alto * (1 - norm);
      return Offset(x.toDouble(), y);
    }

    // Área bajo la curva.
    final area = Path()..moveTo(0, size.height);
    for (var i = 0; i < valores.length; i++) {
      area.lineTo(puntoEn(i).dx, puntoEn(i).dy);
    }
    area
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(
      area,
      Paint()..color = color.withValues(alpha: 0.10),
    );

    // Línea.
    final linea = Path()..moveTo(puntoEn(0).dx, puntoEn(0).dy);
    for (var i = 1; i < valores.length; i++) {
      linea.lineTo(puntoEn(i).dx, puntoEn(i).dy);
    }
    canvas.drawPath(
      linea,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Puntos.
    final relleno = Paint()..color = color;
    final borde = Paint()..color = Colors.white;
    for (var i = 0; i < valores.length; i++) {
      canvas.drawCircle(puntoEn(i), 4, relleno);
      canvas.drawCircle(puntoEn(i), 1.8, borde);
    }
  }

  @override
  bool shouldRepaint(_LineaPainter old) =>
      old.valores != valores || old.color != color;
}
