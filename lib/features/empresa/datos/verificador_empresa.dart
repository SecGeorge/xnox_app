import 'package:dio/dio.dart';
import 'package:xnox_app/core/network/http_service.dart';

/// En qué termina la comprobación del código escrito en el arranque.
enum ResultadoVerificacion {
  /// En la URL de ese código responde nuestra API: el gimnasio existe.
  valido,

  /// El código no corresponde a ningún gimnasio: o no hay nada en esa URL, o
  /// lo que responde no es nuestra API.
  gimnasioNoEncontrado,

  /// El teléfono no tiene red, así que no se puede afirmar nada del código.
  sinConexion,
}

/// Comprueba que el código escrito en el arranque corresponde a un gimnasio
/// real antes de guardarlo. Sin esta comprobación un código mal escrito
/// dejaría la app apuntando a una URL muerta y sin forma de volver a pedirlo.
///
/// Se comprueba que en esa URL responda nuestra API, no que el código coincida
/// con la constante `CODIGO_GIMNASIO` del servidor: todos los despliegues
/// comparten hoy el mismo valor, así que esa comparación rechazaría códigos
/// buenos. Lo que identifica al gimnasio es su URL.
///
/// Usa su propio Dio (no [HttpService]) para no tocar la ruta activa ni
/// disparar los avisos globales de "sin conexión" mientras se valida.
class VerificadorEmpresa {
  const VerificadorEmpresa();

  static const Duration _espera = Duration(seconds: 8);

  Future<ResultadoVerificacion> verificar(String rutaGlobal, String codigo) async {
    final dio = _cliente(rutaGlobal);
    try {
      final sucursales = await _sucursales(dio, codigo);
      // Solo nuestra API devuelve `datos` en esta ruta. Un hosting sin la API
      // responde HTML o un error JSON sin ese campo.
      return sucursales != null
          ? ResultadoVerificacion.valido
          : ResultadoVerificacion.gimnasioNoEncontrado;
    } catch (_) {
      // Con red, que no haya respuesta significa que ese subdominio no existe:
      // el código está mal escrito. Sin red no se puede concluir nada.
      return await HttpService().hayInternet()
          ? ResultadoVerificacion.gimnasioNoEncontrado
          : ResultadoVerificacion.sinConexion;
    } finally {
      dio.close();
    }
  }

  /// Cuál de [candidatos] reconoce el servidor de [rutaGlobal] como su código de
  /// gimnasio, o `null` si ninguno. Es el que hay que enviarle en las
  /// peticiones que lo piden (p. ej. el registro de clientes), y no tiene por
  /// qué ser el que escribió el usuario.
  Future<String?> codigoQueReconoce(
    String rutaGlobal,
    List<String> candidatos,
  ) async {
    final dio = _cliente(rutaGlobal);
    try {
      for (final candidato in candidatos) {
        if (candidato.isEmpty) continue;
        try {
          final sucursales = await _sucursales(dio, candidato);
          // Devuelve sucursales solo cuando el código es el suyo.
          if (sucursales != null && sucursales.isNotEmpty) return candidato;
        } catch (_) {
          return null; // Se cayó la red a mitad: no afirmamos nada.
        }
      }
      return null;
    } finally {
      dio.close();
    }
  }

  Dio _cliente(String rutaGlobal) => Dio(BaseOptions(
        baseUrl: rutaGlobal,
        connectTimeout: _espera,
        receiveTimeout: _espera,
        contentType: Headers.jsonContentType,
        // Un 404 no debe lanzar: lo tratamos como "no es nuestra API".
        validateStatus: (_) => true,
      ));

  /// Sucursales que devuelve el gimnasio para [codigo] (lista vacía si ese no es
  /// su código), o `null` si lo que responde no es nuestra API.
  Future<List<dynamic>?> _sucursales(Dio dio, String codigo) async {
    final respuesta = await dio.post('sucursal.php', data: {
      'metodo': 'por_codigo_gimnasio',
      'codigo_gimnasio': codigo,
    });
    final cuerpo = respuesta.data;
    final datos = cuerpo is Map ? cuerpo['datos'] : null;
    return datos is List ? datos : null;
  }
}
