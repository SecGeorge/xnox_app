import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';
import 'package:xnox_app/features/dashboard/dominio/repositorios/repositorio_dashboard.dart';

class RepositorioDashboardImpl implements RepositorioDashboard {
  final HttpService _httpService;

  RepositorioDashboardImpl(this._httpService);

  @override
  Future<EstadisticasDashboard> obtenerEstadisticas() async {
    try {
      // Asumimos un endpoint dashboard.php con el metodo obtener_resumen
      final response = await _httpService.obtenerConDatos(
        {'metodo': 'obtener_resumen'},
        'dashboard.php',
      );

      if (response != null && response['resultado'] == true) {
        return EstadisticasDashboard.fromJson(response['datos']);
      }

      // Datos de prueba si el backend falla o no existe el endpoint aún.
      // TODO: eliminar al integrar con la base de datos real.
      return EstadisticasDashboard.demo();
    } catch (e) {
      // Datos de prueba en caso de error.
      // TODO: eliminar al integrar con la base de datos real.
      return EstadisticasDashboard.demo();
    }
  }
}
