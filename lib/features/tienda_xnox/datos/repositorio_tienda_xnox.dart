import 'package:dio/dio.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/features/tienda_xnox/dominio/producto_xnox.dart';

/// Lee la tienda de XNOX del sitio de XNOX (panel → Tienda). Es otro
/// servidor que el del gimnasio, así que usa su propio Dio y no
/// [HttpService], cuya ruta cambia con la empresa activa.
class RepositorioTiendaXnox {
  RepositorioTiendaXnox._();
  static final RepositorioTiendaXnox instancia = RepositorioTiendaXnox._();

  /// Raíz del sitio de XNOX. Las fotos llegan como `/uploads/…` y se
  /// resuelven contra esta misma raíz.
  static const sitio = 'https://www.xnoxsoft.es';

  final _dio = Dio(
    BaseOptions(
      baseUrl: '$sitio/api/',
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  /// Productos que el panel publicó para [publico] en el gimnasio activo.
  /// El gimnasio se identifica por el código que se escribió al abrir la app;
  /// el panel decide en cuáles se oculta cada producto.
  Future<List<ProductoXnox>> productos(PublicoTiendaXnox publico) async {
    final empresa = await EmpresaDao.instancia.activa();
    final resp = await _dio.get<dynamic>(
      'tienda.php',
      queryParameters: {
        'gimnasio': empresa?.codigo ?? '',
        'para': publico.clave,
      },
    );
    final datos = resp.data is Map ? resp.data['productos'] : null;
    if (datos is! List) {
      throw Exception('Respuesta inesperada de la tienda de XNOX');
    }
    return datos
        .whereType<Map>()
        .map((p) => ProductoXnox.fromJson(Map<String, dynamic>.from(p)))
        .where((p) => p.nombre.isNotEmpty)
        .toList();
  }

  /// URL absoluta de la foto de un producto, o vacía si no tiene.
  static String urlImagen(String ruta) {
    if (ruta.isEmpty || ruta.startsWith('http')) return ruta;
    return '$sitio${ruta.startsWith('/') ? '' : '/'}$ruta';
  }
}
