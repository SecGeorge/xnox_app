import 'package:xnox_app/core/database/base_datos_local.dart';
import 'package:xnox_app/features/empresa/dominio/entidades/empresa.dart';

/// Acceso a la tabla `empresa` (catálogo multi-tenant). Permite listar el
/// catálogo sembrado, saber cuál está activa y cambiar la activa.
class EmpresaDao {
  EmpresaDao._interno();
  static final EmpresaDao instancia = EmpresaDao._interno();

  final _bd = BaseDatosLocal.instancia;

  /// Todas las empresas del catálogo, para la pantalla de selección.
  Future<List<Empresa>> listar() async {
    final db = await _bd.db;
    final filas = await db.query('empresa', orderBy: 'nombre ASC');
    return filas.map(Empresa.desdeMapa).toList();
  }

  /// La empresa marcada como activa, o `null` si aún no se eligió ninguna.
  Future<Empresa?> activa() async {
    final db = await _bd.db;
    final filas = await db.query(
      'empresa',
      where: 'activa = 1',
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Empresa.desdeMapa(filas.first);
  }

  /// Marca [codigo] como la única empresa activa (desactiva el resto) de forma
  /// atómica. Devuelve la empresa activada, o `null` si el código no existe.
  Future<Empresa?> activar(String codigo) async {
    final db = await _bd.db;
    await db.transaction((txn) async {
      await txn.update('empresa', {'activa': 0});
      await txn.update(
        'empresa',
        {'activa': 1},
        where: 'codigo = ?',
        whereArgs: [codigo],
      );
    });
    return activa();
  }
}
