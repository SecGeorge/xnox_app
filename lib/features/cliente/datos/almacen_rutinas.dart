import 'dart:async';
import 'dart:math';

import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'package:xnox_app/core/database/base_datos_local.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';

/// Almacén de rutinas respaldado por SQLite, con una caché en memoria.
///
/// La caché permite que la UI (incluidos los reportes de avance) lea las
/// rutinas y sus ejercicios de forma síncrona, mientras que las mutaciones y la
/// sincronización con el backend son asíncronas (escriben en SQLite y luego
/// recargan la caché).
///
/// Las rutinas propias del socio y sus sesiones/series se guardan en el
/// backend (`entrenamiento.php`), que es quien manda. Cada cambio se escribe
/// primero en SQLite marcado como pendiente y se sube enseguida; sin internet
/// se queda pendiente y se sube en la próxima sincronización.
class AlmacenRutinas {
  AlmacenRutinas._interno();
  static final AlmacenRutinas instancia = AlmacenRutinas._interno();

  static const _ruta = 'entrenamiento.php';
  final _http = HttpService();
  final _azar = Random.secure();

  List<Rutina> _rutinas = [];
  bool _cargado = false;

  // ----------------------------------------------------------------- Lecturas
  List<Rutina> get rutinas => List.unmodifiable(_rutinas);

  /// Rutinas generales del administrador, las que ven todos los clientes.
  List<Rutina> get rutinasSugeridas =>
      _rutinas.where((r) => r.esGeneral).toList();

  /// Rutina(s) que el administrador armó para este cliente (solo lectura).
  List<Rutina> get rutinasAsignadas =>
      _rutinas.where((r) => r.esSugerida && r.personalizada).toList();

  /// Rutinas propias del cliente (CRUD local).
  List<Rutina> get rutinasCliente =>
      _rutinas.where((r) => r.origen == OrigenRutina.cliente).toList();

  /// Todos los ejercicios de todas las rutinas (para el reporte de avance).
  List<Ejercicio> get todosLosEjercicios => [
    for (final r in _rutinas) ...r.ejercicios,
  ];

  Rutina? buscarRutina(int id) {
    for (final r in _rutinas) {
      if (r.id == id) return r;
    }
    return null;
  }

  /// Carga la caché desde SQLite (una sola vez salvo que se fuerce).
  Future<void> asegurarCargado() async {
    if (_cargado) return;
    await cargar();
  }

  /// Recarga toda la caché desde SQLite ensamblando el árbol completo.
  Future<void> cargar() async {
    final db = await BaseDatosLocal.instancia.db;

    final rutinasRows = await db.query('rutina', orderBy: 'id ASC');
    final diasRows = await db.query('rutina_dia', orderBy: 'orden ASC, id ASC');
    final ejRows = await db.query('ejercicio', orderBy: 'orden ASC, id ASC');
    final marcaRows = await db.query('marca', orderBy: 'fecha ASC, id ASC');
    final serieRows = await db.query(
      'serie',
      orderBy: 'marca_id ASC, numero ASC',
    );

    // Series agrupadas por sesión (marca_id) -> [12, 10, 8, 8] y sus pesos.
    final seriesPorMarca = <int, List<int>>{};
    final pesosPorMarca = <int, List<double?>>{};
    final izqPorMarca = <int, List<int?>>{};
    final derPorMarca = <int, List<int?>>{};
    for (final s in serieRows) {
      final marcaId = s['marca_id'] as int;
      (seriesPorMarca[marcaId] ??= []).add(s['repeticiones'] as int? ?? 0);
      (pesosPorMarca[marcaId] ??= []).add((s['peso'] as num?)?.toDouble());
      (izqPorMarca[marcaId] ??= []).add(s['reps_izq'] as int?);
      (derPorMarca[marcaId] ??= []).add(s['reps_der'] as int?);
    }

    // Marcas agrupadas por ejercicio.
    final marcasPorEj = <int, List<Marca>>{};
    for (final m in marcaRows) {
      final ejId = m['ejercicio_id'] as int;
      final marcaId = m['id'] as int;
      // Series desde la tabla normalizada; fallback al texto legado si faltara.
      final reps =
          seriesPorMarca[marcaId] ?? _parsearReps(m['reps_series'] as String?);
      final pesoSesion = (m['peso'] as num?)?.toDouble() ?? 0;
      final pesos = [
        for (final p in pesosPorMarca[marcaId] ?? const <double?>[])
          p ?? pesoSesion,
      ];
      marcasPorEj
          .putIfAbsent(ejId, () => [])
          .add(
            Marca(
              id: marcaId,
              fecha:
                  DateTime.tryParse(m['fecha'] as String? ?? '') ??
                  DateTime.now(),
              peso: pesoSesion,
              repeticiones: m['repeticiones'] as int? ?? 0,
              repsPorSerie: reps,
              pesoPorSerie: pesos,
              repsIzqPorSerie: izqPorMarca[marcaId],
              repsDerPorSerie: derPorMarca[marcaId],
            ),
          );
    }

    // Ejercicios agrupados por día.
    final ejPorDia = <int, List<Ejercicio>>{};
    for (final e in ejRows) {
      final id = e['id'] as int;
      final diaId = e['dia_id'] as int;
      ejPorDia
          .putIfAbsent(diaId, () => [])
          .add(
            Ejercicio(
              id: id,
              nombre: e['nombre'] as String? ?? '',
              series: e['series'] as int? ?? 0,
              repeticiones: e['repeticiones'] as int? ?? 0,
              observaciones: e['observaciones'] as String?,
              catalogoId: e['catalogo_id'] as int?,
              imagenUrl: e['imagen_url'] as String?,
              videoUrl: e['video_url'] as String?,
              descansoSeg: e['descanso_seg'] as int?,
              unilateral: (e['unilateral'] as int? ?? 0) == 1,
              marcas: marcasPorEj[id] ?? [],
            ),
          );
    }

    // Días agrupados por rutina.
    final diasPorRutina = <int, List<DiaRutina>>{};
    for (final d in diasRows) {
      final id = d['id'] as int;
      final rutinaId = d['rutina_id'] as int;
      diasPorRutina
          .putIfAbsent(rutinaId, () => [])
          .add(
            DiaRutina(
              id: id,
              diaSemana: d['dia_semana'] as String? ?? '',
              ejercicios: ejPorDia[id] ?? [],
            ),
          );
    }

    _rutinas = rutinasRows.map((r) {
      final id = r['id'] as int;
      return Rutina(
        id: id,
        servidorId: r['servidor_id'] as int?,
        nombre: r['nombre'] as String? ?? '',
        descripcion: r['descripcion'] as String? ?? '',
        origen: (r['origen'] as String?) == 'admin'
            ? OrigenRutina.admin
            : OrigenRutina.cliente,
        personalizada: (r['personalizada'] as int? ?? 0) == 1,
        dias: diasPorRutina[id] ?? [],
      );
    }).toList();

    _cargado = true;
  }

  // ----------------------------------------------------- Mutaciones (cliente)
  Future<int> crearRutina(String nombre, String descripcion) async {
    final db = await BaseDatosLocal.instancia.db;
    final id = await db.insert('rutina', {
      'servidor_id': null,
      'nombre': nombre,
      'descripcion': descripcion,
      'origen': 'cliente',
      'fecha_sync': null,
      'uid': _nuevoUid(),
      'pendiente': 1,
    });
    await cargar();
    _subirCambios();
    return id;
  }

  Future<void> editarRutina(int id, String nombre, String descripcion) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.rawUpdate(
      "UPDATE rutina SET nombre = ?, descripcion = ?, pendiente = pendiente + 1 WHERE id = ? AND origen = 'cliente'",
      [nombre, descripcion, id],
    );
    await cargar();
    _subirCambios();
  }

  /// Elimina una rutina del cliente (con sus días, ejercicios y marcas).
  Future<void> eliminarRutina(int id) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      final filas = await txn.query(
        'rutina',
        columns: ['uid'],
        where: 'id = ? AND origen = ?',
        whereArgs: [id, 'cliente'],
      );
      if (filas.isEmpty) return;
      await _anotarBorradoMarcas(
        txn,
        'SELECT m.uid FROM marca m JOIN ejercicio e ON e.id = m.ejercicio_id '
        'JOIN rutina_dia d ON d.id = e.dia_id WHERE d.rutina_id = ?',
        [id],
      );
      await _anotarBorrado(txn, 'rutina', filas.first['uid'] as String?);
      await txn.delete('rutina', where: 'id = ?', whereArgs: [id]);
    });
    await cargar();
    _subirCambios();
  }

  Future<int> agregarDia(int rutinaId, String diaSemana) async {
    final db = await BaseDatosLocal.instancia.db;
    final orden =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM rutina_dia WHERE rutina_id = ?',
            [rutinaId],
          ),
        ) ??
        0;
    final id = await db.insert('rutina_dia', {
      'rutina_id': rutinaId,
      'dia_semana': diaSemana,
      'orden': orden,
    });
    await _tocarRutina(db, 'SELECT ?', [rutinaId]);
    await cargar();
    _subirCambios();
    return id;
  }

  Future<void> eliminarDia(int diaId) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await _tocarRutina(txn, 'SELECT rutina_id FROM rutina_dia WHERE id = ?', [
        diaId,
      ]);
      await _anotarBorradoMarcas(
        txn,
        'SELECT m.uid FROM marca m JOIN ejercicio e ON e.id = m.ejercicio_id '
        'WHERE e.dia_id = ?',
        [diaId],
      );
      await txn.delete('rutina_dia', where: 'id = ?', whereArgs: [diaId]);
    });
    await cargar();
    _subirCambios();
  }

  /// [catalogoId], [imagenUrl] y [videoUrl] llegan cuando el ejercicio se
  /// eligió (o se acaba de crear) en el catálogo del gimnasio; a mano quedan
  /// en null.
  Future<void> agregarEjercicio(
    int diaId,
    String nombre,
    int series,
    int repeticiones, {
    String? observaciones,
    int? catalogoId,
    String? imagenUrl,
    String? videoUrl,
    bool unilateral = false,
  }) async {
    final db = await BaseDatosLocal.instancia.db;
    final orden =
        Sqflite.firstIntValue(
          await db.rawQuery('SELECT COUNT(*) FROM ejercicio WHERE dia_id = ?', [
            diaId,
          ]),
        ) ??
        0;
    await db.insert('ejercicio', {
      'dia_id': diaId,
      'nombre': nombre,
      'series': series,
      'repeticiones': repeticiones,
      'observaciones': observaciones,
      'catalogo_id': catalogoId,
      'imagen_url': imagenUrl,
      'video_url': videoUrl,
      'unilateral': unilateral ? 1 : 0,
      'orden': orden,
    });
    await _tocarRutina(db, 'SELECT rutina_id FROM rutina_dia WHERE id = ?', [
      diaId,
    ]);
    await cargar();
    _subirCambios();
  }

  /// Marca o desmarca un ejercicio como unilateral. Es preferencia del socio
  /// (vale también en las rutinas del gimnasio: la sincronización no la pisa).
  Future<void> cambiarUnilateral(int ejercicioId, bool unilateral) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.update(
      'ejercicio',
      {'unilateral': unilateral ? 1 : 0},
      where: 'id = ?',
      whereArgs: [ejercicioId],
    );
    await _tocarRutina(db, _rutinaDeEjercicio, [ejercicioId]);
    await cargar();
    _subirCambios();
  }

  Future<void> eliminarEjercicio(int ejercicioId) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await _tocarRutina(txn, _rutinaDeEjercicio, [ejercicioId]);
      await _anotarBorradoMarcas(
        txn,
        'SELECT uid FROM marca WHERE ejercicio_id = ?',
        [ejercicioId],
      );
      await txn.delete('ejercicio', where: 'id = ?', whereArgs: [ejercicioId]);
    });
    await cargar();
    _subirCambios();
  }

  /// Registra una marca (peso + reps por serie) en un ejercicio. Se permite en
  /// cualquier ejercicio —incluidas las rutinas sugeridas— porque es el
  /// seguimiento del progreso del cliente que alimenta los reportes.
  ///
  /// [repsPorSerie] son las repeticiones hechas en cada serie. En
  /// `repeticiones` se guarda el total (suma) para no romper los reportes.
  Future<void> agregarMarca(
    int ejercicioId,
    double peso,
    List<int> repsPorSerie,
  ) async {
    final db = await BaseDatosLocal.instancia.db;
    final total = repsPorSerie.fold<int>(0, (a, b) => a + b);
    await db.transaction((txn) async {
      // La sesión (marca) y sus series quedan agrupadas por marca_id.
      final marcaId = await txn.insert('marca', {
        'ejercicio_id': ejercicioId,
        'fecha': DateTime.now().toIso8601String(),
        'peso': peso,
        'repeticiones': total,
        'reps_series': repsPorSerie.join(','), // legado/fallback
        'uid': _nuevoUid(),
        'pendiente': 1,
      });
      final batch = txn.batch();
      for (var i = 0; i < repsPorSerie.length; i++) {
        batch.insert('serie', {
          'marca_id': marcaId,
          'numero': i + 1,
          'repeticiones': repsPorSerie[i],
          'peso': peso,
        });
      }
      await batch.commit(noResult: true);
    });
    await cargar();
    _subirCambios();
  }

  // ----------------------------------------- Registro serie por serie (hoy)

  /// Agrega UNA serie a la sesión de HOY del ejercicio. Si aún no hay sesión
  /// de hoy, la crea. Devuelve el id de la sesión (marca) para poder editarla.
  ///
  /// En un ejercicio unilateral llegan [izq] y [der]; entonces [reps] es el
  /// lado más flojo (lo que cuenta para el objetivo "10 por lado").
  Future<int> agregarSerie(
    int ejercicioId,
    double peso,
    int reps, {
    int? izq,
    int? der,
  }) async {
    final db = await BaseDatosLocal.instancia.db;
    late int marcaId;
    await db.transaction((txn) async {
      final marcaHoy = await _marcaDeHoy(txn, ejercicioId);
      if (marcaHoy == null) {
        marcaId = await txn.insert('marca', {
          'ejercicio_id': ejercicioId,
          'fecha': DateTime.now().toIso8601String(),
          'peso': peso,
          'repeticiones': reps,
          'reps_series': '$reps',
          'uid': _nuevoUid(),
        });
      } else {
        marcaId = marcaHoy['id'] as int;
      }
      final cuantas =
          Sqflite.firstIntValue(
            await txn.rawQuery(
              'SELECT COUNT(*) FROM serie WHERE marca_id = ?',
              [marcaId],
            ),
          ) ??
          0;
      await txn.insert('serie', {
        'marca_id': marcaId,
        'numero': cuantas + 1,
        'repeticiones': reps,
        'peso': peso,
        'reps_izq': izq,
        'reps_der': der,
      });
      await _recomputarMarca(txn, marcaId);
    });
    await cargar();
    _subirCambios();
    return marcaId;
  }

  /// Edita las repeticiones de una serie puntual de una sesión (con [izq] y
  /// [der] si es unilateral, igual que en [agregarSerie]).
  Future<void> editarSerie(
    int marcaId,
    int numero,
    int reps, {
    int? izq,
    int? der,
  }) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await txn.update(
        'serie',
        {'repeticiones': reps, 'reps_izq': izq, 'reps_der': der},
        where: 'marca_id = ? AND numero = ?',
        whereArgs: [marcaId, numero],
      );
      await _recomputarMarca(txn, marcaId);
    });
    await cargar();
    _subirCambios();
  }

  /// Cambia el peso de UNA serie de la sesión, sin tocar las demás.
  Future<void> editarPesoSerie(int marcaId, int numero, double peso) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await txn.update(
        'serie',
        {'peso': peso},
        where: 'marca_id = ? AND numero = ?',
        whereArgs: [marcaId, numero],
      );
      await _recomputarMarca(txn, marcaId);
    });
    await cargar();
    _subirCambios();
  }

  /// Elimina una serie de la sesión, renumera las restantes y recalcula los
  /// totales. Si la sesión se queda sin series, elimina la sesión completa.
  Future<void> eliminarSerie(int marcaId, int numero) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await txn.delete(
        'serie',
        where: 'marca_id = ? AND numero = ?',
        whereArgs: [marcaId, numero],
      );
      final restantes = await txn.query(
        'serie',
        where: 'marca_id = ?',
        whereArgs: [marcaId],
        orderBy: 'numero ASC',
      );
      // Renumerar 1..N para mantener la secuencia.
      for (var i = 0; i < restantes.length; i++) {
        await txn.update(
          'serie',
          {'numero': i + 1},
          where: 'id = ?',
          whereArgs: [restantes[i]['id']],
        );
      }
      if (restantes.isEmpty) {
        await _anotarBorradoMarcas(txn, 'SELECT uid FROM marca WHERE id = ?', [
          marcaId,
        ]);
        await txn.delete('marca', where: 'id = ?', whereArgs: [marcaId]);
      } else {
        await _recomputarMarca(txn, marcaId);
      }
    });
    await cargar();
    _subirCambios();
  }

  /// Recalcula `repeticiones` (total), `reps_series` y `peso` (la carga más
  /// alta de sus series) de la marca a partir de sus series, y la deja
  /// pendiente de subir al backend.
  Future<void> _recomputarMarca(Transaction txn, int marcaId) async {
    final series = await txn.query(
      'serie',
      where: 'marca_id = ?',
      whereArgs: [marcaId],
      orderBy: 'numero ASC',
    );
    final reps = series.map((s) => s['repeticiones'] as int? ?? 0).toList();
    final datos = <String, Object?>{
      'repeticiones': reps.fold<int>(0, (a, b) => a + b),
      'reps_series': reps.join(','),
    };
    final pesos = series
        .map((s) => (s['peso'] as num?)?.toDouble())
        .whereType<double>();
    if (pesos.isNotEmpty) datos['peso'] = pesos.reduce((a, b) => a > b ? a : b);
    await txn.update('marca', datos, where: 'id = ?', whereArgs: [marcaId]);
    // Cambió la sesión: queda pendiente de subir.
    await txn.rawUpdate(
      'UPDATE marca SET pendiente = pendiente + 1 WHERE id = ?',
      [marcaId],
    );
  }

  /// Devuelve la fila de la marca/sesión de HOY del ejercicio, o null.
  Future<Map<String, Object?>?> _marcaDeHoy(
    Transaction txn,
    int ejercicioId,
  ) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day).toIso8601String();
    final fin = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
      23,
      59,
      59,
    ).toIso8601String();
    final rows = await txn.query(
      'marca',
      where: 'ejercicio_id = ? AND fecha BETWEEN ? AND ?',
      whereArgs: [ejercicioId, inicio, fin],
      orderBy: 'id DESC',
      limit: 1,
    );
    return rows.isNotEmpty ? rows.first : null;
  }

  /// Convierte "12,10,8,8" en [12, 10, 8, 8]; null/'' -> [].
  List<int> _parsearReps(String? texto) {
    if (texto == null || texto.trim().isEmpty) return const [];
    return texto
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((n) => n > 0)
        .toList();
  }

  // ------------------------------------------------- Sincronización sugeridas
  /// Sincroniza las rutinas sugeridas del backend hacia SQLite mediante un
  /// upsert por clave natural (servidor_id → día_semana → nombre de ejercicio),
  /// de modo que los ejercicios que no cambian conservan su id local y, con él,
  /// su historial de marcas (no se rompen los reportes de avance).
  ///
  /// Las rutinas sugeridas que ya no vienen del backend se eliminan localmente.
  Future<void> sincronizarSugeridas(List<Rutina> remotas) async {
    final db = await BaseDatosLocal.instancia.db;
    final ahora = DateTime.now().toIso8601String();

    await db.transaction((txn) async {
      // Rutinas admin existentes indexadas por servidor_id.
      final existentes = await txn.query(
        'rutina',
        where: 'origen = ?',
        whereArgs: ['admin'],
      );
      final porServidor = <int, int>{}; // servidor_id -> id local
      for (final r in existentes) {
        final sid = r['servidor_id'] as int?;
        if (sid != null) porServidor[sid] = r['id'] as int;
      }

      final idsRemotos = <int>{};

      for (final remota in remotas) {
        final sid = remota.servidorId;
        if (sid == null) continue;
        idsRemotos.add(sid);

        int rutinaId;
        if (porServidor.containsKey(sid)) {
          rutinaId = porServidor[sid]!;
          await txn.update(
            'rutina',
            {
              'nombre': remota.nombre,
              'descripcion': remota.descripcion,
              'personalizada': remota.personalizada ? 1 : 0,
              'fecha_sync': ahora,
            },
            where: 'id = ?',
            whereArgs: [rutinaId],
          );
        } else {
          rutinaId = await txn.insert('rutina', {
            'servidor_id': sid,
            'nombre': remota.nombre,
            'descripcion': remota.descripcion,
            'origen': 'admin',
            'personalizada': remota.personalizada ? 1 : 0,
            'fecha_sync': ahora,
          });
        }

        await _upsertDias(txn, rutinaId, remota.dias);
      }

      // Eliminar rutinas admin que ya no existen en el backend.
      for (final entry in porServidor.entries) {
        if (!idsRemotos.contains(entry.key)) {
          await txn.delete('rutina', where: 'id = ?', whereArgs: [entry.value]);
        }
      }
    });

    await cargar();
  }

  /// [propia] es true para las rutinas del propio socio que bajan del
  /// backend: en ellas `unilateral` también viene del servidor. En las del
  /// gimnasio es preferencia local y no se pisa.
  Future<void> _upsertDias(
    DatabaseExecutor txn,
    int rutinaId,
    List<DiaRutina> diasRemotos, {
    bool propia = false,
  }) async {
    final diasExistentes = await txn.query(
      'rutina_dia',
      where: 'rutina_id = ?',
      whereArgs: [rutinaId],
    );
    final porDiaSemana = <String, int>{}; // dia_semana -> id local
    for (final d in diasExistentes) {
      porDiaSemana[d['dia_semana'] as String] = d['id'] as int;
    }

    final diasVistos = <String>{};
    var orden = 0;
    for (final dia in diasRemotos) {
      diasVistos.add(dia.diaSemana);
      int diaId;
      if (porDiaSemana.containsKey(dia.diaSemana)) {
        diaId = porDiaSemana[dia.diaSemana]!;
        await txn.update(
          'rutina_dia',
          {'orden': orden},
          where: 'id = ?',
          whereArgs: [diaId],
        );
      } else {
        diaId = await txn.insert('rutina_dia', {
          'rutina_id': rutinaId,
          'dia_semana': dia.diaSemana,
          'orden': orden,
        });
      }
      orden++;
      await _upsertEjercicios(txn, diaId, dia.ejercicios, propia: propia);
    }

    // Eliminar días que ya no vienen del backend.
    for (final entry in porDiaSemana.entries) {
      if (!diasVistos.contains(entry.key)) {
        await txn.delete(
          'rutina_dia',
          where: 'id = ?',
          whereArgs: [entry.value],
        );
      }
    }
  }

  Future<void> _upsertEjercicios(
    DatabaseExecutor txn,
    int diaId,
    List<Ejercicio> ejerciciosRemotos, {
    bool propia = false,
  }) async {
    final ejExistentes = await txn.query(
      'ejercicio',
      where: 'dia_id = ?',
      whereArgs: [diaId],
    );
    final porNombre = <String, int>{}; // nombre -> id local
    for (final e in ejExistentes) {
      porNombre[e['nombre'] as String] = e['id'] as int;
    }

    final nombresVistos = <String>{};
    var orden = 0;
    for (final ej in ejerciciosRemotos) {
      nombresVistos.add(ej.nombre);
      final datos = {
        'nombre': ej.nombre,
        'series': ej.series,
        'repeticiones': ej.repeticiones,
        'observaciones': ej.observaciones,
        // El admin puede haber enlazado el ejercicio al catálogo (con imagen).
        'catalogo_id': ej.catalogoId,
        'imagen_url': ej.imagenUrl,
        'video_url': ej.videoUrl,
        'descanso_seg': ej.descansoSeg,
        if (propia) 'unilateral': ej.unilateral ? 1 : 0,
        'orden': orden,
      };
      if (porNombre.containsKey(ej.nombre)) {
        // Update en sitio: conserva el id y, por tanto, las marcas.
        await txn.update(
          'ejercicio',
          datos,
          where: 'id = ?',
          whereArgs: [porNombre[ej.nombre]],
        );
      } else {
        await txn.insert('ejercicio', {'dia_id': diaId, ...datos});
      }
      orden++;
    }

    // Eliminar ejercicios que el admin quitó (se pierden sus marcas).
    for (final entry in porNombre.entries) {
      if (!nombresVistos.contains(entry.key)) {
        await txn.delete(
          'ejercicio',
          where: 'id = ?',
          whereArgs: [entry.value],
        );
      }
    }
  }

  // --------------------------------------- Entrenamiento en el backend (socio)

  /// Devuelve el id de la rutina del ejercicio dado.
  static const _rutinaDeEjercicio =
      'SELECT d.rutina_id FROM ejercicio e JOIN rutina_dia d ON d.id = e.dia_id '
      'WHERE e.id = ?';

  /// Identificador compartido con el servidor, para que reenviar no duplique.
  String _nuevoUid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_azar.nextInt(1 << 32)}';

  /// Deja pendiente de subir la rutina propia que devuelve [consulta] (las
  /// del gimnasio no se suben).
  Future<void> _tocarRutina(
    DatabaseExecutor db,
    String consulta,
    List<Object?> args,
  ) async {
    await db.rawUpdate(
      "UPDATE rutina SET pendiente = pendiente + 1 WHERE origen = 'cliente' AND id = ($consulta)",
      args,
    );
  }

  Future<void> _anotarBorrado(
    DatabaseExecutor db,
    String tipo,
    String? uid,
  ) async {
    if (uid == null || uid.isEmpty) return;
    await db.insert('sync_borrado', {
      'tipo': tipo,
      'uid': uid,
    }, conflictAlgorithm: ConflictAlgorithm.ignore);
  }

  /// Anota como borradas en el servidor las sesiones cuyos uid devuelve
  /// [consulta] (antes de borrarlas de SQLite).
  Future<void> _anotarBorradoMarcas(
    DatabaseExecutor db,
    String consulta,
    List<Object?> args,
  ) async {
    for (final f in await db.rawQuery(consulta, args)) {
      await _anotarBorrado(db, 'sesion', f['uid'] as String?);
    }
  }

  /// Sube en segundo plano lo que se acaba de cambiar.
  void _subirCambios() => unawaited(sincronizarEntrenamiento());

  bool _sincronizando = false;
  bool _repetir = false;

  /// Sube lo pendiente (borrados, rutinas propias, sesiones con sus series) y
  /// luego trae lo que hay en el servidor, que es quien manda. Sin internet no
  /// hace nada: lo pendiente queda en SQLite y se sube en la próxima. Si ya hay
  /// una sincronización en curso, se vuelve a pasar al terminar.
  Future<void> sincronizarEntrenamiento() async {
    if (_sincronizando) {
      _repetir = true;
      return;
    }
    _sincronizando = true;
    try {
      do {
        _repetir = false;
        await _sincronizarEntrenamiento();
      } while (_repetir);
    } catch (_) {
      // Sin servidor: lo pendiente se reintenta en la próxima.
    } finally {
      _sincronizando = false;
    }
  }

  bool _exito(dynamic resp) =>
      resp is List &&
      resp.isNotEmpty &&
      resp.first is Map &&
      '${resp.first['voit_exito']}' == '1';

  Future<void> _sincronizarEntrenamiento() async {
    final prefs = await SharedPreferences.getInstance();
    final usuario = prefs.getString('idUsuario') ?? '';
    // Solo los socios tienen entrenamiento en el servidor.
    if (usuario.isEmpty || (prefs.getString('miembroId') ?? '').isEmpty) return;

    final db = await BaseDatosLocal.instancia.db;
    if (await _cambiarDueno(db, usuario)) await cargar();
    if (!await _http.hayInternet()) return;

    // 1) Borrados pendientes.
    for (final b in await db.query('sync_borrado')) {
      final resp = await _http.obtenerConDatos({
        'metodo': b['tipo'] == 'rutina' ? 'eliminar_rutina' : 'eliminar_sesion',
        'uid': b['uid'],
      }, _ruta);
      if (!_exito(resp)) return;
      await db.delete(
        'sync_borrado',
        where: 'tipo = ? AND uid = ?',
        whereArgs: [b['tipo'], b['uid']],
      );
    }

    // 2) Rutinas propias con cambios. Solo se dan por subidas si nadie las
    // tocó mientras viajaban (pendiente sigue igual).
    final rutinas = await db.query(
      'rutina',
      where: "origen = 'cliente' AND pendiente > 0 AND uid IS NOT NULL",
    );
    for (final r in rutinas) {
      final resp = await _http.obtenerConDatos({
        'metodo': 'guardar_rutina',
        'rutina': {
          'uid': r['uid'],
          'nombre': r['nombre'],
          'descripcion': r['descripcion'] ?? '',
          'dias': await _arbolRutina(db, r['id'] as int),
        },
      }, _ruta);
      if (!_exito(resp)) return;
      await db.rawUpdate(
        'UPDATE rutina SET pendiente = 0 WHERE id = ? AND pendiente = ?',
        [r['id'], r['pendiente']],
      );
    }

    // 3) Sesiones con cambios, con todas sus series.
    final formato = DateFormat('yyyy-MM-dd HH:mm:ss');
    final sesiones = await db.rawQuery(
      'SELECT m.id, m.uid, m.fecha, m.pendiente, e.nombre, e.catalogo_id, '
      'd.dia_semana, r.origen, r.servidor_id, r.uid AS rutina_uid '
      'FROM marca m '
      'JOIN ejercicio e ON e.id = m.ejercicio_id '
      'JOIN rutina_dia d ON d.id = e.dia_id '
      'JOIN rutina r ON r.id = d.rutina_id '
      'WHERE m.pendiente > 0 AND m.uid IS NOT NULL',
    );
    for (final m in sesiones) {
      final ref = _refRutina(m['origen'], m['servidor_id'], m['rutina_uid']);
      if (ref == null) continue;
      final series = await db.query(
        'serie',
        where: 'marca_id = ?',
        whereArgs: [m['id']],
        orderBy: 'numero ASC',
      );
      final resp = await _http.obtenerConDatos({
        'metodo': 'guardar_sesion',
        'sesion': {
          'uid': m['uid'],
          'fecha': formato.format(
            DateTime.tryParse(m['fecha'] as String? ?? '') ?? DateTime.now(),
          ),
          'rutina_origen': m['origen'],
          'rutina_ref': ref,
          'dia_semana': m['dia_semana'],
          'ejercicio_nombre': m['nombre'],
          'catalogo_id': m['catalogo_id'],
          'series': [
            for (final s in series)
              {
                'numero': s['numero'],
                'repeticiones': s['repeticiones'],
                'peso': s['peso'],
                'reps_izq': s['reps_izq'],
                'reps_der': s['reps_der'],
              },
          ],
        },
      }, _ruta);
      if (!_exito(resp)) return;
      await db.rawUpdate(
        'UPDATE marca SET pendiente = 0 WHERE id = ? AND pendiente = ?',
        [m['id'], m['pendiente']],
      );
    }

    // 4) Lo del servidor manda (p. ej. lo registrado desde otro teléfono).
    final resp = await _http.obtenerConDatos({'metodo': 'listar'}, _ruta);
    if (resp is! Map || resp['resultado'] != true) return;
    await db.transaction((txn) async {
      await _aplicarRutinasRemotas(txn, resp['rutinas']);
      await _aplicarSesionesRemotas(txn, resp['sesiones']);
    });
    await cargar();
  }

  /// Si el entrenamiento guardado en el teléfono es de otro usuario (teléfono
  /// compartido), lo quita: el nuevo usuario baja el suyo del servidor.
  /// Devuelve true si borró algo. Lo que no tiene dueño (versiones anteriores
  /// de la app) se queda con el usuario actual.
  Future<bool> _cambiarDueno(Database db, String usuario) async {
    final filas = await db.query(
      'meta',
      where: 'clave = ?',
      whereArgs: ['dueno_entrenamiento'],
    );
    final dueno = filas.isEmpty ? null : filas.first['valor'] as String?;
    if (dueno == usuario) return false;
    await db.transaction((txn) async {
      if (dueno != null) {
        await txn.delete('rutina', where: "origen = 'cliente'");
        await txn.delete('marca');
        await txn.delete('sync_borrado');
      }
      await txn.insert('meta', {
        'clave': 'dueno_entrenamiento',
        'valor': usuario,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    });
    return dueno != null;
  }

  /// Cómo identifica el servidor la rutina de una sesión: el id del backend
  /// para las del gimnasio, el uid para las propias.
  String? _refRutina(Object? origen, Object? servidorId, Object? uid) {
    final ref = origen == 'admin' ? servidorId : uid;
    final texto = ref?.toString() ?? '';
    return texto.isEmpty ? null : texto;
  }

  /// Días y ejercicios de una rutina, en el formato que guarda el servidor.
  Future<List<Map<String, Object?>>> _arbolRutina(
    DatabaseExecutor db,
    int rutinaId,
  ) async {
    final dias = await db.query(
      'rutina_dia',
      where: 'rutina_id = ?',
      whereArgs: [rutinaId],
      orderBy: 'orden ASC, id ASC',
    );
    return [
      for (final d in dias)
        {
          'dia_semana': d['dia_semana'],
          'ejercicios': [
            for (final e in await db.query(
              'ejercicio',
              where: 'dia_id = ?',
              whereArgs: [d['id']],
              orderBy: 'orden ASC, id ASC',
            ))
              {
                'nombre': e['nombre'],
                'series': e['series'],
                'repeticiones': e['repeticiones'],
                'observaciones': e['observaciones'],
                'catalogo_id': e['catalogo_id'],
                'imagen_url': e['imagen_url'],
                'video_url': e['video_url'],
                'descanso_seg': e['descanso_seg'],
                'unilateral': e['unilateral'],
              },
          ],
        },
    ];
  }

  int? _entero(Object? v) => v is int ? v : int.tryParse('${v ?? ''}');

  String? _texto(Object? v) {
    final t = v?.toString().trim() ?? '';
    return t.isEmpty ? null : t;
  }

  List<Map> _lista(Object? v) => v is List ? v.whereType<Map>().toList() : [];

  /// Rutinas propias del servidor -> SQLite. No pisa las que tienen cambios
  /// sin subir ni revive las borradas aquí; las que ya no están en el
  /// servidor (borradas desde otro teléfono) se quitan.
  Future<void> _aplicarRutinasRemotas(Transaction txn, Object? remotas) async {
    if (remotas is! List) return;
    final locales = {
      for (final r in await txn.query(
        'rutina',
        columns: ['id', 'uid', 'pendiente'],
        where: "origen = 'cliente' AND uid IS NOT NULL",
      ))
        r['uid'] as String: r,
    };
    final borradas = await _uidsBorrados(txn, 'rutina');
    final enServidor = <String>{};

    for (final r in _lista(remotas)) {
      final uid = _texto(r['uid']);
      if (uid == null) continue;
      enServidor.add(uid);
      final local = locales[uid];
      if (borradas.contains(uid) || ((local?['pendiente'] as int?) ?? 0) > 0) {
        continue;
      }
      final datos = {
        'nombre': _texto(r['nombre']) ?? '',
        'descripcion': r['descripcion']?.toString() ?? '',
      };
      final int id;
      if (local == null) {
        id = await txn.insert('rutina', {
          ...datos,
          'origen': 'cliente',
          'uid': uid,
          'pendiente': 0,
        });
      } else {
        id = local['id'] as int;
        await txn.update('rutina', datos, where: 'id = ?', whereArgs: [id]);
      }
      final dias = [
        for (final d in _lista(r['dias']))
          DiaRutina(
            id: 0,
            diaSemana: d['dia_semana']?.toString() ?? '',
            ejercicios: [
              for (final e in _lista(d['ejercicios']))
                Ejercicio(
                  id: 0,
                  nombre: e['nombre']?.toString() ?? '',
                  series: _entero(e['series']) ?? 0,
                  repeticiones: _entero(e['repeticiones']) ?? 0,
                  observaciones: _texto(e['observaciones']),
                  catalogoId: _entero(e['catalogo_id']),
                  imagenUrl: _texto(e['imagen_url']),
                  videoUrl: _texto(e['video_url']),
                  descansoSeg: _entero(e['descanso_seg']),
                  unilateral: _entero(e['unilateral']) == 1,
                ),
            ],
          ),
      ];
      await _upsertDias(txn, id, dias, propia: true);
    }

    for (final local in locales.values) {
      if ((local['pendiente'] as int? ?? 0) == 0 &&
          !enServidor.contains(local['uid'])) {
        await txn.delete('rutina', where: 'id = ?', whereArgs: [local['id']]);
      }
    }
  }

  /// Sesiones del servidor -> SQLite, enganchadas a su ejercicio por la misma
  /// clave natural que usa la sincronización de rutinas (rutina, día,
  /// nombre). Las de un ejercicio que ya no existe en el teléfono se quedan
  /// solo en el servidor.
  Future<void> _aplicarSesionesRemotas(Transaction txn, Object? remotas) async {
    if (remotas is! List) return;

    final ejercicios = <String, int>{};
    for (final e in await txn.rawQuery(
      'SELECT e.id, e.nombre, d.dia_semana, r.origen, r.servidor_id, r.uid '
      'FROM ejercicio e '
      'JOIN rutina_dia d ON d.id = e.dia_id '
      'JOIN rutina r ON r.id = d.rutina_id '
      'ORDER BY e.id ASC',
    )) {
      final ref = _refRutina(e['origen'], e['servidor_id'], e['uid']);
      if (ref == null) continue;
      ejercicios.putIfAbsent(
        '${e['origen']}|$ref|${e['dia_semana']}|${e['nombre']}',
        () => e['id'] as int,
      );
    }

    final locales = {
      for (final m in await txn.query(
        'marca',
        columns: ['id', 'uid', 'pendiente'],
        where: 'uid IS NOT NULL',
      ))
        m['uid'] as String: m,
    };
    final borradas = await _uidsBorrados(txn, 'sesion');
    final enServidor = <String>{};

    for (final s in _lista(remotas)) {
      final uid = _texto(s['uid']);
      final fecha = DateTime.tryParse('${s['fecha']}');
      if (uid == null || fecha == null) continue;
      enServidor.add(uid);
      final local = locales[uid];
      if (borradas.contains(uid) || ((local?['pendiente'] as int?) ?? 0) > 0) {
        continue;
      }
      final series = _lista(s['series']);
      final reps = [for (final x in series) _entero(x['repeticiones']) ?? 0];
      final datos = {
        'fecha': fecha.toIso8601String(),
        'peso': double.tryParse('${s['peso']}') ?? 0,
        'repeticiones': reps.fold<int>(0, (a, b) => a + b),
        'reps_series': reps.join(','),
        'pendiente': 0,
      };

      final int marcaId;
      if (local == null) {
        final ejercicioId =
            ejercicios['${s['rutina_origen']}|${s['rutina_ref']}|'
                '${s['dia_semana']}|${s['ejercicio_nombre']}'];
        if (ejercicioId == null) continue;
        marcaId = await txn.insert('marca', {
          ...datos,
          'ejercicio_id': ejercicioId,
          'uid': uid,
        });
      } else {
        marcaId = local['id'] as int;
        await txn.update('marca', datos, where: 'id = ?', whereArgs: [marcaId]);
        await txn.delete('serie', where: 'marca_id = ?', whereArgs: [marcaId]);
      }
      for (final x in series) {
        await txn.insert('serie', {
          'marca_id': marcaId,
          'numero': _entero(x['numero']) ?? 0,
          'repeticiones': _entero(x['repeticiones']) ?? 0,
          'peso': double.tryParse('${x['peso']}'),
          'reps_izq': _entero(x['reps_izq']),
          'reps_der': _entero(x['reps_der']),
        });
      }
    }

    for (final local in locales.values) {
      if ((local['pendiente'] as int? ?? 0) == 0 &&
          !enServidor.contains(local['uid'])) {
        await txn.delete('marca', where: 'id = ?', whereArgs: [local['id']]);
      }
    }
  }

  Future<Set<String>> _uidsBorrados(DatabaseExecutor db, String tipo) async => {
    for (final b in await db.query(
      'sync_borrado',
      columns: ['uid'],
      where: 'tipo = ?',
      whereArgs: [tipo],
    ))
      b['uid'] as String,
  };
}
