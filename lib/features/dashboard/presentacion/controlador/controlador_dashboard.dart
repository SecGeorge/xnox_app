import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/dashboard/datos/repositorios/repositorio_dashboard_impl.dart';
import 'package:xnox_app/features/dashboard/dominio/casos_de_uso/caso_uso_estadisticas.dart';
import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_logout.dart';

class ControladorDashboard {
  final CasoUsoEstadisticas _casoUsoEstadisticas;
  final CasoUsoLogout _casoUsoLogout;

  ControladorDashboard() 
    : _casoUsoEstadisticas = CasoUsoEstadisticas(RepositorioDashboardImpl(HttpService())),
      _casoUsoLogout = CasoUsoLogout(RepositorioAuthImpl(HttpService()));

  Future<EstadisticasDashboard> obtenerEstadisticas() async {
    return await _casoUsoEstadisticas.ejecutar();
  }

  Future<void> cerrarSesion() async {
    await _casoUsoLogout.ejecutar();
  }
}
