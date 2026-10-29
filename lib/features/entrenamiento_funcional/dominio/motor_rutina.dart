import 'dart:math' as math;

import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';

/// Rutina en un formato neutro que entiende el motor. La arman tanto las
/// rutinas del socio (SQLite) como las del personal (backend).
///
/// La rutina es la semana: cada día tiene uno o varios bloques en orden, y
/// cada bloque su propia metodología (un calentamiento HIIT y dos circuitos
/// el lunes, musculación el martes...). La sesión de un día son sus bloques.
class PlanRutina {
  final String nombre;
  final String? objetivo;
  final String? nivel;
  final List<PlanBloque> bloques;

  const PlanRutina({
    required this.nombre,
    this.objetivo,
    this.nivel,
    required this.bloques,
  });

  /// El tipo de todos sus bloques, o MIXTO si combinan.
  String get tipo {
    final tipos = {for (final b in bloques) b.tipo};
    if (tipos.isEmpty) return Metodologia.musculacion;
    return tipos.length == 1 ? tipos.first : 'MIXTO';
  }

  Metodologia get metodologia => Metodologia.de(tipo);

  /// Bloques con al menos un ejercicio con nombre.
  List<PlanBloque> get bloquesValidos =>
      bloques.where((b) => b.ejerciciosValidos.isNotEmpty).toList();

  /// Días con entrenamiento, en el orden de la semana.
  List<SesionDia> get sesiones {
    final grupos = <String, List<PlanBloque>>{};
    for (final b in bloquesValidos) {
      (grupos[b.diaSemana] ??= []).add(b);
    }
    int orden(String d) {
      final i = diasSemana.indexOf(d);
      return i == -1 ? 99 : i;
    }

    final dias = grupos.keys.toList()
      ..sort((a, b) => orden(a).compareTo(orden(b)));
    return [for (final d in dias) SesionDia(d, grupos[d]!)];
  }
}

/// Los bloques que se entrenan un mismo día.
class SesionDia {
  final String dia;
  final List<PlanBloque> bloques;

  const SesionDia(this.dia, this.bloques);

  String get etiqueta => dia.isEmpty ? 'Sin día' : dia;

  int get duracion => MotorRutina.sumar(MotorRutina.expandirDia(bloques));
}

class PlanBloque {
  final String tipo;
  final String diaSemana;
  final String? nombre;
  final int rondas;
  final int? descansoRondaSeg;
  final int? tiempoLimiteSeg;
  final int? intervaloSeg;
  final int? descansoBloqueSeg;
  final List<PlanEjercicio> ejercicios;

  const PlanBloque({
    this.tipo = Metodologia.musculacion,
    this.diaSemana = '',
    this.nombre,
    this.rondas = 1,
    this.descansoRondaSeg,
    this.tiempoLimiteSeg,
    this.intervaloSeg,
    this.descansoBloqueSeg,
    required this.ejercicios,
  });

  Metodologia get metodologia => Metodologia.de(tipo);

  List<PlanEjercicio> get ejerciciosValidos =>
      ejercicios.where((e) => e.nombre.trim().isNotEmpty).toList();
}

class PlanEjercicio {
  final String nombre;
  final int series;
  final int repeticiones;
  final int? trabajoSeg;
  final double? pesoKg;
  final int? descansoSeg;
  final String? observaciones;
  final String? imagenUrl;

  const PlanEjercicio({
    required this.nombre,
    this.series = 0,
    this.repeticiones = 0,
    this.trabajoSeg,
    this.pesoKg,
    this.descansoSeg,
    this.observaciones,
    this.imagenUrl,
  });

  /// "10 reps · 30 s · 20 kg"
  String medida({bool conTiempo = true}) {
    final partes = <String>[
      if (repeticiones > 0) '$repeticiones reps',
      if (conTiempo && (trabajoSeg ?? 0) > 0) '$trabajoSeg s',
      if ((pesoKg ?? 0) > 0) '${formatoKg(pesoKg!)} kg',
    ];
    return partes.join(' · ');
  }

  static String formatoKg(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString();
}

/// Fase de un paso del entrenamiento.
enum FasePaso { trabajo, descanso, descansoRonda, descansoBloque, emom, amrap }

/// Un paso de la línea de tiempo: trabajar un ejercicio, descansar, un
/// intervalo EMOM o un bloque AMRAP. [duracion] null = el socio lo marca
/// como hecho (series por repeticiones).
class PasoRutina {
  final FasePaso fase;
  final int? duracion;
  final int estimado;
  final PlanEjercicio? ejercicio;
  final List<PlanEjercicio> ejercicios; // AMRAP: la secuencia completa
  final PlanEjercicio? siguiente;
  final Metodologia metodologia;
  final int bloque;
  final String bloqueNombre;
  final int ronda;
  final int? rondas;
  final int? serie;
  final int? series;
  final int indice;
  final int total;
  final int? minuto;
  final int? minutos;

  const PasoRutina({
    required this.fase,
    required this.duracion,
    required this.estimado,
    this.ejercicio,
    this.ejercicios = const [],
    this.siguiente,
    required this.metodologia,
    required this.bloque,
    required this.bloqueNombre,
    this.ronda = 1,
    this.rondas,
    this.serie,
    this.series,
    this.indice = 0,
    this.total = 0,
    this.minuto,
    this.minutos,
  });

  bool get esDescanso =>
      fase == FasePaso.descanso ||
      fase == FasePaso.descansoRonda ||
      fase == FasePaso.descansoBloque;

  int get segundos => duracion ?? estimado;
}

/// Convierte una rutina en la lista de pasos que recorren la vista previa, la
/// duración estimada y el modo de ejecución.
class MotorRutina {
  static const descansoSerieDefecto = 60;
  static const intervaloEmomDefecto = 60;

  /// Tiempo de un paso de trabajo; por repeticiones se estima 3 s por rep.
  static int trabajoEstimado(PlanEjercicio e) {
    if ((e.trabajoSeg ?? 0) > 0) return e.trabajoSeg!;
    if (e.repeticiones > 0) return math.max(20, e.repeticiones * 3);
    return 30;
  }

  static String nombreBloque(PlanBloque b, int indice) {
    final m = b.metodologia;
    final n = (b.nombre ?? '').trim();
    if (n.isNotEmpty) return n;
    return m.esSeries ? m.etiquetaBloque : '${m.etiquetaBloque} ${indice + 1}';
  }

  static List<PasoRutina> expandirBloque(PlanBloque bloque, int indiceBloque) {
    final m = bloque.metodologia;
    final ejs = bloque.ejerciciosValidos;
    final n = ejs.length;
    final pasos = <PasoRutina>[];
    if (n == 0) return pasos;
    final nombre = nombreBloque(bloque, indiceBloque);

    switch (m.forma) {
      case FormaMetodologia.amrap:
        final dur = bloque.tiempoLimiteSeg ?? 0;
        pasos.add(
          PasoRutina(
            fase: FasePaso.amrap,
            duracion: dur,
            estimado: dur,
            ejercicio: ejs.first,
            ejercicios: ejs,
            metodologia: m,
            bloque: indiceBloque,
            bloqueNombre: nombre,
            total: n,
          ),
        );
        return pasos;

      case FormaMetodologia.emom:
        final intervalo = (bloque.intervaloSeg ?? 0) > 0
            ? bloque.intervaloSeg!
            : intervaloEmomDefecto;
        final intervalos = (bloque.tiempoLimiteSeg ?? 0) > 0
            ? bloque.tiempoLimiteSeg! ~/ intervalo
            : math.max(1, bloque.rondas) * n;
        final rondas = (intervalos / n).ceil();
        for (var i = 0; i < intervalos; i++) {
          pasos.add(
            PasoRutina(
              fase: FasePaso.emom,
              duracion: intervalo,
              estimado: intervalo,
              ejercicio: ejs[i % n],
              siguiente: i + 1 < intervalos ? ejs[(i + 1) % n] : null,
              metodologia: m,
              bloque: indiceBloque,
              bloqueNombre: nombre,
              ronda: i ~/ n + 1,
              rondas: rondas,
              indice: i % n,
              total: n,
              minuto: i + 1,
              minutos: intervalos,
            ),
          );
        }
        return pasos;

      case FormaMetodologia.series:
        for (var i = 0; i < n; i++) {
          final ej = ejs[i];
          final series = math.max(1, ej.series);
          final descanso = (ej.descansoSeg ?? 0) > 0
              ? ej.descansoSeg!
              : descansoSerieDefecto;
          for (var s = 1; s <= series; s++) {
            pasos.add(
              PasoRutina(
                fase: FasePaso.trabajo,
                duracion: (ej.trabajoSeg ?? 0) > 0 ? ej.trabajoSeg : null,
                estimado: trabajoEstimado(ej),
                ejercicio: ej,
                metodologia: m,
                bloque: indiceBloque,
                bloqueNombre: nombre,
                serie: s,
                series: series,
                rondas: 1,
                indice: i,
                total: n,
              ),
            );
            final ultimo = s == series && i == n - 1;
            if (!ultimo) {
              pasos.add(
                PasoRutina(
                  fase: FasePaso.descanso,
                  duracion: descanso,
                  estimado: descanso,
                  ejercicio: ej,
                  siguiente: s < series ? ej : ejs[i + 1],
                  metodologia: m,
                  bloque: indiceBloque,
                  bloqueNombre: nombre,
                  serie: s,
                  series: series,
                  rondas: 1,
                  indice: i,
                  total: n,
                ),
              );
            }
          }
        }
        return pasos;

      case FormaMetodologia.circuito:
      case FormaMetodologia.mixto:
        // La secuencia se repite por rondas. Entre rondas manda el descanso
        // de ronda (o el del último ejercicio); la última no descansa.
        final rondas = math.max(1, bloque.rondas);
        for (var r = 1; r <= rondas; r++) {
          for (var i = 0; i < n; i++) {
            final ej = ejs[i];
            pasos.add(
              PasoRutina(
                fase: FasePaso.trabajo,
                duracion: (ej.trabajoSeg ?? 0) > 0 ? ej.trabajoSeg : null,
                estimado: trabajoEstimado(ej),
                ejercicio: ej,
                metodologia: m,
                bloque: indiceBloque,
                bloqueNombre: nombre,
                ronda: r,
                rondas: rondas,
                indice: i,
                total: n,
              ),
            );
            final esUltimo = i == n - 1;
            final d = ej.descansoSeg ?? 0;
            if (!esUltimo && d > 0) {
              pasos.add(
                PasoRutina(
                  fase: FasePaso.descanso,
                  duracion: d,
                  estimado: d,
                  ejercicio: ej,
                  siguiente: ejs[i + 1],
                  metodologia: m,
                  bloque: indiceBloque,
                  bloqueNombre: nombre,
                  ronda: r,
                  rondas: rondas,
                  indice: i,
                  total: n,
                ),
              );
            }
            if (esUltimo && r < rondas) {
              final dr = (bloque.descansoRondaSeg ?? 0) > 0
                  ? bloque.descansoRondaSeg!
                  : d;
              if (dr > 0) {
                pasos.add(
                  PasoRutina(
                    fase: FasePaso.descansoRonda,
                    duracion: dr,
                    estimado: dr,
                    ejercicio: ej,
                    siguiente: ejs.first,
                    metodologia: m,
                    bloque: indiceBloque,
                    bloqueNombre: nombre,
                    ronda: r,
                    rondas: rondas,
                    indice: i,
                    total: n,
                  ),
                );
              }
            }
          }
        }
        return pasos;
    }
  }

  /// Pasos de la sesión de un día: sus bloques en orden con el descanso
  /// entre ellos.
  static List<PasoRutina> expandirDia(List<PlanBloque> bloques) {
    final validos = bloques.where((b) => b.ejerciciosValidos.isNotEmpty).toList();
    final pasos = <PasoRutina>[];
    for (var i = 0; i < validos.length; i++) {
      final b = validos[i];
      pasos.addAll(expandirBloque(b, i));
      final d = b.descansoBloqueSeg ?? 0;
      if (i < validos.length - 1 && d > 0) {
        pasos.add(
          PasoRutina(
            fase: FasePaso.descansoBloque,
            duracion: d,
            estimado: d,
            siguiente: validos[i + 1].ejerciciosValidos.first,
            metodologia: b.metodologia,
            bloque: i,
            bloqueNombre: nombreBloque(b, i),
          ),
        );
      }
    }
    return pasos;
  }

  static int sumar(List<PasoRutina> pasos) =>
      pasos.fold(0, (s, p) => s + p.segundos);

  /// Duración estimada en segundos: la del día más largo.
  static int duracionEstimada(PlanRutina plan) =>
      plan.sesiones.fold(0, (max, s) => math.max(max, s.duracion));

  static int duracionBloque(PlanBloque b) => sumar(expandirBloque(b, 0));

  /// Mismas reglas que el backend, para avisar antes de enviar. Devuelve el
  /// primer error o null.
  static String? validar(PlanRutina plan) {
    if (plan.nombre.trim().isEmpty) return 'El nombre de la rutina es obligatorio';
    final bloques = plan.bloquesValidos;
    if (bloques.isEmpty) return 'Agrega al menos un ejercicio con nombre';
    for (var i = 0; i < bloques.length; i++) {
      final b = bloques[i];
      final m = b.metodologia;
      final etiqueta = '${b.diaSemana} ${nombreBloque(b, i)}'.trim();
      if (m.usa(CampoMetodologia.rondas) && (b.rondas < 1 || b.rondas > 50)) {
        return '$etiqueta: las rondas deben estar entre 1 y 50';
      }
      if (m.forma == FormaMetodologia.amrap && (b.tiempoLimiteSeg ?? 0) <= 0) {
        return '$etiqueta: el AMRAP necesita un tiempo límite';
      }
      final intervalo = (b.intervaloSeg ?? 0) > 0
          ? b.intervaloSeg!
          : intervaloEmomDefecto;
      if (m.forma == FormaMetodologia.emom) {
        if (intervalo < 10) {
          return '$etiqueta: el intervalo del EMOM debe ser de al menos 10 segundos';
        }
        if ((b.tiempoLimiteSeg ?? 0) > 0 && b.tiempoLimiteSeg! < intervalo) {
          return '$etiqueta: el tiempo total debe alcanzar al menos un intervalo';
        }
      }
      for (final e in b.ejerciciosValidos) {
        if ((e.trabajoSeg ?? 0) > 3600 || (e.descansoSeg ?? 0) > 3600) {
          return '${e.nombre}: los tiempos no pueden pasar de 60 minutos';
        }
        if (m.esSeries) continue;
        if (m.trabajoObligatorio && (e.trabajoSeg ?? 0) <= 0) {
          return '${e.nombre}: en ${m.texto} cada ejercicio necesita su tiempo de trabajo';
        }
        if ((e.trabajoSeg ?? 0) <= 0 && e.repeticiones <= 0) {
          return '${e.nombre}: indica el tiempo de trabajo o las repeticiones';
        }
        if (m.forma == FormaMetodologia.emom &&
            (e.trabajoSeg ?? 0) > intervalo) {
          return '${e.nombre}: el trabajo no puede durar más que el intervalo del EMOM';
        }
      }
    }
    return null;
  }
}

/// 615 -> "10:15"; 3725 -> "1:02:05"
String formatoReloj(num segundos) {
  final s = math.max(0, segundos.round());
  final h = s ~/ 3600;
  final m = (s % 3600) ~/ 60;
  final r = s % 60;
  String dd(int x) => x.toString().padLeft(2, '0');
  return h > 0 ? '$h:${dd(m)}:${dd(r)}' : '$m:${dd(r)}';
}

/// 615 -> "10 min 15 s"
String formatoDuracion(int segundos) {
  if (segundos <= 0) return '—';
  final h = segundos ~/ 3600;
  final m = (segundos % 3600) ~/ 60;
  final r = segundos % 60;
  return [
    if (h > 0) '$h h',
    if (m > 0) '$m min',
    if (r > 0 && h == 0) '$r s',
  ].join(' ');
}
