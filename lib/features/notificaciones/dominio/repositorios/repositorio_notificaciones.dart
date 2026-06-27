import 'package:xnox_app/features/notificaciones/dominio/entidades/notificacion.dart';

abstract class RepositorioNotificaciones {
  /// Obtiene las notificaciones no leídas de la sucursal activa.
  Future<List<Notificacion>> obtener();

  /// Marca una notificación como leída.
  Future<void> marcarLeido(int id);
}
