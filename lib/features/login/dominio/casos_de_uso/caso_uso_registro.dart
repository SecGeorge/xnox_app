import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class CasoUsoRegistro {
  final RepositorioAuth repositorio;

  CasoUsoRegistro(this.repositorio);

  Future<RespuestaLogin> ejecutar(DatosRegistro datos) {
    return repositorio.registrarCliente(datos);
  }
}
