import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';

abstract class RepositorioPublicidad {
  Future<List<Publicidad>> obtenerPublicidades();
  Future<bool> crearPublicidad(Publicidad publicidad, Map<String, dynamic> imagen);
}
