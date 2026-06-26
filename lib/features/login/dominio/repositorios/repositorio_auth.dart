import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';

abstract class RepositorioAuth {
  Future<RespuestaLogin> login(String usuario, String password, TipoUsuario tipo);
  Future<void> logout();
}
