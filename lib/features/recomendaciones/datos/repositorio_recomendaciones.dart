import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/recomendaciones/dominio/entidades/recomendacion.dart';

/// Acceso al buzón de recomendaciones (`recomendaciones.php`).
///
/// Enviar está abierto a cualquier perfil logueado; leer la bandeja es solo
/// para el personal — el backend rechaza con 403 al cliente que lo intente,
/// así que aquí no hace falta filtrar nada.
class RepositorioRecomendaciones {
  static const _ruta = 'recomendaciones.php';

  final HttpService _http;

  RepositorioRecomendaciones([HttpService? http]) : _http = http ?? HttpService();

  /// Envía una recomendación. Devuelve el mensaje del backend para poder
  /// mostrar el motivo exacto cuando falla.
  Future<({bool exito, String mensaje})> enviar({
    required DestinoRecomendacion destino,
    required String mensaje,
    required bool anonimo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    final resp = await _http.registrar(
      {
        'metodo': 'registrar',
        'recomendacion': {
          'destino': destino.valor,
          'mensaje': mensaje,
          'anonimo': anonimo ? 1 : 0,
          // El autor lo pone el servidor con la sesión; la sede solo se manda
          // como respaldo por si la sesión no la trae.
          'sucursal_id': sucursalId,
        },
      },
      _ruta,
    );

    return _resultado(resp, mensajeError: 'No se pudo enviar tu recomendación');
  }

  /// ¿El usuario en sesión puede dejar una recomendación? El socio necesita
  /// la membresía vigente; el personal siempre puede. Lo decide el servidor.
  ///
  /// Ante un fallo de red se responde que SÍ puede: es preferible que escriba
  /// y el envío le diga el motivo real, a bloquearle el formulario por una
  /// caída pasajera.
  Future<({bool puede, String motivo})> puedeEnviar() async {
    final resp = await _http.obtenerConDatos({'metodo': 'puede_enviar'}, _ruta);

    if (resp is Map && resp['puede'] != null) {
      final puede = resp['puede'] == true || '${resp['puede']}' == '1';
      return (puede: puede, motivo: '${resp['motivo'] ?? ''}');
    }
    return (puede: true, motivo: '');
  }

  /// Bandeja de la sede. [destino] null trae las de gimnasio y app.
  ///
  /// Lanza si el servidor responde con error (p. ej. 403 al cliente): una
  /// lista vacía se vería en pantalla como "no hay recomendaciones" y
  /// escondería el motivo real.
  Future<List<Recomendacion>> listar({
    DestinoRecomendacion? destino,
    bool soloPendientes = false,
  }) async {
    final resp = await _http.obtenerConDatos(
      {
        'metodo': 'listar',
        'destino': destino?.valor ?? 0,
        'solo_pendientes': soloPendientes ? 1 : 0,
      },
      _ruta,
    );

    // Sin conexión el HttpService ya avisó con su propio toast: devolver
    // vacío evita mostrar dos mensajes seguidos por lo mismo.
    if (resp is Map && resp['sin_conexion'] != true && resp['error'] != null) {
      throw Exception('${resp['error']}');
    }
    if (resp is! List) return [];

    return resp
        .whereType<Map>()
        .map((raw) => Recomendacion.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  /// Recomendaciones sin leer de la sede. Alimenta el contador de la bandeja.
  Future<int> pendientes() async {
    final resp = await _http.obtenerConDatos({'metodo': 'resumen'}, _ruta);
    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      return int.tryParse('${resp.first['pendientes'] ?? 0}') ?? 0;
    }
    return 0;
  }

  Future<bool> marcarLeido(int id, {bool leido = true}) async {
    final resp = await _http.registrar(
      {'metodo': 'marcar_leido', 'id': id, 'leido': leido ? 1 : 0},
      _ruta,
    );
    return _resultado(resp, mensajeError: 'No se pudo actualizar').exito;
  }

  Future<bool> eliminar(int id) async {
    final resp = await _http.eliminar(_ruta, {'metodo': 'eliminar', 'id': id});
    return _resultado(resp, mensajeError: 'No se pudo eliminar').exito;
  }

  /// Los SP de escritura responden `voit_exito` / `voit_message`; un 401/403
  /// llega como mapa con la clave 'error'.
  ({bool exito, String mensaje}) _resultado(
    dynamic resp, {
    required String mensajeError,
  }) {
    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      final fila = resp.first as Map;
      final exito = '${fila['voit_exito'] ?? 0}' == '1';
      final mensaje = '${fila['voit_message'] ?? ''}';
      return (exito: exito, mensaje: mensaje.isEmpty ? mensajeError : mensaje);
    }
    if (resp is Map && resp['error'] != null) {
      return (exito: false, mensaje: '${resp['error']}');
    }
    return (exito: false, mensaje: mensajeError);
  }
}
