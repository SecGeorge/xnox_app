import 'package:xnox_app/features/notificaciones/dominio/entidades/notificacion.dart';

abstract class RepositorioNotificaciones {
  /// Obtiene las notificaciones no leídas de la sucursal activa.
  Future<List<Notificacion>> obtener();

  /// Marca una notificación como leída.
  Future<void> marcarLeido(int id);

  /// Crea una notificación y la envía por push al público indicado.
  ///
  /// Solo el administrador puede hacerlo; el backend lo verifica por sesión.
  /// [tipoEnvio]: 1 admin, 2 clientes, 3 colaboradores. Si [miembroId] tiene
  /// valor, el aviso va únicamente a ese socio.
  Future<bool> crear({
    required String titulo,
    required String mensaje,
    required int tipoEnvio,
    String tipo = 'info',
    int? miembroId,
  });
}
