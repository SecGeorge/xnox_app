import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/notificaciones/dominio/entidades/notificacion.dart';
import 'package:xnox_app/features/notificaciones/dominio/repositorios/repositorio_notificaciones.dart';

class RepositorioNotificacionesImpl implements RepositorioNotificaciones {
  final HttpService _httpService;

  RepositorioNotificacionesImpl(this._httpService);

  @override
  Future<List<Notificacion>> obtener() async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
    final usuarioId = int.tryParse(prefs.getString('idUsuario') ?? '') ?? 0;

    final resp = await _httpService.obtenerConDatos(
      {
        'metodo': 'get',
        'notificacion': {
          'idUsuario': usuarioId,
          'sucursal_id': sucursalId,
          // El servidor decide el público con la sesión; esto solo se usa
          // como respaldo si la sesión caducó. Ver NotificacionAplicacion.
          'tipo_usuario': prefs.getString('tipoUsuario') ?? '',
          'miembro_id': prefs.getString('miembroId') ?? '',
        },
      },
      'notificaciones.php',
    );

    if (resp is! List) return [];

    return resp
        .whereType<Map>()
        .map((raw) => Notificacion.fromJson(Map<String, dynamic>.from(raw)))
        .toList();
  }

  @override
  Future<void> marcarLeido(int id) async {
    await _httpService.obtenerConDatos(
      {'metodo': 'marcar_leido', 'id': id},
      'notificaciones.php',
    );
  }

  @override
  Future<bool> crear({
    required String titulo,
    required String mensaje,
    required int tipoEnvio,
    String tipo = 'info',
    int? miembroId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    final resp = await _httpService.registrar(
      {
        'metodo': 'registrar',
        'notificacion': {
          'titulo': titulo,
          // El backend espera 'mensage' (con la errata original de la API).
          'mensage': mensaje,
          'tipo': tipo,
          'tipo_envio': tipoEnvio,
          'miembro_id': miembroId,
          'sucursal_id': sucursalId,
        },
      },
      'notificaciones.php',
    );

    // El SP responde con voit_exito; un 401/403 llega como mapa con 'error'.
    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      return (resp.first['voit_exito']?.toString() ?? '0') == '1';
    }
    return false;
  }
}
