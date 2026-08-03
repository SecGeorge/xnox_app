import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

/// Acceso remoto (rutinas.php) a la gestión de rutinas del personal. A
/// diferencia del repositorio del cliente, no toca SQLite: opera directo sobre
/// el backend para VER/CREAR/EDITAR/ASIGNAR rutinas de cualquier miembro.
class RepositorioRutinasAdmin {
  final HttpService _http;

  RepositorioRutinasAdmin([HttpService? http]) : _http = http ?? HttpService();

  Future<int> _sucursalId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
  }

  /// Rutinas personalizadas de un miembro (metadata).
  Future<List<RutinaResumen>> listarDeMiembro(int miembroId) async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'listar_miembro', 'miembro_id': miembroId},
      'rutinas.php',
    );
    return _listaResumen(resp);
  }

  /// Plantillas generales de la sucursal, para asignarlas a un miembro.
  Future<List<RutinaResumen>> listarPlantillas() async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'listar_plantillas', 'sucursal_id': await _sucursalId()},
      'rutinas.php',
    );
    return _listaResumen(resp);
  }

  /// Árbol completo de una rutina (para ver/editar). Las imágenes se vuelven
  /// URLs absolutas.
  Future<RutinaAdmin?> obtener(int id) async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'obtener', 'id': id},
      'rutinas.php',
    );
    if (resp is Map && resp['resultado'] == true && resp['datos'] is Map) {
      final r = RutinaAdmin.fromJson(Map<String, dynamic>.from(resp['datos']));
      for (final d in r.dias) {
        for (final e in d.ejercicios) {
          e.imagenUrl = _urlImagen(e.imagenUrl);
        }
      }
      return r;
    }
    return null;
  }

  /// Crea (sin id) o edita (con id) una rutina completa. Devuelve `null` si todo
  /// salió bien, o un mensaje de error legible.
  Future<String?> guardar(RutinaAdmin rutina) async {
    final resp = await _http.obtenerConDatos(
      {
        'metodo': 'guardar',
        'sucursal_id': await _sucursalId(),
        'rutina': rutina.toJson(),
      },
      'rutinas.php',
    );
    return _resultado(resp, 'No se pudo guardar la rutina');
  }

  /// Copia una plantilla como rutina personalizada del miembro.
  Future<String?> asignarPlantilla(int rutinaId, int miembroId) async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'asignar', 'rutina_id': rutinaId, 'miembro_id': miembroId},
      'rutinas.php',
    );
    return _resultado(resp, 'No se pudo asignar la rutina');
  }

  Future<String?> anular(int id) => _estado('anular', id);
  Future<String?> activar(int id) => _estado('activar', id);
  Future<String?> eliminar(int id) => _estado('eliminar', id);

  Future<String?> _estado(String metodo, int id) async {
    final resp = await _http.obtenerConDatos(
      {'metodo': metodo, 'id': id},
      'rutinas.php',
    );
    return _resultado(resp, 'No se pudo actualizar la rutina');
  }

  // --------------------------------------------------------------- helpers
  List<RutinaResumen> _listaResumen(dynamic resp) {
    if (resp is Map && resp['resultado'] == true && resp['datos'] is List) {
      return (resp['datos'] as List)
          .whereType<Map>()
          .map((e) => RutinaResumen.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  /// Devuelve null si `resultado==true`; si no, el mensaje de error del backend
  /// o [porDefecto].
  String? _resultado(dynamic resp, String porDefecto) {
    if (resp is Map && resp['resultado'] == true) return null;
    if (resp is Map && resp['error'] != null) return resp['error'].toString();
    return porDefecto;
  }

  String? _urlImagen(String? ruta) {
    final r = ruta?.trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    final limpia = r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '');
    return '${_http.rutaActual}$limpia';
  }
}
