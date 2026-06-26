import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';

abstract class RepositorioPublicidad {
  /// Listado para el panel admin (todas menos las eliminadas).
  Future<List<Publicidad>> obtenerPublicidades();

  /// Listado para el cliente: solo campañas activadas y vigentes.
  Future<List<Publicidad>> obtenerPublicidadesActivas();

  Future<bool> crearPublicidad(Publicidad publicidad, Map<String, dynamic> imagen);
}
