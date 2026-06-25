import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class CasoUsoLogin {
  final RepositorioAuth repositorio;

  CasoUsoLogin(this.repositorio);

  Future<RespuestaLogin> ejecutar(String usuario, String password) {
    return repositorio.login(usuario, password);
  }
}
