import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';

abstract class RepositorioDashboard {
  Future<EstadisticasDashboard> obtenerEstadisticas();
}
