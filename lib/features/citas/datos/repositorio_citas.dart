import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/citas/dominio/cita.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';

/// Citas con masajista, nutricionista… (`citas.php`). Como en Clases, el
/// backend toma al socio de la sesión: aquí nunca se envía el miembro.
class RepositorioCitas {
  RepositorioCitas([HttpService? http]) : _http = http ?? HttpService();

  final HttpService _http;

  /// Igual que `CitasDominio::DIAS_ANTICIPACION`.
  static const diasAnticipacion = 30;

  static final _formato = DateFormat('yyyy-MM-dd');

  Future<String?> _sucursal() async =>
      (await SharedPreferences.getInstance()).getString('idSucursal');

  Future<CatalogoCitas> catalogo() async {
    final resp = await _http.obtenerConDatos({
      'metodo': 'catalogo_socio',
      'sucursal_id': await _sucursal(),
    }, 'citas.php');
    if (resp is! Map || resp['tipos'] is! List) {
      throw Exception(
        resp is Map
            ? (resp['error'] ?? 'Respuesta inesperada')
            : 'Sin respuesta',
      );
    }
    List<T> lista<T>(dynamic v, T Function(Map<String, dynamic>) de) =>
        (v is List ? v : const [])
            .whereType<Map>()
            .map((m) => de(Map<String, dynamic>.from(m)))
            .toList();
    return CatalogoCitas(
      lista(resp['tipos'], TipoCita.fromJson),
      lista(resp['citas'], CitaSocio.fromJson),
    );
  }

  /// Turnos libres de un tipo de cita desde [desde] (por defecto, hoy).
  Future<List<TurnoCita>> turnos(TipoCita tipo, {DateTime? desde}) async {
    final inicio = desde ?? DateTime.now();
    final resp = await _http.obtenerConDatos({
      'metodo': 'turnos_socio',
      'tipo_id': tipo.id,
      'desde': _formato.format(inicio),
      'hasta': _formato.format(
        inicio.add(const Duration(days: diasAnticipacion)),
      ),
      'sucursal_id': await _sucursal(),
    }, 'citas.php');
    final dias = resp is Map ? resp['dias'] : null;
    if (dias is! List) {
      throw Exception(
        resp is Map
            ? (resp['error'] ?? 'Respuesta inesperada')
            : 'Sin respuesta',
      );
    }
    final turnos = <TurnoCita>[];
    for (final d in dias.whereType<Map>()) {
      final fecha = DateTime.tryParse((d['fecha'] ?? '').toString());
      if (fecha == null || d['turnos'] is! List) continue;
      for (final t in (d['turnos'] as List).whereType<Map>()) {
        turnos.add(
          TurnoCita(
            fecha: fecha,
            profesionalId: int.tryParse(t['profesional_id'].toString()) ?? 0,
            profesional: (t['profesional'] ?? '').toString(),
            horaInicio: (t['hora_inicio'] ?? '').toString(),
            horaFin: (t['hora_fin'] ?? '').toString(),
          ),
        );
      }
    }
    return turnos;
  }

  Future<ResultadoClase> reservar(
    TipoCita tipo,
    TurnoCita turno,
    String nota,
  ) => _accion({
    'metodo': 'reservar_cita',
    'tipo_id': tipo.id,
    'profesional_id': turno.profesionalId,
    'fecha': _formato.format(turno.fecha),
    'hora_inicio': turno.horaInicio,
    'nota': nota,
  }, 'No se pudo reservar');

  Future<ResultadoClase> cancelar(CitaSocio cita) => _accion({
    'metodo': 'cancelar_cita',
    'cita_id': cita.id,
  }, 'No se pudo cancelar');

  Future<ResultadoClase> _accion(
    Map<String, dynamic> datos,
    String porDefecto,
  ) async {
    final resp = await _http.registrar(datos, 'citas.php');
    if (resp is List && resp.isNotEmpty && resp.first is Map) {
      final fila = resp.first as Map;
      return ResultadoClase(
        fila['voit_exito'].toString() == '1',
        (fila['voit_message'] ?? porDefecto).toString(),
      );
    }
    final mensaje = resp is Map ? (resp['error'] ?? porDefecto) : porDefecto;
    return ResultadoClase(false, mensaje.toString());
  }
}
