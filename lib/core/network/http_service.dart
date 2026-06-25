import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HttpService {
  //static const String RUTA_GLOBAL = "https://xnonx.xnoxsoft.es/api/";
  static const String RUTA_GLOBAL = "http://192.168.1.60/sistema_gimnasio_vf/api/";
  static final HttpService _instance = HttpService._internal();
  late Dio _dio;
  late CookieJar _cookieJar;

  factory HttpService() => _instance;

  HttpService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: RUTA_GLOBAL,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    _cookieJar = CookieJar();
    _dio.interceptors.add(CookieManager(_cookieJar));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        // Ensure we send JSON as default
        options.contentType = Headers.jsonContentType;
        return handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          final recuperado = await intentarRecuperarSesion();
          if (recuperado) {
            // Retry the original request
            try {
              final response = await _dio.request(
                e.requestOptions.path,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
                options: Options(
                  method: e.requestOptions.method,
                  contentType: e.requestOptions.contentType,
                ),
              );
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(retryError as DioException);
            }
          } else {
            // Clear session and redirect (handle this in UI)
            final prefs = await SharedPreferences.getInstance();
            await prefs.clear();
          }
        }
        return handler.next(e);
      },
    ));
  }

  Future<bool> intentarRecuperarSesion() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('idUsuario');
    final sucursalId = prefs.getString('idSucursal');

    if (usuarioId == null || sucursalId == null) return false;

    try {
      final response = await _dio.post('usuarios.php', data: {
        'metodo': 'recuperar_sesion',
        'usuario_id': usuarioId,
        'sucursal_id': sucursalId,
      });
      
      final resultado = response.data;
      return resultado['resultado'] == true;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> registrar(Map<String, dynamic> datos, String ruta) async {
    try {
      final response = await _dio.post(ruta, data: datos);
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> obtenerConDatos(Map<String, dynamic> datos, String ruta) async {
    try {
      final response = await _dio.post(ruta, data: datos);
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> eliminar(String ruta, Map<String, dynamic> datos) async {
    try {
      final response = await _dio.post(ruta, data: datos);
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> subirArchivo(FormData formData, String url) async {
    try {
      final response = await _dio.post(
        url,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> registrarConImagen(FormData formData, String ruta) async {
    return await subirArchivo(formData, ruta);
  }

  Future<void> exportar(String ruta, Map<String, dynamic> payload, String nombreArchivo) async {
    try {
      await _dio.download(
        ruta, 
        '${nombreArchivo}', // In real app, use path_provider to get valid path
        data: payload,
      );
    } on DioException catch (e) {
      print("Error exportando archivo: ${e.message}");
    }
  }

  dynamic _handleError(DioException e) {
    if (e.response != null) {
      return e.response?.data;
    }
    return {'success': false, 'error': e.message};
  }
}
