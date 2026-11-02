// Modelos del módulo de gestión de rutinas para el PERSONAL (admin/colaboradores).
//
// Son independientes de las entidades del cliente (que están atadas a SQLite y
// al seguimiento de "marcas"). Aquí trabajamos directo contra el backend
// (`rutinas.php`) con modelos mutables, pensados para crear/editar/asignar.
//
// La rutina es la semana: cada día tiene uno o varios bloques (DiaAdmin) y
// cada bloque su metodología (musculación, circuito, HIIT, EMOM, AMRAP o
// estaciones), con sus rondas y tiempos.

import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';

/// Restricciones de un nivel de rutina en la sucursal (Configuración > Rutinas
/// en el web). El backend las aplica al guardar; aquí acotan lo que se ofrece.
class ReglaNivel {
  final String nivel;

  /// Null = ilimitado.
  final int? maxEjerciciosDia;
  final List<String> tipos;
  final String nivelEjercicioMax;

  const ReglaNivel({
    required this.nivel,
    this.maxEjerciciosDia,
    required this.tipos,
    required this.nivelEjercicioMax,
  });

  factory ReglaNivel.fromJson(Map<String, dynamic> j) => ReglaNivel(
    nivel: j['nivel']?.toString() ?? '',
    maxEjerciciosDia: _positivo(j['max_ejercicios_dia']),
    tipos: (j['tipos_ejercicio']?.toString() ?? '').split(',').where((t) => t.isNotEmpty).toList(),
    nivelEjercicioMax: j['nivel_ejercicio_max']?.toString() ?? '',
  );

  /// Lo que no está clasificado no se bloquea.
  bool permite({String? nivel, String? tipo}) {
    if (tipo != null && !tipos.contains(tipo)) return false;
    if (nivel == null) return true;
    final orden = nivelesRutina.keys.toList();
    return orden.indexOf(nivel) <= orden.indexOf(nivelEjercicioMax);
  }

  /// "Hasta 2 ejercicios por día · Aislado, Core · ejercicios hasta nivel Principiante"
  String get resumen {
    final maximo = maxEjerciciosDia == null
        ? 'Ejercicios ilimitados por día'
        : 'Hasta $maxEjerciciosDia ejercicios por día';
    final permitidos = tipos.map((t) => tiposEjercicio[t] ?? t).join(', ');
    return '$maximo · $permitidos · ejercicios hasta nivel ${nivelesRutina[nivelEjercicioMax] ?? nivelEjercicioMax}';
  }
}

/// Resumen de una rutina para listados (metadata, sin el árbol de ejercicios).
class RutinaResumen {
  final int id;
  final String nombre;
  final String descripcion;
  final int totalDias;
  final int totalEjercicios;

  /// 1 = activa, 0 = anulada (el backend no lista las eliminadas = 2).
  final int estado;

  /// MUSCULACION, CIRCUITO, HIIT, EMOM, AMRAP, ESTACIONES o MIXTO.
  final String tipo;
  final int? duracionSeg;

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
    this.tipo = Metodologia.musculacion,
    this.duracionSeg,
    this.origenNombre,
  });

  Metodologia get metodologia => Metodologia.de(tipo);

  bool get activa => estado == 1;

  factory RutinaResumen.fromJson(Map<String, dynamic> j) => RutinaResumen(
    id: _int(j['id']),
    nombre: j['nombre']?.toString() ?? '',
    descripcion: j['descripcion']?.toString() ?? '',
    totalDias: _int(j['total_dias']),
    totalEjercicios: _int(j['total_ejercicios']),
    estado: _int(j['estado'], por: 1),
    tipo: j['tipo']?.toString() ?? Metodologia.musculacion,
    duracionSeg: _int(j['duracion_estimada_seg']) > 0
        ? _int(j['duracion_estimada_seg'])
        : null,
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
  String? objetivo;
  String? nivel;

  /// Cliente dueño de la rutina personalizada (null en plantillas generales).
  int? miembroId;

  /// Bloques de toda la semana; cada uno con su día y su metodología.
  List<DiaAdmin> dias;

  RutinaAdmin({
    this.id,
    this.nombre = '',
    this.descripcion = '',
    this.objetivo,
    this.nivel,
    this.miembroId,
    List<DiaAdmin>? dias,
  }) : dias = dias ?? [];

  /// La rutina en el formato del motor (vista previa, duración, temporizador).
  PlanRutina get plan => PlanRutina(
    nombre: nombre,
    objetivo: objetivo,
    nivel: nivel,
    bloques: [for (final d in dias) d.plan],
  );

  factory RutinaAdmin.fromJson(Map<String, dynamic> j) {
    final diasJson = (j['dias'] is List) ? j['dias'] as List : const [];
    return RutinaAdmin(
      id: _int(j['id']) == 0 ? null : _int(j['id']),
      nombre: j['nombre']?.toString() ?? '',
      descripcion: j['descripcion']?.toString() ?? '',
      objetivo: _texto(j['objetivo']),
      nivel: _texto(j['nivel']),
      miembroId: _int(j['miembro_id']) == 0 ? null : _int(j['miembro_id']),
      dias: diasJson
          .whereType<Map>()
          .map((d) => DiaAdmin.fromJson(Map<String, dynamic>.from(d)))
          .toList(),
    );
  }

  /// Serializa al formato que espera `rutinas.php` (metodo guardar). Los
  /// bloques van en el orden de la semana; `tipo` le dice al backend que esta
  /// app ya entiende las metodologías.
  Map<String, dynamic> toJson() {
    int orden(String d) {
      final i = diasSemana.indexOf(d);
      return i == -1 ? 99 : i;
    }

    final ordenados = [
      for (var i = 0; i < dias.length; i++) (i, dias[i]),
    ]..sort((a, b) {
        final c = orden(a.$2.diaSemana).compareTo(orden(b.$2.diaSemana));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo': plan.tipo,
      'objetivo': objetivo,
      'nivel': nivel,
      if (miembroId != null) 'miembro_id': miembroId,
      'dias': [
        for (var i = 0; i < ordenados.length; i++) ordenados[i].$2.toJson(i + 1),
      ],
    };
  }
}

/// Un bloque de un día: su metodología, reglas y ejercicios.
class DiaAdmin {
  String diaSemana;
  String tipo;
  String? nombre;
  int rondas;
  int? descansoRondaSeg;
  int? tiempoLimiteSeg;
  int? intervaloSeg;
  int? descansoBloqueSeg;
  List<EjercicioAdmin> ejercicios;

  DiaAdmin({
    required this.diaSemana,
    this.tipo = Metodologia.musculacion,
    this.nombre,
    this.rondas = 1,
    this.descansoRondaSeg,
    this.tiempoLimiteSeg,
    this.intervaloSeg,
    this.descansoBloqueSeg,
    List<EjercicioAdmin>? ejercicios,
  }) : ejercicios = ejercicios ?? [];

  /// Bloque nuevo con los valores de partida de su metodología.
  factory DiaAdmin.nuevo(String dia, String tipo) {
    final m = Metodologia.de(tipo);
    return DiaAdmin(
      diaSemana: dia,
      tipo: m.valor,
      rondas: m.usa(CampoMetodologia.rondas) ? m.rondasDefecto : 1,
      descansoRondaSeg: m.usa(CampoMetodologia.descansoRonda) ? 60 : null,
      tiempoLimiteSeg: m.usa(CampoMetodologia.tiempoLimite) ? 600 : null,
      intervaloSeg: m.forma == FormaMetodologia.emom ? 60 : null,
    );
  }

  Metodologia get metodologia => Metodologia.de(tipo);

  /// Cambia la metodología conservando los ejercicios y completando lo que
  /// la nueva necesita.
  void cambiarTipo(String nuevo) {
    final m = Metodologia.de(nuevo);
    final base = DiaAdmin.nuevo(diaSemana, nuevo);
    tipo = m.valor;
    if (m.usa(CampoMetodologia.rondas) && rondas <= 1) rondas = base.rondas;
    if (m.usa(CampoMetodologia.descansoRonda)) descansoRondaSeg ??= base.descansoRondaSeg;
    if (m.usa(CampoMetodologia.tiempoLimite)) tiempoLimiteSeg ??= base.tiempoLimiteSeg;
    if (m.usa(CampoMetodologia.intervalo)) intervaloSeg ??= base.intervaloSeg;
    for (final e in ejercicios) {
      e.completarPara(m);
    }
  }

  DiaAdmin copia({String? dia}) => DiaAdmin(
    diaSemana: dia ?? diaSemana,
    tipo: tipo,
    nombre: nombre,
    rondas: rondas,
    descansoRondaSeg: descansoRondaSeg,
    tiempoLimiteSeg: tiempoLimiteSeg,
    intervaloSeg: intervaloSeg,
    descansoBloqueSeg: descansoBloqueSeg,
    ejercicios: [for (final e in ejercicios) e.copia()],
  );

  PlanBloque get plan => PlanBloque(
    tipo: tipo,
    diaSemana: diaSemana,
    nombre: nombre,
    rondas: rondas,
    descansoRondaSeg: descansoRondaSeg,
    tiempoLimiteSeg: tiempoLimiteSeg,
    intervaloSeg: intervaloSeg,
    descansoBloqueSeg: descansoBloqueSeg,
    ejercicios: [for (final e in ejercicios) e.plan],
  );

  factory DiaAdmin.fromJson(Map<String, dynamic> j) {
    final ejsJson = (j['ejercicios'] is List)
        ? j['ejercicios'] as List
        : const [];
    return DiaAdmin(
      diaSemana: j['dia_semana']?.toString() ?? '',
      tipo: j['tipo']?.toString() ?? Metodologia.musculacion,
      nombre: _texto(j['nombre']),
      rondas: _int(j['rondas'], por: 1) < 1 ? 1 : _int(j['rondas'], por: 1),
      descansoRondaSeg: _positivo(j['descanso_ronda_seg']),
      tiempoLimiteSeg: _positivo(j['tiempo_limite_seg']),
      intervaloSeg: _positivo(j['intervalo_seg']),
      descansoBloqueSeg: _positivo(j['descanso_bloque_seg']),
      ejercicios: ejsJson
          .whereType<Map>()
          .map((e) => EjercicioAdmin.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  Map<String, dynamic> toJson(int orden) => {
    'dia_semana': diaSemana,
    'tipo': tipo,
    if (nombre != null && nombre!.isNotEmpty) 'nombre': nombre,
    'rondas': rondas,
    'descanso_ronda_seg': descansoRondaSeg,
    'tiempo_limite_seg': tiempoLimiteSeg,
    'intervalo_seg': intervaloSeg,
    'descanso_bloque_seg': descansoBloqueSeg,
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

  /// Descanso entre series por defecto (segundos). Se conserva al editar desde
  /// el móvil para no borrar lo que se fijó en el web.
  int? descansoSeg;

  /// Bloques por tiempo: segundos de trabajo (null = por repeticiones). Ahí
  /// [descansoSeg] es el descanso después del ejercicio.
  int? trabajoSeg;
  double? pesoKg;

  /// Tempo de cada repetición (segundos al bajar y al subir) y velocidad
  /// (LENTO, MODERADO, RAPIDO, EXPLOSIVO).
  int? tempoBajadaSeg;
  int? tempoSubidaSeg;
  String? velocidad;

  /// Esfuerzo objetivo (1 a 10, escala de Borg).
  int? rpe;
  String? observaciones;
  int? catalogoId;
  String? imagenUrl;

  /// Solo en las rutinas propias del socio (no viajan a rutinas.php): un lado
  /// a la vez y el video del catálogo que ya tenía el ejercicio.
  bool unilateral;
  String? videoUrl;

  EjercicioAdmin({
    required this.nombre,
    this.series = 0,
    this.repeticiones = 0,
    this.descansoSeg,
    this.trabajoSeg,
    this.pesoKg,
    this.tempoBajadaSeg,
    this.tempoSubidaSeg,
    this.velocidad,
    this.rpe,
    this.observaciones,
    this.catalogoId,
    this.imagenUrl,
    this.unilateral = false,
    this.videoUrl,
  });

  /// Completa lo que la metodología [m] necesita (p. ej. tiempo en HIIT).
  void completarPara(Metodologia m) {
    if (m.trabajoObligatorio && (trabajoSeg ?? 0) <= 0) trabajoSeg = 30;
    if (m.esSeries) {
      if (series <= 0) series = 3;
      if (repeticiones <= 0) repeticiones = 10;
    } else if ((trabajoSeg ?? 0) <= 0 && repeticiones <= 0) {
      if (m.forma == FormaMetodologia.circuito) {
        trabajoSeg = 30;
      } else {
        repeticiones = 10;
      }
    }
    if (m.usa(CampoMetodologia.descanso) && !m.esSeries) descansoSeg ??= 15;
  }

  EjercicioAdmin copia() => EjercicioAdmin(
    nombre: nombre,
    series: series,
    repeticiones: repeticiones,
    descansoSeg: descansoSeg,
    trabajoSeg: trabajoSeg,
    pesoKg: pesoKg,
    tempoBajadaSeg: tempoBajadaSeg,
    tempoSubidaSeg: tempoSubidaSeg,
    velocidad: velocidad,
    rpe: rpe,
    observaciones: observaciones,
    catalogoId: catalogoId,
    imagenUrl: imagenUrl,
    unilateral: unilateral,
    videoUrl: videoUrl,
  );

  PlanEjercicio get plan => PlanEjercicio(
    nombre: nombre,
    series: series,
    repeticiones: repeticiones,
    trabajoSeg: trabajoSeg,
    pesoKg: pesoKg,
    descansoSeg: descansoSeg,
    tempoBajadaSeg: tempoBajadaSeg,
    tempoSubidaSeg: tempoSubidaSeg,
    velocidad: velocidad,
    rpe: rpe,
    observaciones: observaciones,
    imagenUrl: imagenUrl,
  );

  factory EjercicioAdmin.fromJson(Map<String, dynamic> j) => EjercicioAdmin(
    nombre: j['nombre']?.toString() ?? '',
    series: _int(j['series']),
    repeticiones: _int(j['repeticiones']),
    descansoSeg: _int(j['descanso_seg']) > 0 ? _int(j['descanso_seg']) : null,
    trabajoSeg: _positivo(j['trabajo_seg']),
    pesoKg: double.tryParse(j['peso_kg']?.toString() ?? ''),
    tempoBajadaSeg: _positivo(j['tempo_bajada_seg']),
    tempoSubidaSeg: _positivo(j['tempo_subida_seg']),
    velocidad: (j['velocidad']?.toString().trim().isEmpty ?? true)
        ? null
        : j['velocidad'].toString(),
    rpe: _positivo(j['rpe']),
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
    if (descansoSeg != null) 'descanso_seg': descansoSeg,
    if (trabajoSeg != null) 'trabajo_seg': trabajoSeg,
    if (pesoKg != null) 'peso_kg': pesoKg,
    if (tempoBajadaSeg != null) 'tempo_bajada_seg': tempoBajadaSeg,
    if (tempoSubidaSeg != null) 'tempo_subida_seg': tempoSubidaSeg,
    if (velocidad != null) 'velocidad': velocidad,
    if (rpe != null) 'rpe': rpe,
    if (observaciones != null && observaciones!.isNotEmpty)
      'observaciones': observaciones,
    'orden': orden,
    if (catalogoId != null) 'ejercicio_catalogo_id': catalogoId,
  };
}

int? _positivo(dynamic v) => _int(v) > 0 ? _int(v) : null;

String? _texto(dynamic v) {
  final s = v?.toString().trim() ?? '';
  return s.isEmpty ? null : s;
}

int _int(dynamic v, {int por = 0}) =>
    v == null ? por : (v is int ? v : int.tryParse(v.toString()) ?? por);
