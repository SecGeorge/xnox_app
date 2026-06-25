import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';
import 'package:xnox_app/features/dashboard/dominio/repositorios/repositorio_dashboard.dart';

class CasoUsoEstadisticas {
  final RepositorioDashboard repositorio;

  CasoUsoEstadisticas(this.repositorio);

  Future<EstadisticasDashboard> ejecutar() {
    return repositorio.obtenerEstadisticas();
  }
}
