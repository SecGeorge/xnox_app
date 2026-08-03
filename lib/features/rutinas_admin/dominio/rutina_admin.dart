// Modelos del módulo de gestión de rutinas para el PERSONAL (admin/colaboradores).
//
// Son independientes de las entidades del cliente (que están atadas a SQLite y
// al seguimiento de "marcas"). Aquí trabajamos directo contra el backend
// (`rutinas.php`) con modelos mutables, pensados para crear/editar/asignar.

/// Resumen de una rutina para listados (metadata, sin el árbol de ejercicios).
class RutinaResumen {
  final int id;
  final String nombre;
  final String descripcion;
  final int totalDias;
  final int totalEjercicios;

  /// 1 = activa, 0 = anulada (el backend no lista las eliminadas = 2).
  final int estado;

  /// Nombre de la plantilla de la que se copió (si es personalizada). Puede ser
  /// null cuando la rutina se creó desde cero para el cliente.
  final String? origenNombre;

  const RutinaResumen({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.totalDias,
    required this.totalEjercicios,
    required this.estado,
    this.origenNombre,
  });

  bool get activa => estado == 1;

  factory RutinaResumen.fromJson(Map<String, dynamic> j) => RutinaResumen(
        id: _int(j['id']),
        nombre: j['nombre']?.toString() ?? '',
        descripcion: j['descripcion']?.toString() ?? '',
        totalDias: _int(j['total_dias']),
        totalEjercicios: _int(j['total_ejercicios']),
        estado: _int(j['estado'], por: 1),
        origenNombre: (j['rutina_origen_nombre']?.toString().trim().isEmpty ?? true)
            ? null
            : j['rutina_origen_nombre'].toString(),
      );
}

/// Rutina completa (cabecera + días + ejercicios), mutable para el formulario.
class RutinaAdmin {
  int? id; // null = nueva
  String nombre;
  String descripcion;

  /// Cliente dueño de la rutina personalizada (null en plantillas generales).
  int? miembroId;
  List<DiaAdmin> dias;

  RutinaAdmin({
    this.id,
    this.nombre = '',
    this.descripcion = '',
    this.miembroId,
    List<DiaAdmin>? dias,
  }) : dias = dias ?? [];

  factory RutinaAdmin.fromJson(Map<String, dynamic> j) {
    final diasJson = (j['dias'] is List) ? j['dias'] as List : const [];
    return RutinaAdmin(
      id: _int(j['id']) == 0 ? null : _int(j['id']),
      nombre: j['nombre']?.toString() ?? '',
      descripcion: j['descripcion']?.toString() ?? '',
      miembroId: _int(j['miembro_id']) == 0 ? null : _int(j['miembro_id']),
      dias: diasJson
          .whereType<Map>()
          .map((d) => DiaAdmin.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }

  /// Serializa al formato que espera `rutinas.php` (metodo guardar).
  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'descripcion': descripcion,
        if (miembroId != null) 'miembro_id': miembroId,
        'dias': [
          for (var i = 0; i < dias.length; i++) dias[i].toJson(i + 1),
        ],
      };
}

class DiaAdmin {
  String diaSemana;
  List<EjercicioAdmin> ejercicios;

  DiaAdmin({required this.diaSemana, List<EjercicioAdmin>? ejercicios})
      : ejercicios = ejercicios ?? [];

  factory DiaAdmin.fromJson(Map<String, dynamic> j) {
    final ejsJson = (j['ejercicios'] is List) ? j['ejercicios'] as List : const [];
    return DiaAdmin(
      diaSemana: j['dia_semana']?.toString() ?? '',
      ejercicios: ejsJson
          .whereType<Map>()
          .map((e) => EjercicioAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson(int orden) => {
        'dia_semana': diaSemana,
        'orden': orden,
        'ejercicios': [
          for (var i = 0; i < ejercicios.length; i++) ejercicios[i].toJson(i + 1),
        ],
      };
}

class EjercicioAdmin {
  String nombre;
  int series;
  int repeticiones;
  String? observaciones;
  int? catalogoId;
  String? imagenUrl;

  EjercicioAdmin({
    required this.nombre,
    this.series = 0,
    this.repeticiones = 0,
    this.observaciones,
    this.catalogoId,
    this.imagenUrl,
  });

  factory EjercicioAdmin.fromJson(Map<String, dynamic> j) => EjercicioAdmin(
        nombre: j['nombre']?.toString() ?? '',
        series: _int(j['series']),
        repeticiones: _int(j['repeticiones']),
        observaciones: (j['observaciones']?.toString().trim().isEmpty ?? true)
            ? null
            : j['observaciones'].toString(),
        catalogoId: _int(j['ejercicio_catalogo_id']) == 0
            ? null
            : _int(j['ejercicio_catalogo_id']),
        // La imagen llega como ruta relativa; el repositorio la vuelve absoluta.
        imagenUrl: (j['imagen']?.toString().trim().isEmpty ?? true)
            ? null
            : j['imagen'].toString(),
      );

  Map<String, dynamic> toJson(int orden) => {
        'nombre': nombre,
        'series': series,
        'repeticiones': repeticiones,
        if (observaciones != null && observaciones!.isNotEmpty)
          'observaciones': observaciones,
        'orden': orden,
        if (catalogoId != null) 'ejercicio_catalogo_id': catalogoId,
      };
}

int _int(dynamic v, {int por = 0}) =>
    v == null ? por : (v is int ? v : int.tryParse(v.toString()) ?? por);
