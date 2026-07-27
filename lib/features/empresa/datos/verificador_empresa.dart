import 'package:dio/dio.dart';

/// En qué termina la comprobación del código escrito en el arranque.
enum ResultadoVerificacion {
  /// El gimnasio respondió y reconoció el código.
  valido,

  /// Hay servidor en esa URL, pero el código no es el suyo.
  codigoNoCoincide,

  /// No contestó nuestra API: URL inexistente, servidor caído o sin red.
  sinRespuesta,
}

/// Comprueba que el código escrito en el arranque corresponde a un gimnasio
/// real antes de guardarlo. Sin esta comprobación un código mal escrito
/// dejaría la app apuntando a una URL muerta y sin forma de volver a pedirlo.
///
/// Usa su propio Dio (no [HttpService]) para no tocar la ruta activa ni
/// disparar los avisos globales de "sin conexión" mientras se valida.
class VerificadorEmpresa {
  const VerificadorEmpresa();

  static const Duration _espera = Duration(seconds: 8);

  Future<ResultadoVerificacion> verificar(String rutaGlobal, String codigo) async {
    final dio = Dio(BaseOptions(
      baseUrl: rutaGlobal,
      connectTimeout: _espera,
      receiveTimeout: _espera,
      contentType: Headers.jsonContentType,
    ));
    try {
      // `por_codigo_gimnasio` compara el código con la constante del gimnasio y
      // solo devuelve sus sucursales si coincide: es la validación exacta.
      // Probamos también en minúsculas por si algún despliegue definió así su
      // constante, para no rechazar un código que sí es correcto.
      for (final variante in {codigo, codigo.toLowerCase()}) {
        final sucursales = await _sucursales(dio, variante);
        if (sucursales == null) return ResultadoVerificacion.sinRespuesta;
        if (sucursales.isNotEmpty) return ResultadoVerificacion.valido;
      }
      return ResultadoVerificacion.codigoNoCoincide;
    } finally {
      dio.close();
    }
  }

  /// Sucursales que devuelve el gimnasio para [codigo] (lista vacía si el
  /// código no es el suyo), o `null` si no contestó nuestra API.
  Future<List<dynamic>?> _sucursales(Dio dio, String codigo) async {
    try {
      final respuesta = await dio.post('sucursal.php', data: {
        'metodo': 'por_codigo_gimnasio',
        'codigo_gimnasio': codigo,
      });
      final cuerpo = respuesta.data;
      final datos = cuerpo is Map ? cuerpo['datos'] : null;
      return datos is List ? datos : null;
    } catch (_) {
      return null;
    }
  }
}
