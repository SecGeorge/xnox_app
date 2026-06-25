import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/publicidad/datos/repositorios/repositorio_publicidad_impl.dart';
import 'package:xnox_app/features/publicidad/dominio/casos_de_uso/crear_publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/casos_de_uso/obtener_publicidades.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';

class ControladorPublicidad {
  final ObtenerPublicidades _obtenerPublicidades;
  final CrearPublicidad _crearPublicidad;

  ControladorPublicidad()
      : _obtenerPublicidades = ObtenerPublicidades(RepositorioPublicidadImpl(HttpService())),
        _crearPublicidad = CrearPublicidad(RepositorioPublicidadImpl(HttpService()));

  Future<List<Publicidad>> fetchPublicidades() async {
    return await _obtenerPublicidades.ejecutar();
  }

  Future<bool> addPublicidad(Publicidad publicidad, Map<String, dynamic> imagen) async {
    return await _crearPublicidad.ejecutar(publicidad, imagen);
  }
}
