import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/resultado_sucursales.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';

abstract class RepositorioAuth {
  Future<RespuestaLogin> login(String usuario, String password, TipoUsuario tipo);
  Future<RespuestaLogin> registrarCliente(DatosRegistro datos);

  /// Sucursales que el gimnasio devuelve para [codigoGimnasio]. El resultado
  /// distingue "no hay ninguna" de "no se pudo consultar".
  Future<ResultadoSucursales> sucursalesPorCodigo(String codigoGimnasio);
  Future<void> logout();

  /// Devuelve el tipo de usuario de la sesión guardada, o null si no hay
  /// ninguna sesión activa (el usuario debe iniciar sesión).
  Future<TipoUsuario?> sesionActiva();
}
