import 'package:xnox_app/core/database/base_datos_local.dart';
import 'package:xnox_app/features/empresa/dominio/entidades/empresa.dart';

/// Acceso a la tabla `empresa` (multi-tenant). Guarda el gimnasio cuyo código
/// escribió el usuario en el arranque y cuál está activo.
class EmpresaDao {
  EmpresaDao._interno();
  static final EmpresaDao instancia = EmpresaDao._interno();

  final _bd = BaseDatosLocal.instancia;

  /// La empresa marcada como activa, o `null` si aún no se escribió el código.
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

  /// Guarda el gimnasio [codigo] con su [rutaGlobal] y lo deja como el único
  /// activo, todo de forma atómica. Si el código ya estaba se le actualiza la
  /// ruta. Devuelve la empresa activada.
  Future<Empresa?> guardarYActivar({
    required String codigo,
    required String rutaGlobal,
    String? nombre,
  }) async {
    final db = await _bd.db;
    await db.transaction((txn) async {
      await txn.update('empresa', {'activa': 0});
      final actualizadas = await txn.update(
        'empresa',
        {
          'nombre': nombre ?? codigo,
          'ruta_global': rutaGlobal,
          'activa': 1,
        },
        where: 'codigo = ?',
        whereArgs: [codigo],
      );
      if (actualizadas == 0) {
        await txn.insert('empresa', {
          'codigo': codigo,
          'nombre': nombre ?? codigo,
          'ruta_global': rutaGlobal,
          'activa': 1,
        });
      }
    });
    return activa();
  }
}
