import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';

/// Seguimiento de un socio visto por el personal: lo que llega de
/// `seguimiento.php → detalle` (sesiones con sus series y medidas).

double? _numONull(dynamic v) => v == null ? null : double.tryParse('$v');
int? _entONull(dynamic v) => v == null ? null : int.tryParse('$v');

/// Una serie de una sesión: repeticiones y peso (y por lado si fue
/// unilateral).
class SerieSocio {
  final int numero;
  final int repeticiones;
  final double? peso;
  final int? repsIzq;
  final int? repsDer;

  const SerieSocio({
    required this.numero,
    required this.repeticiones,
    this.peso,
    this.repsIzq,
    this.repsDer,
  });

  factory SerieSocio.desdeJson(Map<String, dynamic> j) => SerieSocio(
    numero: _entONull(j['numero']) ?? 0,
    repeticiones: _entONull(j['repeticiones']) ?? 0,
    peso: _numONull(j['peso']),
    repsIzq: _entONull(j['reps_izq']),
    repsDer: _entONull(j['reps_der']),
  );

  /// "12" o, si fue unilateral, "I10/D9" (como en la app del socio).
  String get repsTexto => repsIzq != null && repsDer != null
      ? 'I$repsIzq/D$repsDer'
      : '$repeticiones';
}

/// Un ejercicio hecho un día.
class SesionSocio {
  final String uid;
  final DateTime fecha;
  final String? rutinaNombre;
  final String? diaSemana;
  final String ejercicio;
  final double peso;
  final int repeticiones;
  final List<SerieSocio> series;

  const SesionSocio({
    required this.uid,
    required this.fecha,
    this.rutinaNombre,
    this.diaSemana,
    required this.ejercicio,
    required this.peso,
    required this.repeticiones,
    this.series = const [],
  });

  factory SesionSocio.desdeJson(Map<String, dynamic> j) => SesionSocio(
    uid: '${j['uid']}',
    fecha: DateTime.tryParse('${j['fecha']}') ?? DateTime(2000),
    rutinaNombre: (j['rutina_nombre'] ?? '').toString().trim().isEmpty
        ? null
        : '${j['rutina_nombre']}',
    diaSemana: j['dia_semana']?.toString(),
    ejercicio: '${j['ejercicio_nombre'] ?? 'Ejercicio'}'.trim(),
    peso: _numONull(j['peso']) ?? 0,
    repeticiones: _entONull(j['repeticiones']) ?? 0,
    series: [
      for (final s in (j['series'] as List?) ?? const [])
        SerieSocio.desdeJson(Map<String, dynamic>.from(s)),
    ],
  );

  /// Peso de una serie; si no se guardó, el de la sesión.
  double pesoDe(SerieSocio s) => s.peso ?? peso;

  /// La carga más alta del día (la que cuenta para el récord).
  double get mejorPeso => series.isEmpty
      ? peso
      : series.map(pesoDe).reduce((a, b) => a > b ? a : b);

  int get totalReps => series.isEmpty
      ? repeticiones
      : series.fold(0, (s, x) => s + x.repeticiones);

  /// "12 × 40 kg · 10 × 45 kg".
  String get seriesTexto => series.isEmpty
      ? '$repeticiones reps · ${numeroMedida(peso)} kg'
      : [
          for (final s in series)
            '${s.repsTexto} × ${numeroMedida(pesoDe(s))} kg',
        ].join(' · ');
}

/// Todas las sesiones de un mismo ejercicio, de la más antigua a la última.
class EjercicioSocio {
  final String nombre;
  final List<SesionSocio> sesiones;

  const EjercicioSocio(this.nombre, this.sesiones);

  SesionSocio get primera => sesiones.first;
  SesionSocio get ultima => sesiones.last;

  double get mejorPeso =>
      sesiones.map((s) => s.mejorPeso).reduce((a, b) => a > b ? a : b);

  /// Cuánto subió la carga desde la primera vez.
  double get mejora => mejorPeso - primera.mejorPeso;

  int get totalSeries =>
      sesiones.fold(0, (s, x) => s + (x.series.isEmpty ? 1 : x.series.length));
}

/// Cambio de una zona del cuerpo desde la primera medida.
class CambioMedida {
  final ZonaMedida zona;
  final double inicio;
  final double actual;

  const CambioMedida(this.zona, this.inicio, this.actual);

  double get cambio => actual - inicio;

  /// True si fue hacia donde conviene; null si a esa zona le da igual.
  bool? get bueno => switch (zona.tendencia) {
    TendenciaMedida.subir => cambio > 0,
    TendenciaMedida.bajar => cambio < 0,
    TendenciaMedida.neutral => null,
  };
}

class SeguimientoSocio {
  final int miembroId;
  final String nombre;
  final String? codigo;
  final String? imagen;
  final String? telefono;
  final DateTime? fechaNacimiento;

  /// De la más reciente a la más antigua.
  final List<SesionSocio> sesiones;

  /// De la más antigua a la más reciente.
  final List<Medida> medidas;

  const SeguimientoSocio({
    required this.miembroId,
    required this.nombre,
    this.codigo,
    this.imagen,
    this.telefono,
    this.fechaNacimiento,
    this.sesiones = const [],
    this.medidas = const [],
  });

  factory SeguimientoSocio.desdeJson(Map<String, dynamic> j) {
    final socio = Map<String, dynamic>.from(j['socio'] ?? const {});
    final medidas = <Medida>[];
    for (final m in (j['medidas'] as List?) ?? const []) {
      final fecha = DateTime.tryParse('${m['fecha']}');
      final valor = double.tryParse('${m['valor']}');
      if (fecha == null || valor == null) continue;
      medidas.add(
        Medida(
          id: medidas.length,
          zona: '${m['zona']}',
          fecha: fecha,
          valor: valor,
        ),
      );
    }
    final sesiones = [
      for (final s in (j['sesiones'] as List?) ?? const [])
        SesionSocio.desdeJson(Map<String, dynamic>.from(s)),
    ]..sort((a, b) => b.fecha.compareTo(a.fecha));
    return SeguimientoSocio(
      miembroId: _entONull(socio['miembro_id']) ?? 0,
      nombre: '${socio['nombre'] ?? ''}'.trim(),
      codigo: socio['codigo']?.toString(),
      imagen: socio['imagen']?.toString(),
      telefono: socio['telefono']?.toString(),
      fechaNacimiento: DateTime.tryParse('${socio['fecha_nacimiento']}'),
      sesiones: sesiones,
      medidas: medidas..sort((a, b) => a.fecha.compareTo(b.fecha)),
    );
  }

  int? get edad {
    final n = fechaNacimiento;
    if (n == null) return null;
    final h = DateTime.now();
    var e = h.year - n.year;
    if (h.month < n.month || (h.month == n.month && h.day < n.day)) e--;
    return e > 0 && e < 120 ? e : null;
  }

  /// Ejercicios agrupados por nombre, el que más mejoró primero.
  List<EjercicioSocio> get ejercicios {
    final grupos = <String, List<SesionSocio>>{};
    for (final s in sesiones.reversed) {
      grupos.putIfAbsent(s.ejercicio.toLowerCase(), () => []).add(s);
    }
    return [for (final g in grupos.values) EjercicioSocio(g.first.ejercicio, g)]
      ..sort((a, b) {
        final m = b.mejora.compareTo(a.mejora);
        return m != 0 ? m : b.ultima.fecha.compareTo(a.ultima.fecha);
      });
  }

  /// Días distintos en los que entrenó.
  int get diasEntrenados => sesiones.map((s) => _dia(s.fecha)).toSet().length;

  /// Días entrenados en los últimos 7 (hoy incluido).
  int get diasUltimaSemana {
    final h = DateTime.now();
    final desde = DateTime(h.year, h.month, h.day - 6);
    return sesiones
        .where((s) => !s.fecha.isBefore(desde))
        .map((s) => _dia(s.fecha))
        .toSet()
        .length;
  }

  int get totalSeries =>
      sesiones.fold(0, (s, x) => s + (x.series.isEmpty ? 1 : x.series.length));

  List<Medida> medidasDe(String zona) =>
      medidas.where((m) => m.zona == zona).toList();

  double? get pesoActual {
    final p = medidasDe('peso');
    return p.isEmpty ? null : p.last.valor;
  }

  /// Zonas con al menos dos medidas y algún cambio.
  List<CambioMedida> get cambiosMedidas => [
    for (final z in ZonaMedida.todas)
      if (medidasDe(z.clave) case final r when r.length >= 2)
        if (r.last.valor != r.first.valor)
          CambioMedida(z, r.first.valor, r.last.valor),
  ];

  int get zonasMedidas =>
      ZonaMedida.todas.where((z) => medidasDe(z.clave).isNotEmpty).length;

  static String _dia(DateTime f) => '${f.year}-${f.month}-${f.day}';
}
