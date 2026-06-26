import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/repositorios/repositorio_publicidad.dart';

class RepositorioPublicidadImpl implements RepositorioPublicidad {
  final HttpService _httpService;

  RepositorioPublicidadImpl(this._httpService);

  Future<int> _sucursalId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
  }

  /// Construye la URL absoluta de la imagen a partir de la ruta relativa
  /// que guarda el backend (ej. "./imagenes/publicidad/x.png").
  String? _urlImagen(dynamic ruta) {
    final r = ruta?.toString().trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    final limpia = r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '');
    return '${HttpService.RUTA_GLOBAL}$limpia';
  }

  Publicidad _aPublicidad(Map<String, dynamic> j) {
    return Publicidad(
      id: j['id'] != null ? int.tryParse(j['id'].toString()) : null,
      titulo: j['titulo']?.toString() ?? '',
      descripcion: j['descripcion']?.toString() ?? '',
      fechaInicio:
          DateTime.tryParse(j['fecha_inicio']?.toString() ?? '') ?? DateTime.now(),
      fechaFin:
          DateTime.tryParse(j['fecha_fin']?.toString() ?? '') ?? DateTime.now(),
      imagenUrl: _urlImagen(j['imagen'] ?? j['imagen_url']),
    );
  }

  List<Publicidad> _mapear(dynamic response) {
    if (response is Map && response['resultado'] == true) {
      final data = response['datos'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => _aPublicidad(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return [];
  }

  @override
  Future<List<Publicidad>> obtenerPublicidades() async {
    try {
      final response = await _httpService.obtenerConDatos(
        {'metodo': 'listar', 'sucursal_id': await _sucursalId()},
        'publicidad.php',
      );
      return _mapear(response);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<List<Publicidad>> obtenerPublicidadesActivas() async {
    try {
      final response = await _httpService.obtenerConDatos(
        {'metodo': 'listar_activas', 'sucursal_id': await _sucursalId()},
        'publicidad.php',
      );
      return _mapear(response);
    } catch (_) {
      return [];
    }
  }

  @override
  Future<bool> crearPublicidad(
      Publicidad publicidad, Map<String, dynamic> imagen) async {
    try {
      final payload = {
        'metodo': 'crear',
        'datos': publicidad.toJson(),
        'imagen': imagen,
        'sucursal_id': await _sucursalId(),
      };
      final response =
          await _httpService.obtenerConDatos(payload, 'publicidad.php');
      return response is Map && response['resultado'] == true;
    } catch (e) {
      return false;
    }
  }
}
