import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xnox_app/core/database/base_datos_local.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';

/// Medidas corporales del socio (pecho, bíceps, cintura…).
///
/// Se guardan primero en el SQLite del teléfono (funciona sin red) y luego se
/// suben a la BD central por `medidas.php`, para no perderlas al cambiar de
/// teléfono. Van separadas por usuario por si el equipo es compartido.
class AlmacenMedidas {
  AlmacenMedidas._interno();
  static final AlmacenMedidas instancia = AlmacenMedidas._interno();

  static const _ruta = 'medidas.php';
  final _http = HttpService();
  final _azar = Random.secure();

  Future<String> _usuario() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('idUsuario') ?? '';
  }

  /// Identificador propio de cada medida, para que el servidor no la duplique
  /// si un envío se repite.
  String _nuevoUid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_azar.nextInt(1 << 32)}';

  /// Todas las medidas del socio, de la más antigua a la más reciente.
  Future<List<Medida>> listar() async {
    final db = await BaseDatosLocal.instancia.db;
    final filas = await db.query(
      'medida',
      where: 'usuario_id = ? AND eliminado = 0',
      whereArgs: [await _usuario()],
      orderBy: 'fecha ASC, id ASC',
    );
    return filas.map(Medida.desdeMapa).toList();
  }

  Future<void> registrar(String zona, double valor) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.insert('medida', {
      'usuario_id': await _usuario(),
      'uid': _nuevoUid(),
      'zona': zona,
      'fecha': DateTime.now().toIso8601String(),
      'valor': valor,
    });
    await sincronizar();
  }

  Future<void> eliminar(int id) async {
    final db = await BaseDatosLocal.instancia.db;
    // Si nunca llegó al servidor se borra ya; si llegó, queda marcada hasta
    // que el servidor confirme el borrado.
    await db.delete(
      'medida',
      where: 'id = ? AND servidor_id IS NULL',
      whereArgs: [id],
    );
    await db.update(
      'medida',
      {'eliminado': 1},
      where: 'id = ?',
      whereArgs: [id],
    );
    await sincronizar();
  }

  bool _exito(dynamic resp) =>
      resp is List &&
      resp.isNotEmpty &&
      resp.first is Map &&
      '${resp.first['voit_exito']}' == '1';

  /// Sube los cambios pendientes y luego trae lo que hay en el servidor (las
  /// medidas registradas desde otro teléfono). Sin red no hace nada: lo
  /// pendiente se sube en la próxima.
  Future<void> sincronizar() async {
    if (!await _http.hayInternet()) return;
    final db = await BaseDatosLocal.instancia.db;
    final usuario = await _usuario();
    if (usuario.isEmpty) return;

    // 1) Borrados pendientes.
    final borrar = await db.query(
      'medida',
      where: 'usuario_id = ? AND eliminado = 1 AND servidor_id IS NOT NULL',
      whereArgs: [usuario],
    );
    for (final f in borrar) {
      final resp = await _http.obtenerConDatos({
        'metodo': 'eliminar',
        'id': f['servidor_id'],
      }, _ruta);
      if (!_exito(resp)) return; // Sin servidor: se reintenta luego.
      await db.delete('medida', where: 'id = ?', whereArgs: [f['id']]);
    }

    // 2) Altas pendientes.
    final subir = await db.query(
      'medida',
      where: 'usuario_id = ? AND eliminado = 0 AND servidor_id IS NULL',
      whereArgs: [usuario],
    );
    final formato = DateFormat('yyyy-MM-dd HH:mm:ss');
    for (final f in subir) {
      final resp = await _http.obtenerConDatos({
        'metodo': 'registrar',
        'medida': {
          'uid': f['uid'],
          'zona': f['zona'],
          'valor': f['valor'],
          'fecha': formato.format(DateTime.parse(f['fecha'] as String)),
        },
      }, _ruta);
      if (!_exito(resp)) return;
      await db.update(
        'medida',
        {'servidor_id': int.tryParse('${(resp as List).first['voit_id']}')},
        where: 'id = ?',
        whereArgs: [f['id']],
      );
    }

    // 3) Lo que hay en el servidor manda: se agrega lo que falta y se quita lo
    // que se borró desde otro teléfono.
    final resp = await _http.obtenerConDatos({'metodo': 'listar'}, _ruta);
    if (resp is! List) return;
    final enServidor = <int>{};
    final batch = db.batch();
    for (final r in resp.whereType<Map>()) {
      final servidorId = int.tryParse('${r['id']}');
      final valor = double.tryParse('${r['valor']}');
      final fecha = DateTime.tryParse('${r['fecha']}');
      if (servidorId == null || valor == null || fecha == null) continue;
      enServidor.add(servidorId);
      batch.insert('medida', {
        'usuario_id': usuario,
        'uid': '${r['uid']}',
        'servidor_id': servidorId,
        'zona': '${r['zona']}',
        'fecha': fecha.toIso8601String(),
        'valor': valor,
      }, conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);

    final locales = await db.query(
      'medida',
      columns: ['id', 'servidor_id'],
      where: 'usuario_id = ? AND servidor_id IS NOT NULL AND eliminado = 0',
      whereArgs: [usuario],
    );
    for (final f in locales) {
      if (!enServidor.contains(f['servidor_id'])) {
        await db.delete('medida', where: 'id = ?', whereArgs: [f['id']]);
      }
    }
  }
}
