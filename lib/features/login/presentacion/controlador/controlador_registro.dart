import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/empresa/dominio/codigo_empresa.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/resultado_sucursales.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class ControladorRegistro {
  final CasoUsoRegistro _casoUsoRegistro;
  final RepositorioAuth _repositorio;

  ControladorRegistro._(this._repositorio)
      : _casoUsoRegistro = CasoUsoRegistro(_repositorio);

  factory ControladorRegistro() =>
      ControladorRegistro._(RepositorioAuthImpl(HttpService()));

  /// Sucursales del gimnasio activo, con el código con el que se obtuvieron.
  ///
  /// El código que hay que enviarle al servidor (su `CODIGO_GIMNASIO`) se
  /// resuelve al escribir el código del gimnasio, pero si en ese momento la red
  /// falló pudo quedar guardado uno que el servidor no reconoce, y entonces
  /// devuelve una lista vacía: al usuario le salía "no hay sucursales" para
  /// siempre. Por eso aquí se prueban también los demás candidatos y, en cuanto
  /// uno responde, se guarda para las próximas veces.
  Future<ResultadoSucursales> cargarSucursales() async {
    final empresa = await EmpresaDao.instancia.activa();
    if (empresa == null) {
      return ResultadoSucursales.errorServidor(
          '', 'No hay un gimnasio configurado en esta app');
    }

    // El guardado primero (es el que suele funcionar); luego los candidatos
    // conocidos. `Set` para no repetir consultas si coinciden.
    final candidatos = <String>{
      empresa.codigoParaBackend,
      ...CodigoEmpresa.candidatosParaBackend(empresa.codigo),
    }.map((c) => c.trim()).where((c) => c.isNotEmpty);

    ResultadoSucursales? ultimoFallo;
    for (final candidato in candidatos) {
      final resultado = await _repositorio.sucursalesPorCodigo(candidato);

      // Sin red no se puede afirmar nada del código: no tiene sentido seguir
      // probando candidatos, todos fallarían igual.
      if (resultado.estado == EstadoSucursales.sinConexion) return resultado;

      if (resultado.hayDatos) {
        if (candidato != empresa.codigoBackend) {
          await EmpresaDao.instancia
              .actualizarCodigoBackend(empresa.id, candidato);
        }
        return resultado;
      }

      // Respondió sin sucursales (ese no es su código) o dio error: se sigue
      // con el siguiente candidato, guardando el fallo por si ninguno sirve.
      if (!resultado.consultado) ultimoFallo = resultado;
    }

    return ultimoFallo ??
        ResultadoSucursales.ok(const [], empresa.codigoParaBackend);
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
