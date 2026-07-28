import 'package:xnox_app/core/database/base_datos_local.dart';
import 'package:xnox_app/features/empresa/dominio/entidades/empresa.dart';

/// Acceso a la tabla `empresa` (multi-tenant). Guarda el gimnasio cuyo código
/// escribió el usuario en el arranque y cuál está activo.
class EmpresaDao {
  EmpresaDao._interno();
  static final EmpresaDao instancia = EmpresaDao._interno();

  final _bd = BaseDatosLocal.instancia;

  /// Contenido crudo de la tabla, para inspeccionarla desde la consola de
  /// `flutter run` (la BD vive en el dispositivo, no en el PC).
  Future<List<Map<String, Object?>>> volcado() async {
    final db = await _bd.db;
    return db.query('empresa', orderBy: 'id ASC');
  }

  /// El gimnasio guardado con ese [codigo], o `null` si no está en la tabla.
  /// Se consulta al escribir el código: si ya lo conocemos usamos su URL exacta
  /// en vez de armarla desde el subdominio. Sin distinguir mayúsculas por si
  /// quedó guardado con otra forma.
  Future<Empresa?> porCodigo(String codigo) async {
    final db = await _bd.db;
    final filas = await db.query(
      'empresa',
      where: 'codigo = ? COLLATE NOCASE',
      whereArgs: [codigo],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    return Empresa.desdeMapa(filas.first);
  }

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
    String? codigoBackend,
  }) async {
    final db = await _bd.db;
    final datos = {
      'nombre': nombre ?? codigo,
      'ruta_global': rutaGlobal,
      'codigo_backend': ?codigoBackend,
      'activa': 1,
    };
    await db.transaction((txn) async {
      await txn.update('empresa', {'activa': 0});
      final actualizadas = await txn.update(
        'empresa',
        datos,
        where: 'codigo = ?',
        whereArgs: [codigo],
      );
      if (actualizadas == 0) {
        await txn.insert('empresa', {'codigo': codigo, ...datos});
      }
    });
    return activa();
  }

  /// Corrige el código que el servidor reconoce en sus peticiones cuando se
  /// descubre cuál es de verdad (p. ej. al cargar las sucursales en el
  /// registro). Sin esto, un valor mal resuelto en el arranque —porque la red
  /// falló justo en ese momento— se quedaba guardado para siempre y el
  /// registro de clientes no encontraba sucursales nunca más.
  Future<void> actualizarCodigoBackend(int id, String codigoBackend) async {
    final db = await _bd.db;
    await db.update(
      'empresa',
      {'codigo_backend': codigoBackend},
      where: 'id = ?',
      whereArgs: [id],
    );
  }
}
