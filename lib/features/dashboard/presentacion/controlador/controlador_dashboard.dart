import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/dashboard/datos/repositorios/repositorio_dashboard_impl.dart';
import 'package:xnox_app/features/dashboard/dominio/casos_de_uso/caso_uso_estadisticas.dart';
import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';

class ControladorDashboard {
  final CasoUsoEstadisticas _casoUsoEstadisticas;

  ControladorDashboard() 
    : _casoUsoEstadisticas = CasoUsoEstadisticas(RepositorioDashboardImpl(HttpService()));

  Future<EstadisticasDashboard> obtenerEstadisticas() async {
    return await _casoUsoEstadisticas.ejecutar();
  }
}
