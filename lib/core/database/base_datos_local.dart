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
  static const _version = 2;

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

    await db.execute('CREATE INDEX idx_rutina_dia_rutina ON rutina_dia (rutina_id)');
    await db.execute('CREATE INDEX idx_ejercicio_dia ON ejercicio (dia_id)');
    await db.execute('CREATE INDEX idx_marca_ejercicio ON marca (ejercicio_id)');
  }
}
