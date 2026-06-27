import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';

abstract class RepositorioPublicidad {
  /// Listado para el panel admin (todas menos las eliminadas).
  Future<List<Publicidad>> obtenerPublicidades();

  /// Listado para el cliente: solo campañas activadas y vigentes.
  Future<List<Publicidad>> obtenerPublicidadesActivas();

  /// Crea una campaña. [imagenBase64] es la imagen codificada (opcional).
  Future<bool> crearPublicidad(Publicidad publicidad, String? imagenBase64);

  /// Edita una campaña existente. [imagenBase64] solo si se cambió la imagen.
  Future<bool> editarPublicidad(Publicidad publicidad, String? imagenBase64);

  /// Elimina (lógico, estado = 2) una campaña.
  Future<bool> eliminarPublicidad(int id);
}
