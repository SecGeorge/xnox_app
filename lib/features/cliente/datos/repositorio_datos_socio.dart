import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/datos_socio.dart';

/// Datos del socio (`miembros.php`). El backend toma al socio de la sesión:
/// aquí nunca se envía el miembro.
class RepositorioDatosSocio {
  RepositorioDatosSocio([HttpService? http]) : _http = http ?? HttpService();

  final HttpService _http;

  Future<DatosSocio> obtener() async {
    final r = await _http.obtenerConDatos({
      'metodo': 'mis_datos',
    }, 'miembros.php');
    if (r is! Map || !r.containsKey('fecha_nacimiento')) {
      throw Exception(r is Map ? (r['error'] ?? 'Sin datos') : 'Sin respuesta');
    }
    return DatosSocio.fromJson(Map<String, dynamic>.from(r));
  }

  /// Devuelve el mensaje de error, o null si se guardó.
  Future<String?> guardar(DatosSocio datos) async {
    const fallo = 'No se pudieron guardar tus datos';
    final r = await _http.registrar({
      'metodo': 'guardar_mis_datos',
      ...datos.toJson(),
    }, 'miembros.php');
    if (r is Map && r['voit_exito'].toString() == '1') return null;
    return r is Map
        ? (r['voit_message'] ?? r['error'] ?? fallo).toString()
        : fallo;
  }
}
