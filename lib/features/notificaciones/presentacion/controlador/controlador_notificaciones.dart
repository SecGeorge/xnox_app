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
}
