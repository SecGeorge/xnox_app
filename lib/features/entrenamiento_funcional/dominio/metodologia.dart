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

/// Una metodología de rutina: musculación, circuito, HIIT, EMOM, AMRAP o
/// estaciones.
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
