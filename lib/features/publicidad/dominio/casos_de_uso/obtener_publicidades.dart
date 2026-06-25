import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/repositorios/repositorio_publicidad.dart';

class ObtenerPublicidades {
  final RepositorioPublicidad repositorio;

  ObtenerPublicidades(this.repositorio);

  Future<List<Publicidad>> ejecutar() async {
    return await repositorio.obtenerPublicidades();
  }
}
