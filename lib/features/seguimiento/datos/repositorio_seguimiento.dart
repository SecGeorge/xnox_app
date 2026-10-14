import 'dart:convert';

import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/seguimiento/dominio/seguimiento.dart';

/// Habla con `seguimiento.php` (solo personal): entrenamiento y medidas que
/// el socio registra en su app. Sin caché: el personal siempre ve lo último.
class RepositorioSeguimiento {
  static const _ruta = 'seguimiento.php';
  final _http = HttpService();

  Future<SeguimientoSocio> detalle(int miembroId) async {
    var resp = await _http.obtenerConDatos({
      'metodo': 'detalle',
      'miembro_id': miembroId,
    }, _ruta);
    if (resp is String) {
      try {
        resp = jsonDecode(resp);
      } catch (_) {}
    }
    if (resp is! Map || resp['resultado'] != true) {
      throw Exception(
        resp is Map && resp['error'] != null
            ? '${resp['error']}'
            : 'No se pudo cargar el progreso del socio',
      );
    }
    return SeguimientoSocio.desdeJson(Map<String, dynamic>.from(resp));
  }
}
