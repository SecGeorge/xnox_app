import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/repositorios/repositorio_publicidad.dart';

class CrearPublicidad {
  final RepositorioPublicidad repositorio;

  CrearPublicidad(this.repositorio);

  Future<bool> ejecutar(Publicidad publicidad, Map<String, dynamic> imagen) async {
    return await repositorio.crearPublicidad(publicidad, imagen);
  }
}
