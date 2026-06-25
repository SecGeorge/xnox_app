import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';

abstract class RepositorioAuth {
  Future<RespuestaLogin> login(String usuario, String password);
}
