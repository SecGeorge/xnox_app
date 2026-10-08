import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';

/// Resultado de marcar una entrada (`sp_asistencia_registrar`).
/// [exito]: 1 ingresó, 2 ingresó con aviso, 0 denegado.
class ResultadoAsistencia {
  final int exito;
  final String mensaje;
  final String nombre;
  final String codigo;
  final String imagen;
  final String membresia;
  final DateTime? fechaFin;

  /// Días que le quedan (negativo = hace cuántos venció).
  final int? diasRestantes;
  final int? visitasRestantes;
  final double deuda;
  final DateTime hora;

  ResultadoAsistencia({
    required this.exito,
    required this.mensaje,
    this.nombre = '',
    this.codigo = '',
    this.imagen = '',
    this.membresia = '',
    this.fechaFin,
    this.diasRestantes,
    this.visitasRestantes,
    this.deuda = 0,
    DateTime? hora,
  }) : hora = hora ?? DateTime.now();

  bool get ingreso => exito == 1 || exito == 2;

  factory ResultadoAsistencia.fromJson(Map<String, dynamic> j) {
    int? entero(dynamic v) => v == null ? null : int.tryParse(v.toString());
    return ResultadoAsistencia(
      exito: entero(j['voit_exito']) ?? 0,
      mensaje: j['voit_message']?.toString() ?? 'No se pudo registrar',
      nombre: (j['voit_nombre']?.toString() ?? '').trim(),
      codigo: j['voit_codigo']?.toString() ?? '',
      imagen: j['voit_imagen']?.toString() ?? '',
      membresia: j['voit_membresia']?.toString() ?? '',
      fechaFin: DateTime.tryParse(j['voit_fecha_fin']?.toString() ?? ''),
      diasRestantes: entero(j['voit_dias_restantes']),
      visitasRestantes: entero(j['voit_visitas_restantes']),
      deuda: double.tryParse(j['voit_deuda']?.toString() ?? '') ?? 0,
    );
  }
}

/// Una entrada del día (`sp_asistencia_obtener`).
class EntradaAsistencia {
  final String nombre;
  final String codigo;
  final String hora; // "HH:MM:SS"
  final String tipo;

  const EntradaAsistencia({
    required this.nombre,
    required this.codigo,
    required this.hora,
    required this.tipo,
  });

  int? get horaDelDia => int.tryParse(hora.split(':').first);

  factory EntradaAsistencia.fromJson(Map<String, dynamic> j) =>
      EntradaAsistencia(
        nombre: (j['nombre_completo']?.toString() ?? '')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim(),
        codigo: j['codigo']?.toString() ?? '',
        hora: j['hora']?.toString() ?? '',
        tipo: j['tipo']?.toString() ?? '',
      );
}

class AsistenciasDia {
  final List<EntradaAsistencia> entradas;
  final int miembrosActivos;

  const AsistenciasDia(this.entradas, this.miembrosActivos);
}

/// Horario de atención de un día (Ajustes del panel web). `diaSemana`: 1 lunes
/// ... 7 domingo, igual que [DateTime.weekday].
class HorarioDia {
  final int diaSemana;
  final bool abierto;
  final String apertura; // "HH:MM"
  final String cierre;

  const HorarioDia(this.diaSemana, this.abierto, this.apertura, this.cierre);

  String get texto => !abierto
      ? 'Cerrado'
      : (apertura.isEmpty || cierre.isEmpty)
      ? '—'
      : '$apertura – $cierre';

  static int? _minutos(String hhmm) {
    final p = hhmm.split(':');
    final h = int.tryParse(p.first);
    final m = int.tryParse(p.length > 1 ? p[1] : '0');
    return (h == null || m == null) ? null : h * 60 + m;
  }

  int? get horaApertura =>
      _minutos(apertura) == null ? null : _minutos(apertura)! ~/ 60;
  int? get horaCierre =>
      _minutos(cierre) == null ? null : _minutos(cierre)! ~/ 60;

  /// Igual que el panel web: si el cierre es antes de la apertura, el horario
  /// cruza la medianoche.
  bool abiertoA(DateTime t) {
    if (!abierto) return false;
    final a = _minutos(apertura), c = _minutos(cierre);
    if (a == null || c == null) return false;
    final ahora = t.hour * 60 + t.minute;
    if (c <= a) return ahora >= a || ahora < c;
    return ahora >= a && ahora < c;
  }
}

/// Registro de asistencia del admin: mismos endpoints que el registro rápido
/// del panel web (`Asistencia.vue`).
class RepositorioAsistencia {
  final _http = HttpService();

  Future<(int sucursal, String usuario)> _sesion() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0,
      prefs.getString('idUsuario') ?? '',
    );
  }

  Future<ResultadoAsistencia> registrar(String codigoMiembro) async {
    final (sucursal, usuario) = await _sesion();
    final r = await _http.obtenerConDatos({
      'metodo': 'registrar',
      'asistencia': {
        'codigoMiembro': codigoMiembro,
        'usuario_creacion': usuario,
        'sucursal_id': sucursal,
      },
    }, 'asistencia.php');
    if (r is List && r.isNotEmpty && r.first is Map) {
      return ResultadoAsistencia.fromJson(Map<String, dynamic>.from(r.first));
    }
    final error = r is Map && r['error'] != null
        ? r['error'].toString()
        : 'No se pudo procesar la respuesta del servidor';
    return ResultadoAsistencia(exito: 0, mensaje: error);
  }

  Future<AsistenciasDia> obtener(DateTime fecha) async {
    final (sucursal, _) = await _sesion();
    final f =
        '${fecha.year.toString().padLeft(4, '0')}-'
        '${fecha.month.toString().padLeft(2, '0')}-'
        '${fecha.day.toString().padLeft(2, '0')}';
    final r = await _http.obtenerConDatos({
      'metodo': 'obtener',
      'sucursal_id': sucursal,
      'filtros': {'fecha': f},
    }, 'asistencia.php');
    if (r is! Map || r['asistencias'] is! List) {
      throw Exception('No se pudo cargar la asistencia');
    }
    final entradas =
        (r['asistencias'] as List)
            .whereType<Map>()
            .map(
              (e) => EntradaAsistencia.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList()
          ..sort((a, b) => b.hora.compareTo(a.hora));
    final activos = r['cantidad_miembros_activos'];
    final cantidad =
        activos is List && activos.isNotEmpty && activos.first is Map
        ? int.tryParse(activos.first['cantidad']?.toString() ?? '') ?? 0
        : 0;
    return AsistenciasDia(entradas, cantidad);
  }

  Future<List<HorarioDia>> horario() async {
    final (sucursal, _) = await _sesion();
    final r = await _http.obtenerConDatos({
      'metodo': 'horario_obtener',
      'sucursal_id': sucursal,
    }, 'ajustes.php');
    final datos = r is Map ? r['datos'] : null;
    if (datos is! List) return const [];
    String hhmm(dynamic v) {
      final t = v?.toString() ?? '';
      return t.length >= 5 ? t.substring(0, 5) : t;
    }

    return datos
        .whereType<Map>()
        .map(
          (h) => HorarioDia(
            int.tryParse(h['dia_semana']?.toString() ?? '') ?? 0,
            h['cerrado']?.toString() != '1',
            hhmm(h['hora_apertura']),
            hhmm(h['hora_cierre']),
          ),
        )
        .toList();
  }
}
