import 'package:flutter/material.dart';

/// Forma en que se recorre una metodología ([mixto] solo describe rutinas
/// que combinan varias; ningún bloque es mixto).
enum FormaMetodologia { series, circuito, emom, amrap, mixto }

/// Campos que usa cada metodología (el formulario muestra solo esos).
enum CampoMetodologia {
  diaSemana,
  nombreBloque,
  rondas,
  descansoRonda,
  tiempoLimite,
  intervalo,
  descansoBloque,
  series,
  trabajo,
  repeticiones,
  peso,
  descanso,
}

/// Una metodología de rutina: musculación, circuito, HIIT, EMOM, AMRAP,
/// estaciones, calentamiento, movilidad, estabilidad o core.
///
/// Es el espejo de `src/components/Rutinas/metodologias.js` (web) y de
/// `RutinaMetodologia.php` (backend): los tres calculan la duración igual.
/// Para sumar una metodología nueva basta con agregarla a [todas]; si no se
/// recorre como un circuito, darle su forma en el motor.
class Metodologia {
  final String valor;
  final String texto;
  final IconData icono;
  final Color color;
  final FormaMetodologia forma;
  final String ayuda;
  final Set<CampoMetodologia> campos;
  final bool trabajoObligatorio;
  final String etiquetaDescanso;
  final String etiquetaBloque;
  final String etiquetaRondas;
  final String etiquetaEjercicio;

  /// Rondas con las que nace un bloque nuevo.
  final int rondasDefecto;

  /// Preparación: no consume el máximo de ejercicios por día del nivel.
  final bool sinLimite;

  /// Tipo de ejercicio que el bloque ofrece al elegir del catálogo.
  final String? tipoEjercicio;

  const Metodologia({
    required this.valor,
    required this.texto,
    required this.icono,
    required this.color,
    required this.forma,
    required this.ayuda,
    required this.campos,
    this.trabajoObligatorio = false,
    this.etiquetaDescanso = 'Descanso (s)',
    this.etiquetaBloque = 'Bloque',
    this.etiquetaRondas = 'Rondas',
    this.etiquetaEjercicio = 'Ejercicio',
    this.rondasDefecto = 3,
    this.sinLimite = false,
    this.tipoEjercicio,
  });

  bool usa(CampoMetodologia c) => campos.contains(c);

  bool get esSeries => forma == FormaMetodologia.series;

  static const musculacion = 'MUSCULACION';

  static const _circuito = {
    CampoMetodologia.nombreBloque,
    CampoMetodologia.rondas,
    CampoMetodologia.descansoRonda,
    CampoMetodologia.descansoBloque,
    CampoMetodologia.trabajo,
    CampoMetodologia.repeticiones,
    CampoMetodologia.descanso,
  };

  static const List<Metodologia> todas = [
    Metodologia(
      valor: 'MUSCULACION',
      texto: 'Musculación',
      icono: Icons.fitness_center_rounded,
      color: Color(0xFF1E3A5F),
      forma: FormaMetodologia.series,
      ayuda: 'Series, repeticiones, peso y descanso entre series.',
      campos: {
        CampoMetodologia.nombreBloque,
        CampoMetodologia.descansoBloque,
        CampoMetodologia.series,
        CampoMetodologia.repeticiones,
        CampoMetodologia.peso,
        CampoMetodologia.descanso,
      },
      etiquetaDescanso: 'Descanso entre series (s)',
      etiquetaBloque: 'Musculación',
    ),
    Metodologia(
      valor: 'CIRCUITO',
      texto: 'Circuito funcional',
      icono: Icons.loop_rounded,
      color: Color(0xFF0F766E),
      forma: FormaMetodologia.circuito,
      ayuda:
          'Secuencia de ejercicios que se repite por rondas, por tiempo, por repeticiones o ambos.',
      campos: _circuito,
      etiquetaDescanso: 'Descanso después (s)',
      etiquetaBloque: 'Circuito',
    ),
    Metodologia(
      valor: 'HIIT',
      texto: 'HIIT',
      icono: Icons.bolt_rounded,
      color: Color(0xFFDC2626),
      forma: FormaMetodologia.circuito,
      ayuda:
          'Intervalos de trabajo intenso y recuperación. Todos los ejercicios llevan tiempo de trabajo.',
      campos: _circuito,
      trabajoObligatorio: true,
      etiquetaDescanso: 'Recuperación (s)',
    ),
    Metodologia(
      valor: 'EMOM',
      texto: 'EMOM',
      icono: Icons.av_timer_rounded,
      color: Color(0xFF7C3AED),
      forma: FormaMetodologia.emom,
      ayuda:
          'Every Minute On the Minute: al inicio de cada intervalo se hace la tarea y se descansa lo que sobre.',
      campos: {
        CampoMetodologia.nombreBloque,
        CampoMetodologia.tiempoLimite,
        CampoMetodologia.intervalo,
        CampoMetodologia.descansoBloque,
        CampoMetodologia.trabajo,
        CampoMetodologia.repeticiones,
      },
    ),
    Metodologia(
      valor: 'AMRAP',
      texto: 'AMRAP',
      icono: Icons.all_inclusive_rounded,
      color: Color(0xFFEA580C),
      forma: FormaMetodologia.amrap,
      ayuda:
          'As Many Rounds As Possible: tantas rondas de la secuencia como se pueda dentro del tiempo límite.',
      campos: {
        CampoMetodologia.nombreBloque,
        CampoMetodologia.tiempoLimite,
        CampoMetodologia.descansoBloque,
        CampoMetodologia.repeticiones,
      },
    ),
    Metodologia(
      valor: 'ESTACIONES',
      texto: 'Por estaciones',
      icono: Icons.alt_route_rounded,
      color: Color(0xFF0369A1),
      forma: FormaMetodologia.circuito,
      ayuda:
          'Cada ejercicio es una estación: se trabaja un tiempo en cada una y se rota a la siguiente.',
      campos: _circuito,
      etiquetaDescanso: 'Rotación (s)',
      etiquetaBloque: 'Estaciones',
      etiquetaRondas: 'Vueltas',
      etiquetaEjercicio: 'Estación',
    ),
    Metodologia(
      valor: 'CALENTAMIENTO',
      texto: 'Calentamiento',
      icono: Icons.local_fire_department_rounded,
      color: Color(0xFFD97706),
      forma: FormaMetodologia.circuito,
      ayuda: 'Activación antes de entrenar: ejercicios suaves por tiempo o repeticiones.',
      campos: _circuito,
      etiquetaDescanso: 'Descanso después (s)',
      etiquetaBloque: 'Calentamiento',
      rondasDefecto: 1,
      sinLimite: true,
    ),
    Metodologia(
      valor: 'MOVILIDAD',
      texto: 'Movilidad',
      icono: Icons.self_improvement_rounded,
      color: Color(0xFF059669),
      forma: FormaMetodologia.circuito,
      ayuda: 'Rango de movimiento de las articulaciones, con posiciones sostenidas por tiempo.',
      campos: _circuito,
      etiquetaDescanso: 'Descanso después (s)',
      etiquetaBloque: 'Movilidad',
      rondasDefecto: 1,
      sinLimite: true,
      tipoEjercicio: 'MOVILIDAD',
    ),
    Metodologia(
      valor: 'ESTABILIDAD',
      texto: 'Estabilidad',
      icono: Icons.balance_rounded,
      color: Color(0xFF4F46E5),
      forma: FormaMetodologia.circuito,
      ayuda: 'Equilibrio y control del cuerpo, por tiempo o repeticiones.',
      campos: _circuito,
      etiquetaDescanso: 'Descanso después (s)',
      etiquetaBloque: 'Estabilidad',
      tipoEjercicio: 'ESTABILIDAD',
    ),
    Metodologia(
      valor: 'CORE',
      texto: 'Core',
      icono: Icons.adjust_rounded,
      color: Color(0xFFBE123C),
      forma: FormaMetodologia.circuito,
      ayuda: 'Abdomen, zona lumbar y cadera, por tiempo o repeticiones.',
      campos: _circuito,
      etiquetaDescanso: 'Descanso después (s)',
      etiquetaBloque: 'Core',
      tipoEjercicio: 'CORE',
    ),
  ];

  /// Tipo de la rutina cuando sus bloques combinan metodologías.
  static const mixto = Metodologia(
    valor: 'MIXTO',
    texto: 'Mixta',
    icono: Icons.shuffle_rounded,
    color: Color(0xFF475569),
    forma: FormaMetodologia.mixto,
    ayuda: 'Combina varios tipos de entrenamiento en la semana.',
    campos: {},
  );

  static Metodologia de(String? valor) => (valor ?? '').toUpperCase() == 'MIXTO'
      ? mixto
      : todas.firstWhere(
    (m) => m.valor == (valor ?? '').toUpperCase(),
    orElse: () => todas.first,
  );
}

const diasSemana = [
  'Lunes',
  'Martes',
  'Miércoles',
  'Jueves',
  'Viernes',
  'Sábado',
  'Domingo',
];

const nivelesRutina = {
  'PRINCIPIANTE': 'Principiante',
  'INTERMEDIO': 'Intermedio',
  'AVANZADO': 'Avanzado',
};

/// Tipo de un ejercicio del catálogo.
const tiposEjercicio = {
  'AISLADO': 'Aislado',
  'COMPUESTO': 'Compuesto',
  'CORE': 'Core',
  'MOVILIDAD': 'Movilidad',
  'ESTABILIDAD': 'Estabilidad',
};

/// Un tramo de la escala de esfuerzo.
class BandaRpe {
  final int desde;
  final int hasta;
  final String texto;
  final String detalle;
  final Color color;

  const BandaRpe(this.desde, this.hasta, this.texto, this.detalle, this.color);
}

/// Esfuerzo objetivo de un ejercicio: escala de Borg CR10, del 1 al 10.
class Rpe {
  static const bandas = [
    BandaRpe(1, 2, 'Muy ligero', 'Reposo, paseo suave', Color(0xFF059669)),
    BandaRpe(3, 4, 'Ligero a moderado', 'Conversación cómoda', Color(0xFF65A30D)),
    BandaRpe(5, 6, 'Moderado', 'Conversación algo entrecortada', Color(0xFFD97706)),
    BandaRpe(7, 8, 'Fuerte', 'Difícil mantener una conversación larga', Color(0xFFEA580C)),
    BandaRpe(9, 10, 'Muy fuerte a máximo', 'Incapaz de hablar, fatiga extrema', Color(0xFFDC2626)),
  ];

  static BandaRpe? banda(int? rpe) {
    for (final b in bandas) {
      if (rpe != null && rpe >= b.desde && rpe <= b.hasta) return b;
    }
    return null;
  }

  /// "RPE 7 · Fuerte" (vacío sin RPE).
  static String texto(int? rpe) {
    final b = banda(rpe);
    return b == null ? '' : 'RPE $rpe · ${b.texto}';
  }
}
