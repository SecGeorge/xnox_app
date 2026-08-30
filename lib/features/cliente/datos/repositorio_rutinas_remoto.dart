import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';

/// Obtiene del backend las rutinas sugeridas (creadas por el administrador en
/// el sistema web) para sincronizarlas a SQLite.
///
/// Devuelve [Rutina] con [OrigenRutina.admin]; el `servidorId` identifica la
/// rutina en el backend y los ids locales de días/ejercicios quedan en 0
/// (se asignan al persistir en SQLite).
class RepositorioRutinasRemoto {
  final HttpService _http;

  RepositorioRutinasRemoto([HttpService? http]) : _http = http ?? HttpService();

  Future<int> _sucursalId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
  }

  Future<int> _miembroId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;
  }

  /// Devuelve las rutinas activas del backend: las generales de la sucursal más
  /// las que el administrador armó para este cliente. Lista vacía si no hay
  /// conexión o el backend no responde (la app sigue funcionando con SQLite).
  Future<List<Rutina>> obtenerSugeridas() async {
    try {
      final response = await _http.obtenerConDatos(
        {
          'metodo': 'listar_sugeridas',
          'sucursal_id': await _sucursalId(),
          'miembro_id': await _miembroId(),
        },
        'rutinas.php',
      );
      return _mapear(response);
    } catch (_) {
      return [];
    }
  }

  List<Rutina> _mapear(dynamic response) {
    if (response is Map && response['resultado'] == true) {
      final data = response['datos'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => _aRutina(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return [];
  }

  Rutina _aRutina(Map<String, dynamic> j) {
    final diasJson = (j['dias'] is List) ? j['dias'] as List : const [];
    final dias = diasJson.whereType<Map>().map((d) {
      final dm = Map<String, dynamic>.from(d);
      final ejsJson = (dm['ejercicios'] is List) ? dm['ejercicios'] as List : const [];
      final ejercicios = ejsJson.whereType<Map>().map((e) {
        final em = Map<String, dynamic>.from(e);
        final catalogoId = _entero(em['ejercicio_catalogo_id']);
        return Ejercicio(
          id: 0,
          nombre: em['nombre']?.toString() ?? '',
          series: _entero(em['series']),
          repeticiones: _entero(em['repeticiones']),
          observaciones: _textoNullable(em['observaciones']),
          catalogoId: catalogoId == 0 ? null : catalogoId,
          imagenUrl: _urlImagen(em['imagen']),
          videoUrl: _urlImagen(em['video']),
        );
      }).toList();
      return DiaRutina(
        id: 0,
        diaSemana: dm['dia_semana']?.toString() ?? '',
        ejercicios: ejercicios,
      );
    }).toList();

    return Rutina(
      id: 0,
      servidorId: _entero(j['id']),
      nombre: j['nombre']?.toString() ?? '',
      descripcion: j['descripcion']?.toString() ?? '',
      origen: OrigenRutina.admin,
      // Con miembro_id la rutina es solo para este cliente.
      personalizada: _entero(j['miembro_id']) > 0,
      dias: dias,
    );
  }

  /// URL absoluta de la imagen del catálogo a partir de la ruta relativa del
  /// backend. Usa `rutaActual` porque cada empresa vive en su propio servidor.
  String? _urlImagen(dynamic ruta) {
    final r = ruta?.toString().trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    final limpia = r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '');
    return '${_http.rutaActual}$limpia';
  }

  int _entero(dynamic v) =>
      v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

  String? _textoNullable(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
