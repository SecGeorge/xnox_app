import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/publicidad/datos/repositorios/repositorio_publicidad_impl.dart';
import 'package:xnox_app/features/publicidad/dominio/casos_de_uso/crear_publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/casos_de_uso/obtener_publicidades.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/repositorios/repositorio_publicidad.dart';

class ControladorPublicidad {
  final RepositorioPublicidad _repositorio;
  final ObtenerPublicidades _obtenerPublicidades;
  final CrearPublicidad _crearPublicidad;

  ControladorPublicidad._(this._repositorio)
      : _obtenerPublicidades = ObtenerPublicidades(_repositorio),
        _crearPublicidad = CrearPublicidad(_repositorio);

  factory ControladorPublicidad() =>
      ControladorPublicidad._(RepositorioPublicidadImpl(HttpService()));

  /// Panel admin: todas las campañas (menos eliminadas).
  Future<List<Publicidad>> fetchPublicidades() async {
    return await _obtenerPublicidades.ejecutar();
  }

  /// Cliente: solo campañas activas y vigentes.
  Future<List<Publicidad>> fetchPublicidadesActivas() async {
    return await _repositorio.obtenerPublicidadesActivas();
  }

  Future<bool> addPublicidad(Publicidad publicidad, Map<String, dynamic> imagen) async {
    return await _crearPublicidad.ejecutar(publicidad, imagen);
  }
}
