import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';

class HttpService {
  //static const String RUTA_GLOBAL = "https://xnonx.xnoxsoft.es/api/";
  // Ruta de arranque / fallback. La ruta real la define la empresa activa del
  // catálogo (tabla `empresa`), que se aplica en init() o al elegirla en la
  // pantalla de selección; esta constante solo se usa si la BD no da una ruta.
  static const String RUTA_GLOBAL = "http://192.168.1.47/sistema_gimnasio_vf/api/";
  static final HttpService _instance = HttpService._internal();
  late Dio _dio;
  late CookieManager _cookieManager;
  bool _cookiesPersistentes = false;

  factory HttpService() => _instance;

  HttpService._internal() {
    _dio = Dio(BaseOptions(
      baseUrl: RUTA_GLOBAL,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));

    // Jar en memoria como arranque; se reemplaza por uno persistente en init().
    _cookieManager = CookieManager(CookieJar());
    _dio.interceptors.add(_cookieManager);
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

  /// Reemplaza el jar en memoria por uno persistente en disco para que la
  /// cookie de sesión de PHP sobreviva al cierre y reapertura de la app. Sin
  /// esto, al reabrir se pierde la sesión, las peticiones devuelven 401 y el
  /// interceptor terminaba borrando los datos guardados (sucursal, miembro…).
  /// Debe llamarse una vez desde main() antes de runApp().
  Future<void> init() async {
    // Apuntar la app a la empresa activa del catálogo antes de cualquier
    // petición. Si aún no hay empresa elegida se mantiene RUTA_GLOBAL como
    // fallback; la pantalla de selección aplicará la ruta al escogerla.
    try {
      final empresa = await EmpresaDao.instancia.activa();
      if (empresa != null) {
        aplicarRuta(empresa.rutaGlobal);
      }
    } catch (_) {
      // Si la BD falla seguimos con la ruta de arranque (fallback).
    }

    if (_cookiesPersistentes) return;
    try {
      final dir = await getApplicationDocumentsDirectory();
      final jar = PersistCookieJar(
        ignoreExpires: true,
        storage: FileStorage('${dir.path}/.cookies/'),
      );
      final persistente = CookieManager(jar);
      final indice = _dio.interceptors.indexOf(_cookieManager);
      if (indice >= 0) {
        _dio.interceptors[indice] = persistente;
      } else {
        _dio.interceptors.insert(0, persistente);
      }
      _cookieManager = persistente;
      _cookiesPersistentes = true;
    } catch (_) {
      // Si falla el acceso a disco seguimos con el jar en memoria; la app
      // funciona, solo pierde la persistencia de la sesión entre reinicios.
    }
  }

  /// Cambia en caliente la URL base de la API (p. ej. al elegir empresa en la
  /// pantalla de selección). Dio la usa desde la siguiente petición.
  void aplicarRuta(String ruta) {
    _dio.options.baseUrl = ruta;
  }

  /// Ruta base actual de la API.
  String get rutaActual => _dio.options.baseUrl;

  /// Mensaje mostrado al usuario cuando el dispositivo no tiene conexión.
  static const String _mensajeSinConexion =
      'Sin conexión a internet. Verifica tu red e inténtalo de nuevo.';

  /// Comprueba si el dispositivo tiene alguna interfaz de red activa
  /// (WiFi, datos móviles, ethernet o VPN).
  Future<bool> hayInternet() async {
    try {
      final resultados = await Connectivity().checkConnectivity();
      return resultados.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      // Ante cualquier fallo del plugin asumimos que sí hay red para no
      // bloquear la petición; Dio reportará el error real si no la hay.
      return true;
    }
  }

  /// Respuesta estándar de "sin conexión". Muestra el snack amarillo global y
  /// devuelve un mapa compatible con lo que esperan los repositorios.
  Map<String, dynamic> _respuestaSinConexion() {
    mostrarMensajeGlobal(_mensajeSinConexion, tipo: TipoMensaje.advertencia);
    return {'success': false, 'sin_conexion': true, 'error': _mensajeSinConexion};
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
    if (!await hayInternet()) return _respuestaSinConexion();
    try {
      final response = await _dio.post(ruta, data: datos);
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> obtenerConDatos(Map<String, dynamic> datos, String ruta) async {
    if (!await hayInternet()) return _respuestaSinConexion();
    try {
      final response = await _dio.post(ruta, data: datos);
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> eliminar(String ruta, Map<String, dynamic> datos) async {
    if (!await hayInternet()) return _respuestaSinConexion();
    try {
      final response = await _dio.post(ruta, data: datos);
      return response.data;
    } on DioException catch (e) {
      return _handleError(e);
    }
  }

  Future<dynamic> subirArchivo(FormData formData, String url) async {
    if (!await hayInternet()) return _respuestaSinConexion();
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
    if (!await hayInternet()) {
      _respuestaSinConexion();
      return;
    }
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
    // Sin respuesta del servidor: timeout, conexión rechazada o red caída
    // aunque el dispositivo reporte tener interfaz activa.
    const erroresConexion = {
      DioExceptionType.connectionError,
      DioExceptionType.connectionTimeout,
      DioExceptionType.receiveTimeout,
      DioExceptionType.sendTimeout,
    };
    if (erroresConexion.contains(e.type)) {
      return _respuestaSinConexion();
    }
    return {'success': false, 'error': e.message};
  }
}
