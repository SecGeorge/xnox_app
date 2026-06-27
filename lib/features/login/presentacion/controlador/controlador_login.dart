import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';

class ControladorLogin {
  final CasoUsoLogin _casoUsoLogin;
  final RepositorioAuthImpl _repositorio;

  ControladorLogin._(this._repositorio)
      : _casoUsoLogin = CasoUsoLogin(_repositorio);

  factory ControladorLogin() =>
      ControladorLogin._(RepositorioAuthImpl(HttpService()));

  Future<RespuestaLogin> login(
      String usuario, String password, TipoUsuario tipo) async {
    if (usuario.isEmpty || password.isEmpty) {
      return RespuestaLogin(success: false, message: 'Por favor, complete todos los campos');
    }
    return await _casoUsoLogin.ejecutar(usuario, password, tipo);
  }

  /// Tipo de usuario de la sesión guardada (null si debe iniciar sesión).
  Future<TipoUsuario?> sesionActiva() => _repositorio.sesionActiva();
}
