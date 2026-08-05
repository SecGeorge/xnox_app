import 'package:flutter_test/flutter_test.dart';
import 'package:xnox_app/features/recomendaciones/dominio/filtro_contenido.dart';

void main() {
  const validos = [
    'Sería bueno tener más discos de 10 kg',
    'Me gustaría ver mi historial de pagos en la app',
    'el baño está sucio, por favor mejorar la limpieza',
    'el disputado horario de la mañana',
    'hay que calcular mejor el aforo',
    'poner mas espejos',
  ];
  const groserias = [
    'El profe es un conchasumadre',
    'que mierda de gimnasio',
    'c0nch4 de tu madre',
    'p u t a madre el aire acondicionado',
    'son unos ctm',
    'PUUUUTA que mal servicio',
  ];
  const basura = ['aaaaaaaaaa', 'sdfg sdfg sdfg', '1234567890', 'hola', '!!!!!!!!!!!!'];

  test('acepta recomendaciones normales', () {
    for (final t in validos) {
      expect(FiltroContenido.validar(t), isNull, reason: t);
    }
  });
  test('rechaza groserías con el aviso de respeto', () {
    for (final t in groserias) {
      expect(FiltroContenido.validar(t), FiltroContenido.avisoGroseria, reason: t);
    }
  });
  test('rechaza texto basura', () {
    for (final t in basura) {
      expect(FiltroContenido.validar(t), isNotNull, reason: t);
    }
  });
}
