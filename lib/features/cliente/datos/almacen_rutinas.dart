import 'package:sqflite/sqflite.dart';
import 'package:xnox_app/core/database/base_datos_local.dart';
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
class AlmacenRutinas {
  AlmacenRutinas._interno();
  static final AlmacenRutinas instancia = AlmacenRutinas._interno();

  List<Rutina> _rutinas = [];
  bool _cargado = false;

  // ----------------------------------------------------------------- Lecturas
  List<Rutina> get rutinas => List.unmodifiable(_rutinas);

  /// Rutinas sugeridas del administrador (solo lectura).
  List<Rutina> get rutinasSugeridas =>
      _rutinas.where((r) => r.origen == OrigenRutina.admin).toList();

  /// Rutinas propias del cliente (CRUD local).
  List<Rutina> get rutinasCliente =>
      _rutinas.where((r) => r.origen == OrigenRutina.cliente).toList();

  /// Todos los ejercicios de todas las rutinas (para el reporte de avance).
  List<Ejercicio> get todosLosEjercicios =>
      [for (final r in _rutinas) ...r.ejercicios];

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
    final serieRows =
        await db.query('serie', orderBy: 'marca_id ASC, numero ASC');

    // Series agrupadas por sesión (marca_id) -> [12, 10, 8, 8].
    final seriesPorMarca = <int, List<int>>{};
    for (final s in serieRows) {
      final marcaId = s['marca_id'] as int;
      (seriesPorMarca[marcaId] ??= []).add(s['repeticiones'] as int? ?? 0);
    }

    // Marcas agrupadas por ejercicio.
    final marcasPorEj = <int, List<Marca>>{};
    for (final m in marcaRows) {
      final ejId = m['ejercicio_id'] as int;
      final marcaId = m['id'] as int;
      // Series desde la tabla normalizada; fallback al texto legado si faltara.
      final reps = seriesPorMarca[marcaId] ??
          _parsearReps(m['reps_series'] as String?);
      marcasPorEj.putIfAbsent(ejId, () => []).add(Marca(
            id: marcaId,
            fecha: DateTime.tryParse(m['fecha'] as String? ?? '') ?? DateTime.now(),
            peso: (m['peso'] as num?)?.toDouble() ?? 0,
            repeticiones: m['repeticiones'] as int? ?? 0,
            repsPorSerie: reps,
          ));
    }

    // Ejercicios agrupados por día.
    final ejPorDia = <int, List<Ejercicio>>{};
    for (final e in ejRows) {
      final id = e['id'] as int;
      final diaId = e['dia_id'] as int;
      ejPorDia.putIfAbsent(diaId, () => []).add(Ejercicio(
            id: id,
            nombre: e['nombre'] as String? ?? '',
            series: e['series'] as int? ?? 0,
            repeticiones: e['repeticiones'] as int? ?? 0,
            observaciones: e['observaciones'] as String?,
            marcas: marcasPorEj[id] ?? [],
          ));
    }

    // Días agrupados por rutina.
    final diasPorRutina = <int, List<DiaRutina>>{};
    for (final d in diasRows) {
      final id = d['id'] as int;
      final rutinaId = d['rutina_id'] as int;
      diasPorRutina.putIfAbsent(rutinaId, () => []).add(DiaRutina(
            id: id,
            diaSemana: d['dia_semana'] as String? ?? '',
            ejercicios: ejPorDia[id] ?? [],
          ));
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
    });
    await cargar();
    return id;
  }

  Future<void> editarRutina(int id, String nombre, String descripcion) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.update(
      'rutina',
      {'nombre': nombre, 'descripcion': descripcion},
      where: 'id = ? AND origen = ?',
      whereArgs: [id, 'cliente'],
    );
    await cargar();
  }

  /// Elimina una rutina del cliente (con sus días, ejercicios y marcas).
  Future<void> eliminarRutina(int id) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.delete(
      'rutina',
      where: 'id = ? AND origen = ?',
      whereArgs: [id, 'cliente'],
    );
    await cargar();
  }

  Future<int> agregarDia(int rutinaId, String diaSemana) async {
    final db = await BaseDatosLocal.instancia.db;
    final orden = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM rutina_dia WHERE rutina_id = ?', [rutinaId])) ??
        0;
    final id = await db.insert('rutina_dia', {
      'rutina_id': rutinaId,
      'dia_semana': diaSemana,
      'orden': orden,
    });
    await cargar();
    return id;
  }

  Future<void> eliminarDia(int diaId) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.delete('rutina_dia', where: 'id = ?', whereArgs: [diaId]);
    await cargar();
  }

  Future<void> agregarEjercicio(
    int diaId,
    String nombre,
    int series,
    int repeticiones, {
    String? observaciones,
  }) async {
    final db = await BaseDatosLocal.instancia.db;
    final orden = Sqflite.firstIntValue(await db.rawQuery(
            'SELECT COUNT(*) FROM ejercicio WHERE dia_id = ?', [diaId])) ??
        0;
    await db.insert('ejercicio', {
      'dia_id': diaId,
      'nombre': nombre,
      'series': series,
      'repeticiones': repeticiones,
      'observaciones': observaciones,
      'orden': orden,
    });
    await cargar();
  }

  Future<void> eliminarEjercicio(int ejercicioId) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.delete('ejercicio', where: 'id = ?', whereArgs: [ejercicioId]);
    await cargar();
  }

  /// Registra una marca (peso + reps por serie) en un ejercicio. Se permite en
  /// cualquier ejercicio —incluidas las rutinas sugeridas— porque es el
  /// seguimiento del progreso del cliente que alimenta los reportes.
  ///
  /// [repsPorSerie] son las repeticiones hechas en cada serie. En
  /// `repeticiones` se guarda el total (suma) para no romper los reportes.
  Future<void> agregarMarca(
      int ejercicioId, double peso, List<int> repsPorSerie) async {
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
      });
      final batch = txn.batch();
      for (var i = 0; i < repsPorSerie.length; i++) {
        batch.insert('serie', {
          'marca_id': marcaId,
          'numero': i + 1,
          'repeticiones': repsPorSerie[i],
        });
      }
      await batch.commit(noResult: true);
    });
    await cargar();
  }

  // ----------------------------------------- Registro serie por serie (hoy)

  /// Agrega UNA serie a la sesión de HOY del ejercicio. Si aún no hay sesión
  /// de hoy, la crea. Devuelve el id de la sesión (marca) para poder editarla.
  Future<int> agregarSerie(int ejercicioId, double peso, int reps) async {
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
        });
      } else {
        marcaId = marcaHoy['id'] as int;
      }
      final cuantas = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM serie WHERE marca_id = ?', [marcaId])) ??
          0;
      await txn.insert('serie', {
        'marca_id': marcaId,
        'numero': cuantas + 1,
        'repeticiones': reps,
      });
      await _recomputarMarca(txn, marcaId, peso);
    });
    await cargar();
    return marcaId;
  }

  /// Edita las repeticiones de una serie puntual de una sesión.
  Future<void> editarSerie(int marcaId, int numero, int reps) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await txn.update('serie', {'repeticiones': reps},
          where: 'marca_id = ? AND numero = ?', whereArgs: [marcaId, numero]);
      await _recomputarMarca(txn, marcaId, null);
    });
    await cargar();
  }

  /// Actualiza el peso de trabajo de la sesión.
  Future<void> editarPesoSesion(int marcaId, double peso) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.update('marca', {'peso': peso},
        where: 'id = ?', whereArgs: [marcaId]);
    await cargar();
  }

  /// Elimina una serie de la sesión, renumera las restantes y recalcula los
  /// totales. Si la sesión se queda sin series, elimina la sesión completa.
  Future<void> eliminarSerie(int marcaId, int numero) async {
    final db = await BaseDatosLocal.instancia.db;
    await db.transaction((txn) async {
      await txn.delete('serie',
          where: 'marca_id = ? AND numero = ?', whereArgs: [marcaId, numero]);
      final restantes = await txn.query('serie',
          where: 'marca_id = ?', whereArgs: [marcaId], orderBy: 'numero ASC');
      // Renumerar 1..N para mantener la secuencia.
      for (var i = 0; i < restantes.length; i++) {
        await txn.update('serie', {'numero': i + 1},
            where: 'id = ?', whereArgs: [restantes[i]['id']]);
      }
      if (restantes.isEmpty) {
        await txn.delete('marca', where: 'id = ?', whereArgs: [marcaId]);
      } else {
        await _recomputarMarca(txn, marcaId, null);
      }
    });
    await cargar();
  }

  /// Recalcula `repeticiones` (total) y `reps_series` de la marca a partir de
  /// sus series. Si [peso] no es null, también actualiza el peso de la sesión.
  Future<void> _recomputarMarca(Transaction txn, int marcaId, double? peso) async {
    final series = await txn.query('serie',
        where: 'marca_id = ?', whereArgs: [marcaId], orderBy: 'numero ASC');
    final reps = series.map((s) => s['repeticiones'] as int? ?? 0).toList();
    final datos = <String, Object?>{
      'repeticiones': reps.fold<int>(0, (a, b) => a + b),
      'reps_series': reps.join(','),
    };
    if (peso != null) datos['peso'] = peso;
    await txn.update('marca', datos, where: 'id = ?', whereArgs: [marcaId]);
  }

  /// Devuelve la fila de la marca/sesión de HOY del ejercicio, o null.
  Future<Map<String, Object?>?> _marcaDeHoy(
      Transaction txn, int ejercicioId) async {
    final hoy = DateTime.now();
    final inicio = DateTime(hoy.year, hoy.month, hoy.day).toIso8601String();
    final fin =
        DateTime(hoy.year, hoy.month, hoy.day, 23, 59, 59).toIso8601String();
    final rows = await txn.query('marca',
        where: 'ejercicio_id = ? AND fecha BETWEEN ? AND ?',
        whereArgs: [ejercicioId, inicio, fin],
        orderBy: 'id DESC',
        limit: 1);
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

  Future<void> _upsertDias(
    DatabaseExecutor txn,
    int rutinaId,
    List<DiaRutina> diasRemotos,
  ) async {
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
        await txn.update('rutina_dia', {'orden': orden},
            where: 'id = ?', whereArgs: [diaId]);
      } else {
        diaId = await txn.insert('rutina_dia', {
          'rutina_id': rutinaId,
          'dia_semana': dia.diaSemana,
          'orden': orden,
        });
      }
      orden++;
      await _upsertEjercicios(txn, diaId, dia.ejercicios);
    }

    // Eliminar días que ya no vienen del backend.
    for (final entry in porDiaSemana.entries) {
      if (!diasVistos.contains(entry.key)) {
        await txn.delete('rutina_dia', where: 'id = ?', whereArgs: [entry.value]);
      }
    }
  }

  Future<void> _upsertEjercicios(
    DatabaseExecutor txn,
    int diaId,
    List<Ejercicio> ejerciciosRemotos,
  ) async {
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
        'orden': orden,
      };
      if (porNombre.containsKey(ej.nombre)) {
        // Update en sitio: conserva el id y, por tanto, las marcas.
        await txn.update('ejercicio', datos,
            where: 'id = ?', whereArgs: [porNombre[ej.nombre]]);
      } else {
        await txn.insert('ejercicio', {'dia_id': diaId, ...datos});
      }
      orden++;
    }

    // Eliminar ejercicios que el admin quitó (se pierden sus marcas).
    for (final entry in porNombre.entries) {
      if (!nombresVistos.contains(entry.key)) {
        await txn.delete('ejercicio', where: 'id = ?', whereArgs: [entry.value]);
      }
    }
  }
}
