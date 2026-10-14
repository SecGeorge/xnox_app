import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:xnox_app/core/utils/quitar_fondo.dart';

void main() {
  /// Aro rojo con hueco blanco sobre fondo blanco, guardado como JPEG (con
  /// el ruido de compresión de una foto de verdad).
  Uint8List logoConFondo() {
    final i = img.Image(width: 200, height: 120);
    img.fill(i, color: img.ColorRgb8(255, 255, 255));
    img.fillCircle(
      i,
      x: 100,
      y: 60,
      radius: 40,
      color: img.ColorRgb8(192, 57, 43),
    );
    img.fillCircle(
      i,
      x: 100,
      y: 60,
      radius: 15,
      color: img.ColorRgb8(255, 255, 255),
    );
    return Uint8List.fromList(img.encodeJpg(i, quality: 85));
  }

  test('quita el fondo blanco y conserva el logo', () async {
    final r = await quitarFondoLogo(logoConFondo());
    expect(r, isNotNull);
    final i = img.decodePng(r!)!;
    expect(i.getPixel(0, 0).a, 0);
    expect(i.getPixel(10, 60).a, 0);
    expect(i.getPixel(100, 25).a, 255); // aro rojo
    // El hueco blanco está rodeado por el logo: no es fondo.
    expect(i.getPixel(100, 60).a, 255);
  });

  test('un logo ya transparente no tiene fondo que quitar', () async {
    final sinFondo = await quitarFondoLogo(logoConFondo());
    expect(await quitarFondoLogo(sinFondo!), isNull);
  });
}
