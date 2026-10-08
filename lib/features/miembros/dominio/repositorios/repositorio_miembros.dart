import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';

abstract class RepositorioMiembros {
  /// Trae todos los miembros de la sucursal activa (endpoint `buscar`).
  Future<List<Miembro>> buscar();

  /// Membresías vigentes que vencen en los próximos [dias] días.
  Future<List<MiembroAlerta>> proximosVencer({int dias = 7});

  /// Membresías que vencieron en los últimos [dias] días (para recuperarlos).
  Future<List<MiembroAlerta>> vencidosRecuperar({int dias = 30});
}
