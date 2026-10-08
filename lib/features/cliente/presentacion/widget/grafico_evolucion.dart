import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';

/// Un punto de la gráfica: un valor en una fecha, con un detalle opcional
/// que se muestra al seleccionarlo (p. ej. "12 · 10 · 8 reps").
class PuntoEvolucion {
  final DateTime fecha;
  final double valor;
  final String? detalle;

  const PuntoEvolucion(this.fecha, this.valor, {this.detalle});
}

/// 38.0 -> "38", 38.5 -> "38.5".
String _numero(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

/// Gráfica de evolución (medidas corporales, cargas de un ejercicio…): curva
/// suave con relleno degradado, escala a la izquierda, fechas abajo y un punto
/// seleccionable (tocar o arrastrar) cuyo valor y fecha salen en la cabecera.
/// Se muestra siempre, incluso sin datos, con un aviso.
class GraficoEvolucion extends StatefulWidget {
  /// Puntos del más antiguo al más reciente. Puede venir vacía.
  final List<PuntoEvolucion> puntos;
  final String unidad;

  /// Hacia dónde es bueno el cambio: true = subir (verde al subir), false =
  /// bajar, null = neutro (sin verde ni rojo).
  final bool? mejorSiSube;

  /// Valor grande del punto seleccionado arriba. Sin cabecera, el valor solo
  /// se ve en el globo sobre el punto.
  final bool cabecera;

  /// Envuelve la gráfica en su propia tarjeta. Desactívalo si ya va dentro de
  /// otra tarjeta.
  final bool enTarjeta;
  final double alto;
  final String textoVacio;
  final String textoUnPunto;

  const GraficoEvolucion({
    super.key,
    required this.puntos,
    required this.unidad,
    this.mejorSiSube = true,
    this.cabecera = true,
    this.enTarjeta = true,
    this.alto = 190,
    this.textoVacio = 'Registra tu primer dato y aparecerá aquí',
    this.textoUnPunto = 'Registra otro dato para ver tu curva',
  });

  @override
  State<GraficoEvolucion> createState() => _GraficoEvolucionState();
}

class _GraficoEvolucionState extends State<GraficoEvolucion> {
  /// Punto seleccionado; null = el último.
  int? _sel;

  int get _indice {
    final n = widget.puntos.length;
    return (_sel == null || _sel! >= n) ? n - 1 : _sel!;
  }

  @override
  void didUpdateWidget(GraficoEvolucion old) {
    super.didUpdateWidget(old);
    // Al agregar o borrar un dato se vuelve a mostrar el último.
    if (old.puntos.length != widget.puntos.length) _sel = null;
  }

  void _seleccionar(double x, double ancho) {
    final n = widget.puntos.length;
    if (n < 2) return;
    final util =
        ancho - _PintorEvolucion.margenIzq - _PintorEvolucion.margenDer;
    final rel = ((x - _PintorEvolucion.margenIzq) / util).clamp(0.0, 1.0);
    final i = (rel * (n - 1)).round();
    if (i != _indice) {
      HapticFeedback.selectionClick();
      setState(() => _sel = i);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.puntos;
    final i = _indice;
    final actual = p.isEmpty ? null : p[i];
    final diferencia = i <= 0 ? null : actual!.valor - p[i - 1].valor;
    final ayuda = switch (p.length) {
      0 => widget.textoVacio,
      1 => widget.textoUnPunto,
      _ => widget.cabecera ? 'Toca o desliza para ver cada registro' : null,
    };

    final contenido = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.cabecera) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      actual == null
                          ? 'Aún sin registros'
                          : [
                              if (i == p.length - 1) 'Último',
                              _fecha(actual.fecha),
                              if (actual.detalle != null) actual.detalle!,
                            ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: actual == null ? '—' : _numero(actual.valor),
                          ),
                          TextSpan(
                            text: ' ${widget.unidad}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 30,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                  ],
                ),
              ),
              if (diferencia != null)
                _ChipDiferencia(
                  diferencia: diferencia,
                  unidad: widget.unidad,
                  mejorSiSube: widget.mejorSiSube,
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
        ],
        LayoutBuilder(
          builder: (context, restr) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _seleccionar(d.localPosition.dx, restr.maxWidth),
            onHorizontalDragUpdate: (d) =>
                _seleccionar(d.localPosition.dx, restr.maxWidth),
            child: TweenAnimationBuilder<double>(
              // Al abrir, la curva se dibuja de izquierda a derecha.
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 650),
              curve: Curves.easeOutCubic,
              builder: (_, avance, _) => CustomPaint(
                size: Size(restr.maxWidth, widget.alto),
                painter: _PintorEvolucion(
                  valores: [for (final x in p) x.valor],
                  etiquetas: [for (final x in p) _fechaCorta(x.fecha)],
                  seleccionado: i,
                  avance: avance,
                  color: AppColores.primario,
                  colorTexto: AppColores.textoSecundario,
                  colorRejilla: AppColores.borde,
                  colorFondo: AppColores.superficie,
                ),
              ),
            ),
          ),
        ),
        if (ayuda != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              ayuda,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                color: AppColores.textoSecundario.withValues(alpha: 0.8),
              ),
            ),
          ),
        ],
      ],
    );

    if (!widget.enTarjeta) return contenido;
    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(
        AppEspaciado.md,
        AppEspaciado.md,
        AppEspaciado.md,
        AppEspaciado.sm + 4,
      ),
      child: contenido,
    );
  }

  String _fecha(DateTime f) => DateFormat('d MMM yyyy', 'es').format(f);
  String _fechaCorta(DateTime f) => DateFormat('d MMM', 'es').format(f);
}

/// Cambio respecto al registro anterior: verde si va hacia donde conviene,
/// rojo si va al revés y neutro si da igual.
class _ChipDiferencia extends StatelessWidget {
  final double diferencia;
  final String unidad;
  final bool? mejorSiSube;

  const _ChipDiferencia({
    required this.diferencia,
    required this.unidad,
    required this.mejorSiSube,
  });

  @override
  Widget build(BuildContext context) {
    final bueno = diferencia == 0 || mejorSiSube == null
        ? null
        : (diferencia > 0) == mejorSiSube;
    final color = bueno == null
        ? AppColores.textoSecundario
        : bueno
        ? AppColores.activo
        : AppColores.moroso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            diferencia > 0
                ? Icons.trending_up_rounded
                : diferencia < 0
                ? Icons.trending_down_rounded
                : Icons.trending_flat_rounded,
            size: 16,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            diferencia == 0
                ? 'Igual'
                : '${diferencia > 0 ? '+' : ''}${_numero(diferencia)} $unidad',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _PintorEvolucion extends CustomPainter {
  final List<double> valores;
  final List<String> etiquetas;
  final int seleccionado;
  final double avance;
  final Color color;
  final Color colorTexto;
  final Color colorRejilla;
  final Color colorFondo;

  /// Espacio para la escala (izquierda), aire a la derecha y las fechas.
  static const margenIzq = 36.0;
  static const margenDer = 10.0;
  static const _margenSup = 12.0;
  static const _margenInf = 24.0;

  _PintorEvolucion({
    required this.valores,
    required this.etiquetas,
    required this.seleccionado,
    required this.avance,
    required this.color,
    required this.colorTexto,
    required this.colorRejilla,
    required this.colorFondo,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final n = valores.length;
    if (n == 0) {
      _pintarVacio(canvas, size);
      return;
    }
    final minV = valores.reduce((a, b) => a < b ? a : b);
    final maxV = valores.reduce((a, b) => a > b ? a : b);
    // Aire arriba y abajo para que la curva no toque los bordes.
    final rango = maxV - minV;
    final colchon = rango < 0.001 ? 1.0 : rango * 0.2;
    final bajo = minV - colchon;
    final alto = maxV + colchon;

    final ancho = size.width - margenIzq - margenDer;
    final altoUtil = size.height - _margenSup - _margenInf;
    final base = _margenSup + altoUtil;

    Offset punto(int i) => Offset(
      // Con un solo registro el punto va al centro.
      n == 1 ? margenIzq + ancho / 2 : margenIzq + ancho * i / (n - 1),
      _margenSup + altoUtil * (1 - (valores[i] - bajo) / (alto - bajo)),
    );

    // Rejilla horizontal punteada con la escala a la izquierda.
    final rejilla = Paint()
      ..color = colorRejilla
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = _margenSup + altoUtil * k / 3;
      for (var x = margenIzq; x < size.width - margenDer; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 3.5, y), rejilla);
      }
      final valor = alto - (alto - bajo) * k / 3;
      _texto(
        canvas,
        _numero(valor),
        Offset(0, y),
        ancho: margenIzq - 6,
        alinear: TextAlign.right,
        centrarVertical: true,
      );
    }

    // Fechas: la primera, la última y algunas intermedias sin amontonarse.
    final maxEtiquetas = (ancho / 58).floor().clamp(1, n);
    final mostradas = maxEtiquetas == 1
        ? <int>{n - 1}
        : <int>{
            for (var k = 0; k < maxEtiquetas; k++)
              (k * (n - 1) / (maxEtiquetas - 1)).round(),
          };
    for (final i in mostradas) {
      final p = punto(i);
      _texto(
        canvas,
        etiquetas[i],
        Offset(p.dx - 30, base + 7),
        ancho: 60,
        alinear: TextAlign.center,
        negrita: i == seleccionado,
      );
    }

    // Curva suave (cubic) entre los puntos.
    final puntos = [for (var i = 0; i < n; i++) punto(i)];
    final curva = Path()..moveTo(puntos.first.dx, puntos.first.dy);
    for (var i = 1; i < n; i++) {
      final a = puntos[i - 1];
      final b = puntos[i];
      final medio = (b.dx - a.dx) / 2;
      curva.cubicTo(a.dx + medio, a.dy, b.dx - medio, b.dy, b.dx, b.dy);
    }

    // La animación de entrada recorta la curva de izquierda a derecha.
    canvas.save();
    canvas.clipRect(
      Rect.fromLTWH(0, 0, margenIzq + ancho * avance + margenDer, size.height),
    );

    final area = Path.from(curva)
      ..lineTo(puntos.last.dx, base)
      ..lineTo(puntos.first.dx, base)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, _margenSup, size.width, altoUtil)),
    );
    canvas.drawPath(
      curva,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Puntos pequeños (si son muchos se omiten: solo ensuciarían).
    if (n <= 16) {
      for (final p in puntos) {
        canvas.drawCircle(p, 4, Paint()..color = colorFondo);
        canvas.drawCircle(
          p,
          4,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
    }
    canvas.restore();

    // Punto seleccionado: guía vertical, halo y globo con el valor.
    if (avance >= 1) {
      final p = puntos[seleccionado];
      final guia = Paint()
        ..color = color.withValues(alpha: 0.45)
        ..strokeWidth = 1.2;
      for (var y = p.dy + 8; y < base; y += 6) {
        canvas.drawLine(Offset(p.dx, y), Offset(p.dx, y + 3), guia);
      }
      canvas.drawCircle(p, 11, Paint()..color = color.withValues(alpha: 0.18));
      canvas.drawCircle(p, 6.5, Paint()..color = color);
      canvas.drawCircle(p, 2.8, Paint()..color = colorFondo);

      final globo = TextPainter(
        text: TextSpan(
          text: _numero(valores[seleccionado]),
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final w = globo.width + 14;
      const h = 22.0;
      final x = (p.dx - w / 2).clamp(0.0, size.width - w);
      // Encima del punto; si no cabe arriba, debajo.
      final y = p.dy - 16 - h < 0 ? p.dy + 16 : p.dy - 16 - h;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, y, w, h),
          const Radius.circular(8),
        ),
        Paint()..color = color,
      );
      globo.paint(canvas, Offset(x + 7, y + (h - globo.height) / 2));
    }
  }

  /// Sin datos: la misma rejilla punteada y una línea de base tenue, para
  /// que se vea dónde aparecerá la evolución.
  void _pintarVacio(Canvas canvas, Size size) {
    final altoUtil = size.height - _margenSup - _margenInf;
    final rejilla = Paint()
      ..color = colorRejilla
      ..strokeWidth = 1;
    for (var k = 0; k <= 3; k++) {
      final y = _margenSup + altoUtil * k / 3;
      for (var x = margenIzq; x < size.width - margenDer; x += 7) {
        canvas.drawLine(Offset(x, y), Offset(x + 3.5, y), rejilla);
      }
    }
    // Curva de ejemplo muy tenue.
    final ancho = size.width - margenIzq - margenDer;
    final ejemplo = Path()
      ..moveTo(margenIzq, _margenSup + altoUtil * 0.8)
      ..cubicTo(
        margenIzq + ancho * 0.35,
        _margenSup + altoUtil * 0.8,
        margenIzq + ancho * 0.55,
        _margenSup + altoUtil * 0.3,
        margenIzq + ancho,
        _margenSup + altoUtil * 0.25,
      );
    canvas.drawPath(
      ejemplo,
      Paint()
        ..color = color.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
  }

  void _texto(
    Canvas canvas,
    String texto,
    Offset origen, {
    required double ancho,
    TextAlign alinear = TextAlign.left,
    bool centrarVertical = false,
    bool negrita = false,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: texto,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: negrita ? FontWeight.w800 : FontWeight.w500,
          color: negrita ? color : colorTexto,
        ),
      ),
      textAlign: alinear,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout(minWidth: ancho, maxWidth: ancho);
    tp.paint(
      canvas,
      centrarVertical ? origen.translate(0, -tp.height / 2) : origen,
    );
  }

  @override
  bool shouldRepaint(_PintorEvolucion old) =>
      old.valores != valores ||
      old.seleccionado != seleccionado ||
      old.avance != avance ||
      old.color != color;
}
