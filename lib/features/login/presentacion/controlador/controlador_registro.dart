import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/sucursal.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class ControladorRegistro {
  final CasoUsoRegistro _casoUsoRegistro;
  final RepositorioAuth _repositorio;

  ControladorRegistro._(this._repositorio)
      : _casoUsoRegistro = CasoUsoRegistro(_repositorio);

  factory ControladorRegistro() =>
      ControladorRegistro._(RepositorioAuthImpl(HttpService()));

  /// Carga las sucursales del gimnasio identificado por su código.
  /// Devuelve lista vacía si el código no es válido.
  Future<List<Sucursal>> cargarSucursales(String codigoGimnasio) {
    return _repositorio.sucursalesPorCodigo(codigoGimnasio.trim());
  }

  Future<RespuestaLogin> registrar({
    required String codigoGimnasio,
    required int? idSucursal,
    required String documento,
    required String password,
    required String confirmar,
  }) async {
    if (codigoGimnasio.trim().isEmpty) {
      return RespuestaLogin(
          success: false, message: 'Ingresa el código de gimnasio');
    }
    if (idSucursal == null) {
      return RespuestaLogin(
          success: false, message: 'Selecciona una sucursal');
    }
    if (documento.trim().isEmpty || password.trim().isEmpty) {
      return RespuestaLogin(
          success: false, message: 'Ingresa tu DNI y contraseña');
    }
    if (password.length < 4) {
      return RespuestaLogin(
          success: false,
          message: 'La contraseña debe tener al menos 4 caracteres');
    }
    if (password != confirmar) {
      return RespuestaLogin(
          success: false, message: 'Las contraseñas no coinciden');
    }

    return _casoUsoRegistro.ejecutar(DatosRegistro(
      codigoGimnasio: codigoGimnasio.trim(),
      idSucursal: idSucursal,
      documento: documento.trim(),
      password: password,
    ));
  }
}
