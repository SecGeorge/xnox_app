import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

/// Quita el fondo liso de un logo y lo devuelve como PNG transparente.
///
/// Toma como fondo el color más repetido en el borde de la imagen y lo borra
/// avanzando desde los bordes hacia adentro (relleno por inundación): así no
/// se comen las partes del logo que tengan ese mismo color pero estén
/// rodeadas por el dibujo. Los píxeles de transición quedan semitransparentes
/// para que el contorno no se vea dentado.
///
/// Devuelve null si la imagen no se puede leer o si su borde ya es
/// transparente (no hay fondo que quitar). Corre en un isolate.
Future<Uint8List?> quitarFondoLogo(Uint8List bytes) =>
    compute(_quitarFondo, bytes);

/// Distancia de color por debajo de la cual el píxel es fondo.
const _tolerancia = 48.0;

/// Hasta esta distancia el píxel es borde suave (alfa parcial).
const _toleranciaSuave = 90.0;

Uint8List? _quitarFondo(Uint8List bytes) {
  final original = img.decodeImage(bytes);
  if (original == null) return null;
  final imagen = original.convert(numChannels: 4);
  final ancho = imagen.width;
  final alto = imagen.height;

  // Color de fondo: el más frecuente del borde (agrupado de a 16 niveles para
  // que el ruido de compresión no lo divida en muchos colores).
  final conteo = <int, int>{};
  final borde = <int>[];
  void contar(int x, int y) {
    final p = imagen.getPixel(x, y);
    borde.add(y * ancho + x);
    if (p.a < 20) return;
    final clave =
        (p.r.toInt() >> 4) << 8 | (p.g.toInt() >> 4) << 4 | p.b.toInt() >> 4;
    conteo[clave] = (conteo[clave] ?? 0) + 1;
  }

  for (var x = 0; x < ancho; x++) {
    contar(x, 0);
    contar(x, alto - 1);
  }
  for (var y = 1; y < alto - 1; y++) {
    contar(0, y);
    contar(ancho - 1, y);
  }
  // Casi todo el borde transparente: el logo ya no tiene fondo.
  final opacos = conteo.values.fold(0, (a, b) => a + b);
  if (opacos < borde.length * 0.5) return null;

  final grupo = conteo.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  // Promedio real de los píxeles de ese grupo.
  var sr = 0.0, sg = 0.0, sb = 0.0, n = 0;
  for (final i in borde) {
    final p = imagen.getPixel(i % ancho, i ~/ ancho);
    final clave =
        (p.r.toInt() >> 4) << 8 | (p.g.toInt() >> 4) << 4 | p.b.toInt() >> 4;
    if (p.a < 20 || clave != grupo) continue;
    sr += p.r;
    sg += p.g;
    sb += p.b;
    n++;
  }
  final fr = sr / n, fg = sg / n, fb = sb / n;

  double distancia(img.Pixel p) {
    final dr = p.r - fr, dg = p.g - fg, db = p.b - fb;
    return dr * dr + dg * dg + db * db;
  }

  const tol2 = _tolerancia * _tolerancia;
  const suave2 = _toleranciaSuave * _toleranciaSuave;

  // Inundación desde el borde: solo avanza por píxeles de fondo.
  final visitado = Uint8List(ancho * alto);
  final cola = Queue<int>();
  for (final i in borde) {
    if (visitado[i] == 1) continue;
    final p = imagen.getPixel(i % ancho, i ~/ ancho);
    if (p.a < 20 || distancia(p) <= tol2) {
      visitado[i] = 1;
      cola.add(i);
    }
  }
  while (cola.isNotEmpty) {
    final i = cola.removeFirst();
    final x = i % ancho, y = i ~/ ancho;
    imagen.getPixel(x, y).a = 0;
    for (final (dx, dy) in const [(1, 0), (-1, 0), (0, 1), (0, -1)]) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= ancho || ny >= alto) continue;
      final j = ny * ancho + nx;
      if (visitado[j] == 1) continue;
      final q = imagen.getPixel(nx, ny);
      final d = distancia(q);
      if (q.a < 20 || d <= tol2) {
        visitado[j] = 1;
        cola.add(j);
      } else if (d < suave2) {
        // Contorno: alfa proporcional a qué tan lejos está del fondo.
        visitado[j] = 1;
        final dist = (d - tol2) / (suave2 - tol2);
        q.a = (q.a * dist.clamp(0.0, 1.0)).roundToDouble();
      }
    }
  }

  return Uint8List.fromList(img.encodePng(imagen));
}
