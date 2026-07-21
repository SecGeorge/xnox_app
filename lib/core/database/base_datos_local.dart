import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

/// Acceso a la base de datos local SQLite (offline) de la app.
///
/// Aquí viven las rutinas del cliente (CRUD local) y la copia sincronizada de
/// las rutinas sugeridas del administrador, junto con el historial de marcas
/// que alimenta los reportes de avance.
class BaseDatosLocal {
  BaseDatosLocal._interno();
  static final BaseDatosLocal instancia = BaseDatosLocal._interno();

  static const _nombreArchivo = 'xnox_app.db';
  static const _version = 4;

  /// Catálogo de empresas (tenants) que se siembra al crear/actualizar la BD.
  /// Cada una define la ruta base de la API a la que apunta la app. La empresa
  /// activa la elige el usuario en la pantalla de selección del primer arranque.
  static const List<Map<String, String>> catalogoEmpresas = [
    {
      'codigo': 'oxygeenfit',
      'nombre': 'Oxygeen Fit',
      'ruta_global': 'https://oxygeenfit.xnoxsoft.es/api/',
    },
    {
      'codigo': 'xnonx',
      'nombre': 'Xnonx',
      'ruta_global': 'https://xnonx.xnoxsoft.es/api/',
    },
  ];

  Database? _db;

  Future<Database> get db async {
    _db ??= await _abrir();
    return _db!;
  }

  Future<Database> _abrir() async {
    final ruta = p.join(await getDatabasesPath(), _nombreArchivo);
    return openDatabase(
      ruta,
      version: _version,
      onConfigure: (db) async {
        // Necesario para que ON DELETE CASCADE funcione.
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _crear,
      onUpgrade: _actualizar,
    );
  }

  /// Migraciones incrementales sin perder datos.
  Future<void> _actualizar(Database db, int desde, int hasta) async {
    if (desde < 2) {
      // v2: desglose de repeticiones por serie (p. ej. "12,10,8,8").
      await db.execute('ALTER TABLE marca ADD COLUMN reps_series TEXT');
    }
    if (desde < 3) {
      // v3: las series se normalizan en su propia tabla, agrupadas por sesión
      // (marca_id) e indexadas para lecturas rápidas.
      await _crearTablaSerie(db);
      // Migrar el texto "12,10,8,8" de cada marca a filas de la tabla serie.
      final marcas = await db.query('marca', columns: ['id', 'reps_series']);
      final batch = db.batch();
      for (final m in marcas) {
        final reps = _split(m['reps_series'] as String?);
        for (var i = 0; i < reps.length; i++) {
          batch.insert('serie', {
            'marca_id': m['id'],
            'numero': i + 1,
            'repeticiones': reps[i],
          });
        }
      }
      await batch.commit(noResult: true);
    }
    if (desde < 4) {
      // v4: catálogo de empresas (multi-tenant). Guarda código, nombre y ruta
      // base de la API; la app apunta a la empresa marcada como activa.
      await _crearTablaEmpresa(db);
      await _sembrarEmpresas(db);
    }
  }

  Future<void> _crearTablaEmpresa(Database db) async {
    await db.execute('''
      CREATE TABLE empresa (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo TEXT NOT NULL UNIQUE,
        nombre TEXT NOT NULL,
        ruta_global TEXT NOT NULL,
        activa INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  /// Inserta el catálogo inicial de empresas. Ninguna queda activa: eso obliga
  /// a pasar por la pantalla de selección en el primer arranque. Usa INSERT OR
  /// IGNORE para no duplicar si el código ya existe.
  Future<void> _sembrarEmpresas(Database db) async {
    final batch = db.batch();
    for (final e in catalogoEmpresas) {
      batch.insert(
        'empresa',
        {
          'codigo': e['codigo'],
          'nombre': e['nombre'],
          'ruta_global': e['ruta_global'],
          'activa': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _crearTablaSerie(Database db) async {
    await db.execute('''
      CREATE TABLE serie (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        marca_id INTEGER NOT NULL,
        numero INTEGER NOT NULL,
        repeticiones INTEGER NOT NULL,
        FOREIGN KEY (marca_id) REFERENCES marca (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_serie_marca ON serie (marca_id)');
  }

  /// "12,10,8,8" -> [12, 10, 8, 8] (ignora vacíos/no numéricos).
  List<int> _split(String? texto) {
    if (texto == null || texto.trim().isEmpty) return const [];
    return texto
        .split(',')
        .map((s) => int.tryParse(s.trim()) ?? 0)
        .where((n) => n > 0)
        .toList();
  }

  Future<void> _crear(Database db, int version) async {
    // origen: 'admin' = rutina sugerida (solo lectura, viene del backend)
    //         'cliente' = rutina propia del cliente (CRUD local)
    // servidor_id: id de la rutina en el backend (solo rutinas 'admin').
    await db.execute('''
      CREATE TABLE rutina (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        servidor_id INTEGER,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        origen TEXT NOT NULL,
        fecha_sync TEXT
      )
    ''');

    await db.execute('''
      CREATE TABLE rutina_dia (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        rutina_id INTEGER NOT NULL,
        dia_semana TEXT NOT NULL,
        orden INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (rutina_id) REFERENCES rutina (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE ejercicio (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        dia_id INTEGER NOT NULL,
        nombre TEXT NOT NULL,
        series INTEGER NOT NULL DEFAULT 0,
        repeticiones INTEGER NOT NULL DEFAULT 0,
        observaciones TEXT,
        orden INTEGER NOT NULL DEFAULT 0,
        FOREIGN KEY (dia_id) REFERENCES rutina_dia (id) ON DELETE CASCADE
      )
    ''');

    // Las marcas son el historial de progreso (peso/reps por fecha). Alimentan
    // los reportes de avance y deben sobrevivir a las sincronizaciones.
    await db.execute('''
      CREATE TABLE marca (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        ejercicio_id INTEGER NOT NULL,
        fecha TEXT NOT NULL,
        peso REAL NOT NULL,
        repeticiones INTEGER NOT NULL,
        reps_series TEXT,
        FOREIGN KEY (ejercicio_id) REFERENCES ejercicio (id) ON DELETE CASCADE
      )
    ''');

    // Series de cada marca/sesión, normalizadas y agrupadas por marca_id.
    await _crearTablaSerie(db);

    // Catálogo de empresas (multi-tenant) y su siembra inicial.
    await _crearTablaEmpresa(db);
    await _sembrarEmpresas(db);

    await db.execute('CREATE INDEX idx_rutina_dia_rutina ON rutina_dia (rutina_id)');
    await db.execute('CREATE INDEX idx_ejercicio_dia ON ejercicio (dia_id)');
    await db.execute('CREATE INDEX idx_marca_ejercicio ON marca (ejercicio_id)');
  }
}
