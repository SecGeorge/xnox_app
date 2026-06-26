import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';

abstract class RepositorioMiembros {
  /// Trae todos los miembros de la sucursal activa (endpoint `buscar`).
  Future<List<Miembro>> buscar();
}
