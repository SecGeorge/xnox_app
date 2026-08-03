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
  static const _version = 10;

  /// Código de la empresa de desarrollo que se sembraba mientras se trabajaba
  /// contra el servidor local. Ya no se siembra: la migración v5 la borra.
  static const String _codigoEmpresaDesarrollo = 'local';

  /// Gimnasios ya conocidos, con su URL exacta. Se siembran inactivos: no se
  /// eligen de una lista, solo sirven para que al escribir uno de estos códigos
  /// la app use la URL guardada en vez de armarla desde el subdominio. Un
  /// código que no esté aquí se guarda solo cuando el usuario lo escribe.
  /// `codigo_backend` es el código que ese servidor reconoce en las peticiones
  /// (su constante `CODIGO_GIMNASIO`). Cada gimnasio se configura con el mismo
  /// código que escribe el usuario, así que se siembra igual; el arranque lo
  /// confirma contra el servidor y corrige el valor si allí es otro.
  static const List<Map<String, String>> codigosConocidos = [
    {
      'codigo': 'PASSIONFIT',
      'nombre': 'Passion Fit',
      'ruta_global': 'https://passionfit.xnoxsoft.es/api/',
      'codigo_backend': 'PASSIONFIT',
    },
    {
      'codigo': 'OXYGEENFIT',
      'nombre': 'Oxygeen Fit',
      'ruta_global': 'https://oxygeenfit.xnoxsoft.es/api/',
      'codigo_backend': 'OXYGEENFIT',
    },
    {
      'codigo': 'VICTORGYM',
      'nombre': 'Victor Gym',
      'ruta_global': 'https://victorgym.xnoxsoft.es/api/',
      'codigo_backend': 'VICTORGYM',
    },
    {
      'codigo': 'XNONX',
      'nombre': 'Xnonx',
      'ruta_global': 'https://xnonx.xnoxsoft.es/api/',
      'codigo_backend': 'XNONX',
    },
    {
      'codigo': 'LOCAL',
      'nombre': 'Sistema Gimnasio VF',
      'ruta_global': 'http://192.168.1.193/sistema_gimnasio_vf/api/',
      'codigo_backend': 'LOCAL',
    }
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
      // v4: empresa (multi-tenant). Guarda código, nombre y ruta base de la
      // API; la app apunta a la empresa marcada como activa.
      await _crearTablaEmpresa(db);
    }
    if (desde < 5) {
      // v5: el arranque ya no lista empresas, el usuario escribe el código de
      // su gimnasio. Se borra la empresa de desarrollo (quedaba activa y se
      // saltaba esa pantalla) y las del catálogo que nadie llegó a elegir.
      await db.delete(
        'empresa',
        where: 'codigo = ? OR activa = 0',
        whereArgs: [_codigoEmpresaDesarrollo],
      );
    }
    if (desde < 6) {
      // v6: los gimnasios conocidos viven en la tabla, con su URL exacta, para
      // consultarlos cuando se escribe el código.
      await _sembrarCodigosConocidos(db);
    }
    if (desde < 7) {
      // v7: el código que el servidor reconoce en sus peticiones (su constante
      // CODIGO_GIMNASIO) no es el que escribe el usuario, así que se guarda
      // aparte. Sin esto el registro de clientes tenía que volver a pedirlo.
      if (!await _existeColumna(db, 'empresa', 'codigo_backend')) {
        await db.execute('ALTER TABLE empresa ADD COLUMN codigo_backend TEXT');
      }
      await db.update(
        'empresa',
        {'codigo_backend': _codigoBackendPorDefecto},
        where: 'codigo_backend IS NULL',
      );
    }
    if (desde < 8) {
      // v8: el administrador puede armar una rutina para UN cliente. Sigue
      // siendo 'admin' (solo lectura), pero se marca para mostrarla aparte de
      // las generales de la sucursal.
      if (!await _existeColumna(db, 'rutina', 'personalizada')) {
        await db.execute(
            'ALTER TABLE rutina ADD COLUMN personalizada INTEGER NOT NULL DEFAULT 0');
      }
    }
    if (desde < 9) {
      // v9: realinea `codigo_backend` con el valor sembrado. Un código que el
      // servidor no reconoce deja el registro de clientes sin sucursales, y
      // hasta ahora ese valor equivocado se quedaba guardado para siempre. Si
      // el gimnasio usa otro, el propio registro vuelve a resolverlo y lo pisa.
      for (final gimnasio in codigosConocidos) {
        await db.update(
          'empresa',
          {'codigo_backend': gimnasio['codigo_backend']},
          where: 'codigo = ? AND (codigo_backend IS NULL OR codigo_backend != ?)',
          whereArgs: [gimnasio['codigo'], gimnasio['codigo_backend']],
        );
      }
    }
    if (desde < 10) {
      // v10: el ejercicio puede venir del catálogo del gimnasio, que trae
      // imágenes de referencia. Se guarda el id del catálogo y la URL de la
      // portada para verla sin conexión a la lista de sugerencias.
      if (!await _existeColumna(db, 'ejercicio', 'catalogo_id')) {
        await db.execute('ALTER TABLE ejercicio ADD COLUMN catalogo_id INTEGER');
      }
      if (!await _existeColumna(db, 'ejercicio', 'imagen_url')) {
        await db.execute('ALTER TABLE ejercicio ADD COLUMN imagen_url TEXT');
      }
    }
  }

  /// Valor de partida para las filas que ya existían: mientras un gimnasio no
  /// esté configurado con su propio código, su servidor sigue reconociendo este.
  /// El arranque lo corrige en cuanto el servidor acepta el código real.
  static const String _codigoBackendPorDefecto = 'PASSIONFIT';

  Future<bool> _existeColumna(Database db, String tabla, String columna) async {
    final info = await db.rawQuery('PRAGMA table_info($tabla)');
    return info.any((c) => c['name'] == columna);
  }

  /// Inserta los gimnasios conocidos sin tocar los que ya estén (INSERT OR
  /// IGNORE por `codigo`), así no se pisa la empresa activa ni su URL.
  Future<void> _sembrarCodigosConocidos(Database db) async {
    final batch = db.batch();
    for (final gimnasio in codigosConocidos) {
      batch.insert(
        'empresa',
        {
          'codigo': gimnasio['codigo'],
          'nombre': gimnasio['nombre'],
          'ruta_global': gimnasio['ruta_global'],
          'codigo_backend': gimnasio['codigo_backend'],
          'activa': 0,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> _crearTablaEmpresa(Database db) async {
    await db.execute('''
      CREATE TABLE empresa (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        codigo TEXT NOT NULL UNIQUE,
        nombre TEXT NOT NULL,
        ruta_global TEXT NOT NULL,
        codigo_backend TEXT,
        activa INTEGER NOT NULL DEFAULT 0
      )
    ''');
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
    // personalizada: 1 si el administrador armó esa rutina 'admin' para este
    //                cliente en concreto (no la ven los demás).
    await db.execute('''
      CREATE TABLE rutina (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        servidor_id INTEGER,
        nombre TEXT NOT NULL,
        descripcion TEXT,
        origen TEXT NOT NULL,
        personalizada INTEGER NOT NULL DEFAULT 0,
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
        catalogo_id INTEGER,
        imagen_url TEXT,
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

    // Empresa (multi-tenant): trae los gimnasios conocidos y se completa con el
    // código que el usuario escribe en el primer arranque.
    await _crearTablaEmpresa(db);
    await _sembrarCodigosConocidos(db);

    await db.execute('CREATE INDEX idx_rutina_dia_rutina ON rutina_dia (rutina_id)');
    await db.execute('CREATE INDEX idx_ejercicio_dia ON ejercicio (dia_id)');
    await db.execute('CREATE INDEX idx_marca_ejercicio ON marca (ejercicio_id)');
  }
}
