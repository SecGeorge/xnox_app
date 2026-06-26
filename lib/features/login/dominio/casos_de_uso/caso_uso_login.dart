import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class CasoUsoLogin {
  final RepositorioAuth repositorio;

  CasoUsoLogin(this.repositorio);

  Future<RespuestaLogin> ejecutar(
      String usuario, String password, TipoUsuario tipo) {
    return repositorio.login(usuario, password, tipo);
  }
}
