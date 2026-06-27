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
}
