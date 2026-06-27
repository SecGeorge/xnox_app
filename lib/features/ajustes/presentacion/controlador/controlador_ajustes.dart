import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/ajustes/datos/repositorios/repositorio_ajustes_impl.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/datos_negocio.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/perfil_usuario.dart';

class ControladorAjustes {
  final RepositorioAjustesImpl _repositorio;

  ControladorAjustes()
      : _repositorio = RepositorioAjustesImpl(HttpService());

  Future<PerfilUsuario?> obtenerPerfil() => _repositorio.obtenerPerfil();

  Future<DatosNegocio> obtenerDatosNegocio() =>
      _repositorio.obtenerDatosNegocio();

  Future<String?> guardarDatosNegocio(DatosNegocio datos) =>
      _repositorio.guardarDatosNegocio(datos);

  Future<bool> verificarPassword(String actual) =>
      _repositorio.verificarPassword(actual);

  Future<String?> cambiarPassword(String nueva) =>
      _repositorio.cambiarPassword(nueva);
}
