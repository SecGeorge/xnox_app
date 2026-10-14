import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';

/// Clases del gimnasio para el socio (`clases.php`). El backend toma al socio
/// de la sesión, así que aquí nunca se envía el miembro.
class RepositorioClases {
  RepositorioClases([HttpService? http]) : _http = http ?? HttpService();

  final HttpService _http;

  /// Días que el socio puede ver y reservar por adelantado (igual que el
  /// backend, `ClasesDominio::DIAS_ANTICIPACION`).
  static const diasAnticipacion = 14;

  static final _formato = DateFormat('yyyy-MM-dd');

  Future<List<SesionClase>> agenda({
    DateTime? desde,
    int dias = diasAnticipacion,
  }) async {
    final inicio = desde ?? DateTime.now();
    final prefs = await SharedPreferences.getInstance();
    final resp = await _http.obtenerConDatos({
      'metodo': 'agenda_socio',
      'desde': _formato.format(inicio),
      'hasta': _formato.format(inicio.add(Duration(days: dias))),
      'sucursal_id': prefs.getString('idSucursal'),
    }, 'clases.php');
    final sesiones = resp is Map ? resp['sesiones'] : null;
    if (sesiones is! List) {
      throw Exception(
        resp is Map
            ? (resp['error'] ?? 'Respuesta inesperada')
            : 'Sin respuesta',
      );
    }
    return sesiones
        .whereType<Map>()
        .map((s) => SesionClase.fromJson(Map<String, dynamic>.from(s)))
        .toList();
  }

  Future<ResultadoClase> reservar(SesionClase s) => _accion({
    'metodo': 'reservar',
    'horario_id': s.horarioId,
    'fecha': _formato.format(s.fecha),
  }, 'No se pudo reservar');

  Future<ResultadoClase> cancelar(SesionClase s) => _accion({
    'metodo': 'cancelar',
    'reserva_id': s.reservaId,
  }, 'No se pudo cancelar');

  Future<ResultadoClase> _accion(
    Map<String, dynamic> datos,
    String porDefecto,
  ) async {
    final resp = await _http.registrar(datos, 'clases.php');
    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      final fila = resp.first as Map;
      final exito = fila['voit_exito'].toString() == '1';
      return ResultadoClase(
        exito,
        (fila['voit_message'] ?? porDefecto).toString(),
      );
    }
    final mensaje = resp is Map ? (resp['error'] ?? porDefecto) : porDefecto;
    return ResultadoClase(false, mensaje.toString());
  }
}
