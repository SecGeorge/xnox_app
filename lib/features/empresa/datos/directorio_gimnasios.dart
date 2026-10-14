import 'package:dio/dio.dart';

/// Lo que el panel de XNOX sabe de un gimnasio registrado: a qué servidor va
/// la app con ese código y qué código reconoce ese servidor.
class GimnasioRegistrado {
  final String codigo;
  final String nombre;
  final String rutaGlobal;
  final String codigoBackend;

  const GimnasioRegistrado({
    required this.codigo,
    required this.nombre,
    required this.rutaGlobal,
    required this.codigoBackend,
  });

  /// `null` si a la respuesta le falta lo imprescindible.
  static GimnasioRegistrado? desdeJson(Object? json) {
    if (json is! Map) return null;
    final codigo = (json['codigo'] ?? '').toString().trim();
    final ruta = (json['ruta_global'] ?? '').toString().trim();
    if (codigo.isEmpty || !ruta.startsWith('http')) return null;
    final backend = (json['codigo_backend'] ?? '').toString().trim();
    return GimnasioRegistrado(
      codigo: codigo,
      nombre: (json['nombre'] ?? '').toString().trim(),
      rutaGlobal: ruta.endsWith('/') ? ruta : '$ruta/',
      codigoBackend: backend.isEmpty ? codigo : backend,
    );
  }
}

/// Directorio de gimnasios del panel de XNOX (Clientes → Acceso a la app).
/// Con él, dar de alta un gimnasio en la app ya no requiere tocar el código:
/// basta con registrarlo en el panel. Usa su propio Dio porque es otro
/// servidor que el del gimnasio.
class DirectorioGimnasios {
  const DirectorioGimnasios();

  static const _url = 'https://www.xnoxsoft.es/api/gimnasio.php';

  /// El gimnasio registrado con [codigo], o `null` si el panel no lo tiene.
  /// Lanza si el panel no responde: quien llama sigue entonces con lo que ya
  /// sabía (tabla `empresa` o subdominio).
  Future<GimnasioRegistrado?> consultar(String codigo) async {
    final dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 6),
        receiveTimeout: const Duration(seconds: 6),
        // 404 = no registrado, no es un fallo.
        validateStatus: (s) => s != null && s < 500,
      ),
    );
    try {
      final resp = await dio.get<dynamic>(
        _url,
        queryParameters: {'codigo': codigo},
      );
      final datos = resp.data;
      if (datos is! Map || !datos.containsKey('gimnasio')) {
        throw Exception('Respuesta inesperada del directorio de XNOX');
      }
      return GimnasioRegistrado.desdeJson(datos['gimnasio']);
    } finally {
      dio.close();
    }
  }
}
