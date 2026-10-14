import 'package:flutter_test/flutter_test.dart';
import 'package:xnox_app/features/empresa/datos/directorio_gimnasios.dart';

void main() {
  test('lee el gimnasio que devuelve api/gimnasio.php', () {
    final g = GimnasioRegistrado.desdeJson({
      'codigo': 'OXYGEENFIT',
      'nombre': 'Oxygeen Fitness Club',
      'ruta_global': 'https://oxygeenfit.xnoxsoft.es/api',
      'codigo_backend': 'LOCAL',
    })!;
    expect(g.rutaGlobal, 'https://oxygeenfit.xnoxsoft.es/api/');
    expect(g.codigoBackend, 'LOCAL');
    expect(g.nombre, 'Oxygeen Fitness Club');
  });

  test('sin codigo_backend usa el código; null o sin URL no es gimnasio', () {
    final g = GimnasioRegistrado.desdeJson({
      'codigo': 'XNONX',
      'ruta_global': 'https://xnonx.xnoxsoft.es/api/',
    })!;
    expect(g.codigoBackend, 'XNONX');
    expect(GimnasioRegistrado.desdeJson(null), isNull);
    expect(GimnasioRegistrado.desdeJson({'codigo': 'X', 'ruta_global': ''}), isNull);
  });
}
