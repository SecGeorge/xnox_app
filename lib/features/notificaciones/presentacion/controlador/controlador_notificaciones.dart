import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/notificaciones/datos/repositorios/repositorio_notificaciones_impl.dart';
import 'package:xnox_app/features/notificaciones/dominio/entidades/notificacion.dart';
import 'package:xnox_app/features/notificaciones/dominio/repositorios/repositorio_notificaciones.dart';

class ControladorNotificaciones {
  final RepositorioNotificaciones _repositorio;

  ControladorNotificaciones()
      : _repositorio = RepositorioNotificacionesImpl(HttpService());

  Future<List<Notificacion>> obtener() => _repositorio.obtener();

  Future<void> marcarLeido(int id) => _repositorio.marcarLeido(id);

  /// Crea una notificación y la envía por push. Solo para administradores.
  Future<bool> crear({
    required String titulo,
    required String mensaje,
    required int tipoEnvio,
    int? miembroId,
  }) =>
      _repositorio.crear(
        titulo: titulo,
        mensaje: mensaje,
        tipoEnvio: tipoEnvio,
        miembroId: miembroId,
      );
}
