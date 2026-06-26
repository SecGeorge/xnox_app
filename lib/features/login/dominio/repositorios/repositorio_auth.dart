import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/sucursal.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';

abstract class RepositorioAuth {
  Future<RespuestaLogin> login(String usuario, String password, TipoUsuario tipo);
  Future<RespuestaLogin> registrarCliente(DatosRegistro datos);
  Future<List<Sucursal>> sucursalesPorCodigo(String codigoGimnasio);
  Future<void> logout();
}
