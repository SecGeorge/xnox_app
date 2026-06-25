import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/repositorios/repositorio_publicidad.dart';

class RepositorioPublicidadImpl implements RepositorioPublicidad {
  final HttpService _httpService;

  RepositorioPublicidadImpl(this._httpService);

  @override
  Future<List<Publicidad>> obtenerPublicidades() async {
    try {
      final payload = {'metodo': 'listar'};
      final response = await _httpService.obtenerConDatos(payload, 'publicidad.php');
      
      if (response != null && response['resultado'] == true) {
        final List data = response['datos'];
        return data.map((e) => Publicidad.fromJson(e)).toList();
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  @override
  Future<bool> crearPublicidad(Publicidad publicidad, Map<String, dynamic> imagen) async {
    try {
      final payload = {
        'metodo': 'crear',
        'datos': publicidad.toJson(),
        'imagen': imagen,
      };
      final response = await _httpService.obtenerConDatos(payload, 'publicidad.php');
      return response != null && response['resultado'] == true;
    } catch (e) {
      return false;
    }
  }
}
