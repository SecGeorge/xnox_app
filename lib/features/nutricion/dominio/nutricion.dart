import 'package:flutter/material.dart';

/// Nutrición del socio: modelos que llegan de `nutricion.php`.
///
/// Los nutrientes usan las mismas claves que la tabla `nutricion_nutriente`
/// del backend (kcal, proteina, carbohidrato, azucar, grasa, grasa_saturada,
/// fibra, sodio); el sodio va en mg y el resto en g, salvo las kcal.

double _num(dynamic v) => double.tryParse('${v ?? ''}') ?? 0;
double? _numONull(dynamic v) =>
    v == null || '$v'.isEmpty ? null : double.tryParse('$v');
int? _entONull(dynamic v) => v == null ? null : int.tryParse('$v');

/// Un nutriente: clave del backend, nombre y unidad.
class Nutriente {
  final String clave;
  final String nombre;
  final String corto;
  final String unidad;

  const Nutriente(this.clave, this.nombre, this.corto, this.unidad);

  static const kcal = Nutriente('kcal', 'Calorías', 'kcal', 'kcal');
  static const proteina = Nutriente('proteina', 'Proteínas', 'Prot.', 'g');
  static const carbohidrato = Nutriente(
    'carbohidrato',
    'Carbohidratos',
    'Carb.',
    'g',
  );
  static const azucar = Nutriente('azucar', 'Azúcares', 'Azúc.', 'g');
  static const grasa = Nutriente('grasa', 'Grasas', 'Grasa', 'g');
  static const grasaSaturada = Nutriente(
    'grasa_saturada',
    'Grasas saturadas',
    'G. sat.',
    'g',
  );
  static const fibra = Nutriente('fibra', 'Fibra', 'Fibra', 'g');
  static const sodio = Nutriente('sodio', 'Sodio', 'Sodio', 'mg');

  static const todos = [
    kcal,
    proteina,
    carbohidrato,
    azucar,
    grasa,
    grasaSaturada,
    fibra,
    sodio,
  ];

  static Nutriente de(String clave) =>
      todos.firstWhere((n) => n.clave == clave, orElse: () => kcal);

  /// "12.5 g", "320 kcal", "450 mg".
  String formato(double valor) {
    if (unidad != 'g') return '${valor.round()} $unidad';
    final r = (valor * 10).round() / 10;
    return '${r == r.roundToDouble() ? r.toInt() : r} g';
  }
}

/// Desayuno, almuerzo, cena o aperitivos (claves de
/// `nutricion_tiempo_comida`).
class TiempoComida {
  final String clave;
  final String nombre;
  final IconData icono;

  const TiempoComida(this.clave, this.nombre, this.icono);

  static const desayuno = TiempoComida(
    'desayuno',
    'Desayuno',
    Icons.free_breakfast_rounded,
  );
  static const almuerzo = TiempoComida(
    'almuerzo',
    'Almuerzo',
    Icons.lunch_dining_rounded,
  );
  static const cena = TiempoComida('cena', 'Cena', Icons.dinner_dining_rounded);
  static const aperitivo = TiempoComida(
    'aperitivo',
    'Aperitivos',
    Icons.cookie_rounded,
  );

  static const todos = [desayuno, almuerzo, cena, aperitivo];

  static TiempoComida de(String clave) =>
      todos.firstWhere((t) => t.clave == clave, orElse: () => aperitivo);

  /// El que toca según la hora: así al agregar ya viene elegido.
  static TiempoComida segunHora([DateTime? ahora]) {
    final h = (ahora ?? DateTime.now()).hour;
    if (h < 11) return desayuno;
    if (h < 16) return almuerzo;
    if (h >= 19) return cena;
    return aperitivo;
  }
}

/// "Alto en …": la calcula el backend con umbrales por 100 g.
class EtiquetaNutricional {
  final String clave;
  final String nombre;
  final Color color;

  /// Verdadero si conviene limitarlo (sodio, azúcar…); falso si es algo
  /// buscado (proteínas, fibra).
  final bool advertencia;

  const EtiquetaNutricional(
    this.clave,
    this.nombre,
    this.color, {
    this.advertencia = true,
  });

  static const _rojo = Color(0xFFE5484D);
  static const _naranja = Color(0xFFF5A623);

  static const todas = [
    EtiquetaNutricional(
      'alto_proteina',
      'Alto en proteínas',
      Color(0xFF2E7CF6),
      advertencia: false,
    ),
    EtiquetaNutricional('alto_sodio', 'Alto en sodio', _rojo),
    EtiquetaNutricional(
      'alto_grasa_saturada',
      'Alto en grasas saturadas',
      _rojo,
    ),
    EtiquetaNutricional('alto_azucar', 'Alto en azúcar', _rojo),
    EtiquetaNutricional('alto_grasa', 'Alto en grasas', _naranja),
    EtiquetaNutricional('alto_calorias', 'Alto en calorías', _naranja),
    EtiquetaNutricional(
      'alto_carbohidrato',
      'Alto en carbohidratos',
      Color(0xFF7C5CFC),
      advertencia: false,
    ),
    EtiquetaNutricional(
      'alto_fibra',
      'Alto en fibra',
      Color(0xFF22A06B),
      advertencia: false,
    ),
  ];

  static EtiquetaNutricional de(String clave) => todas.firstWhere(
    (e) => e.clave == clave,
    orElse: () => EtiquetaNutricional(clave, clave, Colors.blueGrey),
  );
}

/// Alimento del catálogo con sus nutrientes por 100 g.
class Alimento {
  final int id;
  final String nombre;
  final String? marca;
  final String fuente;
  final double porcionG;
  final String? porcionNombre;

  /// Ruta del backend ('./imagenes/alimentos/x.jpg') o URL absoluta (Open
  /// Food Facts). La API siempre manda una (genérica si no tiene).
  final String? imagenUrl;

  /// Autor y licencia de la foto (Wikimedia Commons), para el crédito.
  final String? imagenCredito;
  final List<String> etiquetas;
  final Map<String, double> por100g;

  const Alimento({
    required this.id,
    required this.nombre,
    this.marca,
    this.fuente = 'base',
    this.porcionG = 100,
    this.porcionNombre,
    this.imagenUrl,
    this.imagenCredito,
    this.etiquetas = const [],
    this.por100g = const {},
  });

  factory Alimento.desdeJson(Map<String, dynamic> j) {
    final por100 = (j['por_100g'] as Map?) ?? const {};
    final marca = '${j['marca'] ?? ''}'.trim();
    final porcionNombre = '${j['porcion_nombre'] ?? ''}'.trim();
    final imagen = '${j['imagen_url'] ?? ''}'.trim();
    final credito = '${j['imagen_credito'] ?? ''}'.trim();
    return Alimento(
      id: int.tryParse('${j['id']}') ?? 0,
      nombre: '${j['nombre'] ?? ''}',
      marca: marca.isEmpty ? null : marca,
      fuente: '${j['fuente'] ?? 'base'}',
      porcionG: _num(j['porcion_g']) > 0 ? _num(j['porcion_g']) : 100,
      porcionNombre: porcionNombre.isEmpty ? null : porcionNombre,
      imagenUrl: imagen.isEmpty ? null : imagen,
      imagenCredito: credito.isEmpty ? null : credito,
      etiquetas: [for (final e in (j['etiquetas'] as List?) ?? const []) '$e'],
      por100g: {
        for (final n in Nutriente.todos) n.clave: _num(por100[n.clave]),
      },
    );
  }

  double de(String clave) => por100g[clave] ?? 0;

  /// Aporte de [gramos] de este alimento.
  Map<String, double> aporte(double gramos) => {
    for (final n in Nutriente.todos) n.clave: de(n.clave) * gramos / 100,
  };

  /// "1 unidad (50 g)" o "100 g".
  String get porcionTexto {
    final g = gramosTexto(porcionG);
    return porcionNombre == null ? g : '$porcionNombre ($g)';
  }

  /// La unidad de la porción ("filete" de "1 filete"); null si la porción
  /// no empieza con "1 " (p. ej. "1/2 palta", "4 cucharadas", "30 g").
  String? get _unidad {
    final n = porcionNombre;
    if (n == null || !n.startsWith('1 ') || n.length < 3) return null;
    return n.substring(2);
  }

  /// [gramos] en palabras si es un múltiplo claro de la porción: "½ filete",
  /// "2 filetes". null si no lo es o la porción no tiene unidad.
  String? porcionesDe(double gramos) {
    final unidad = _unidad;
    if (unidad == null || porcionG <= 0) return null;
    final veces = gramos / porcionG;
    const multiplos = [
      (0.5, '½'),
      (1.0, '1'),
      (1.5, '1½'),
      (2.0, '2'),
      (2.5, '2½'),
      (3.0, '3'),
      (4.0, '4'),
    ];
    for (final (veces0, texto) in multiplos) {
      if ((veces - veces0).abs() < 0.02) {
        return '$texto ${veces0 > 1 ? plural(unidad) : unidad}';
      }
    }
    return null;
  }

  /// "150 g · 1 filete", o solo "137 g" si no es un múltiplo claro.
  String cantidadTexto(double gramos) {
    final p = porcionesDe(gramos);
    return p == null ? gramosTexto(gramos) : '${gramosTexto(gramos)} · $p';
  }

  /// Plural en español palabra por palabra: "lata escurrida" → "latas
  /// escurridas", "unidad mediana" → "unidades medianas".
  static String plural(String unidad) =>
      unidad.split(' ').map(_pluralPalabra).join(' ');

  static String _pluralPalabra(String p) {
    if (p.length <= 2 || p.endsWith('s')) return p; // "de", "tazas"…
    const vocales = 'aeiouáéíóú';
    return vocales.contains(p[p.length - 1].toLowerCase()) ? '${p}s' : '${p}es';
  }
}

/// "150 g", "62.5 g".
String gramosTexto(double g) =>
    '${g == g.roundToDouble() ? g.toInt() : (g * 10).round() / 10} g';

/// Meta diaria de un nutriente y cómo se cumple.
class MetaNutricion {
  final String clave;
  final double cantidad;

  /// minimo = llegar; maximo = no pasarse; rango = ±10 %.
  final String regla;

  /// auto = calculada con peso y altura; personal = la fijó el entrenador.
  final String origen;

  const MetaNutricion({
    required this.clave,
    required this.cantidad,
    required this.regla,
    required this.origen,
  });

  factory MetaNutricion.desdeJson(Map<String, dynamic> j) => MetaNutricion(
    clave: '${j['clave']}',
    cantidad: _num(j['cantidad']),
    regla: '${j['regla'] ?? 'rango'}',
    origen: '${j['origen'] ?? 'auto'}',
  );

  Nutriente get nutriente => Nutriente.de(clave);

  bool cumple(double valor) {
    if (cantidad <= 0) return true;
    switch (regla) {
      case 'minimo':
        return valor >= cantidad;
      case 'maximo':
        return valor <= cantidad;
      default:
        return (valor - cantidad).abs() <= cantidad * 0.10;
    }
  }

  String get reglaTexto => switch (regla) {
    'minimo' => 'mínimo',
    'maximo' => 'máximo',
    _ => 'objetivo',
  };

  static String nombreRegla(String regla) => switch (regla) {
    'minimo' => 'Llegar al menos a',
    'maximo' => 'No pasarse de',
    _ => 'Acercarse (±10 %)',
  };

  Map<String, dynamic> aJson() => {
    'clave': clave,
    'cantidad': cantidad,
    'regla': regla,
  };
}

/// Altura, peso (de Mis medidas) y objetivo del socio.
class PerfilNutricion {
  final int miembroId;
  final String nombre;
  final String? codigo;
  final int? edad;
  final double? alturaCm;
  final String? sexo;
  final String objetivo;
  final int actividad;
  final double? peso;
  final double? imc;

  const PerfilNutricion({
    required this.miembroId,
    required this.nombre,
    this.codigo,
    this.edad,
    this.alturaCm,
    this.sexo,
    this.objetivo = 'mantener',
    this.actividad = 2,
    this.peso,
    this.imc,
  });

  factory PerfilNutricion.desdeJson(Map<String, dynamic> j) => PerfilNutricion(
    miembroId: int.tryParse('${j['miembro_id']}') ?? 0,
    nombre: '${j['nombre'] ?? ''}',
    codigo: j['codigo']?.toString(),
    edad: _entONull(j['edad']),
    alturaCm: _numONull(j['altura_cm']),
    sexo: (j['sexo'] == 'M' || j['sexo'] == 'F') ? '${j['sexo']}' : null,
    objetivo: '${j['objetivo'] ?? 'mantener'}',
    actividad: _entONull(j['actividad']) ?? 2,
    peso: _numONull(j['peso']),
    imc: _numONull(j['imc']),
  );

  /// Sin altura no se pueden calcular las metas.
  bool get completo => alturaCm != null;

  String get categoriaImc {
    final v = imc;
    if (v == null) return '';
    if (v < 18.5) return 'Bajo peso';
    if (v < 25) return 'Normal';
    if (v < 30) return 'Sobrepeso';
    return 'Obesidad';
  }

  static const objetivos = {
    'perder': 'Bajar de peso',
    'mantener': 'Mantener mi peso',
    'ganar': 'Ganar masa muscular',
  };

  static const actividades = {
    1: 'Sedentario (sin ejercicio)',
    2: 'Ligero (1-3 días por semana)',
    3: 'Moderado (3-5 días por semana)',
    4: 'Intenso (6-7 días por semana)',
    5: 'Muy intenso (2 veces al día)',
  };
}

/// Alimento del plan que asignó el entrenador.
class ItemPlan {
  final int? id;
  final String tiempo;
  final double cantidadG;
  final Alimento alimento;

  const ItemPlan({
    this.id,
    required this.tiempo,
    required this.cantidadG,
    required this.alimento,
  });

  factory ItemPlan.desdeJson(Map<String, dynamic> j) => ItemPlan(
    id: _entONull(j['id']),
    tiempo: '${j['tiempo']}',
    cantidadG: _num(j['cantidad_g']),
    alimento: Alimento.desdeJson(Map<String, dynamic>.from(j['alimento'])),
  );

  ItemPlan copiar({double? cantidadG}) => ItemPlan(
    id: id,
    tiempo: tiempo,
    cantidadG: cantidadG ?? this.cantidadG,
    alimento: alimento,
  );

  Map<String, double> get aporte => alimento.aporte(cantidadG);
}

class PlanNutricion {
  final String nombre;
  final String? notas;
  final List<ItemPlan> items;

  const PlanNutricion({
    required this.nombre,
    this.notas,
    this.items = const [],
  });

  factory PlanNutricion.desdeJson(Map<String, dynamic> j) => PlanNutricion(
    nombre: '${j['nombre'] ?? 'Plan de alimentación'}',
    notas: (j['notas'] ?? '').toString().trim().isEmpty
        ? null
        : '${j['notas']}',
    items: [
      for (final i in (j['items'] as List?) ?? const [])
        ItemPlan.desdeJson(Map<String, dynamic>.from(i)),
    ],
  );

  List<ItemPlan> de(String tiempo) =>
      items.where((i) => i.tiempo == tiempo).toList();

  Map<String, double> get totales => sumarAportes(items.map((i) => i.aporte));
}

/// Algo que comió el socio.
class Consumo {
  final String uid;
  final String fecha;
  final String tiempo;
  final double cantidadG;
  final int? planItemId;
  final Alimento alimento;

  const Consumo({
    required this.uid,
    required this.fecha,
    required this.tiempo,
    required this.cantidadG,
    this.planItemId,
    required this.alimento,
  });

  factory Consumo.desdeJson(Map<String, dynamic> j) => Consumo(
    uid: '${j['uid']}',
    fecha: '${j['fecha']}',
    tiempo: '${j['tiempo']}',
    cantidadG: _num(j['cantidad_g']),
    planItemId: _entONull(j['plan_item_id']),
    alimento: Alimento.desdeJson(Map<String, dynamic>.from(j['alimento'])),
  );

  Map<String, double> get aporte => alimento.aporte(cantidadG);
}

/// Totales de un día y si cumplió cada meta.
class DiaNutricion {
  final String fecha;
  final int registros;
  final Map<String, double> totales;
  final Map<String, bool?> cumple;

  /// Proteínas y grasas dentro de su meta; null si no hay metas.
  final bool? cumpleDia;

  const DiaNutricion({
    required this.fecha,
    required this.registros,
    required this.totales,
    required this.cumple,
    this.cumpleDia,
  });

  factory DiaNutricion.desdeJson(Map<String, dynamic> j) {
    final totales = (j['totales'] as Map?) ?? const {};
    final cumple = j['cumple'] is Map ? j['cumple'] as Map : const {};
    return DiaNutricion(
      fecha: '${j['fecha']}',
      registros: int.tryParse('${j['registros']}') ?? 0,
      totales: {
        for (final n in Nutriente.todos) n.clave: _num(totales[n.clave]),
      },
      cumple: {for (final e in cumple.entries) '${e.key}': e.value as bool?},
      cumpleDia: j['cumple_dia'] as bool?,
    );
  }
}

class RachaNutricion {
  final int actual;
  final int mejor;
  final int diasCumplidos;
  final int diasConRegistro;

  const RachaNutricion({
    this.actual = 0,
    this.mejor = 0,
    this.diasCumplidos = 0,
    this.diasConRegistro = 0,
  });

  factory RachaNutricion.desdeJson(Map<String, dynamic> j) => RachaNutricion(
    actual: int.tryParse('${j['actual']}') ?? 0,
    mejor: int.tryParse('${j['mejor']}') ?? 0,
    diasCumplidos: int.tryParse('${j['dias_cumplidos']}') ?? 0,
    diasConRegistro: int.tryParse('${j['dias_con_registro']}') ?? 0,
  );
}

/// Todo lo de nutrición de un socio en un periodo.
class ResumenNutricion {
  final String desde;
  final String hasta;
  final PerfilNutricion perfil;
  final List<MetaNutricion> metas;
  final PlanNutricion? plan;
  final List<Consumo> consumos;
  final List<DiaNutricion> dias;
  final RachaNutricion racha;

  const ResumenNutricion({
    required this.desde,
    required this.hasta,
    required this.perfil,
    required this.metas,
    this.plan,
    required this.consumos,
    required this.dias,
    required this.racha,
  });

  factory ResumenNutricion.desdeJson(Map<String, dynamic> j) =>
      ResumenNutricion(
        desde: '${j['desde']}',
        hasta: '${j['hasta']}',
        perfil: PerfilNutricion.desdeJson(
          Map<String, dynamic>.from(j['perfil']),
        ),
        metas: [
          for (final m in (j['metas'] as List?) ?? const [])
            MetaNutricion.desdeJson(Map<String, dynamic>.from(m)),
        ],
        plan: j['plan'] is Map
            ? PlanNutricion.desdeJson(Map<String, dynamic>.from(j['plan']))
            : null,
        consumos: [
          for (final c in (j['consumos'] as List?) ?? const [])
            Consumo.desdeJson(Map<String, dynamic>.from(c)),
        ],
        dias: [
          for (final d in (j['dias'] as List?) ?? const [])
            DiaNutricion.desdeJson(Map<String, dynamic>.from(d)),
        ],
        racha: j['racha'] is Map
            ? RachaNutricion.desdeJson(Map<String, dynamic>.from(j['racha']))
            : const RachaNutricion(),
      );

  MetaNutricion? meta(String clave) {
    for (final m in metas) {
      if (m.clave == clave) return m;
    }
    return null;
  }

  List<Consumo> consumosDe(String fecha) =>
      consumos.where((c) => c.fecha == fecha).toList();

  DiaNutricion? dia(String fecha) {
    for (final d in dias) {
      if (d.fecha == fecha) return d;
    }
    return null;
  }
}

Map<String, double> sumarAportes(Iterable<Map<String, double>> aportes) {
  final total = {for (final n in Nutriente.todos) n.clave: 0.0};
  for (final a in aportes) {
    for (final e in a.entries) {
      total[e.key] = (total[e.key] ?? 0) + e.value;
    }
  }
  return total;
}

/// 'YYYY-MM-DD' de una fecha local.
String isoFecha(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';
