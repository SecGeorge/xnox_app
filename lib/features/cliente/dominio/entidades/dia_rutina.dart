import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';

/// Un bloque de entrenamiento de un día de la rutina (ej. "Lunes") con sus
/// ejercicios. Un día puede tener varios bloques y cada uno su metodología
/// ([tipo]): musculación, circuito, HIIT, EMOM, AMRAP o estaciones.
class DiaRutina {
  final int id;
  final String diaSemana; // Lunes, Martes, ...
  final String tipo;
  final String? nombre;
  final int rondas;
  final int? descansoRondaSeg;
  final int? tiempoLimiteSeg;
  final int? intervaloSeg;
  final int? descansoBloqueSeg;
  final List<Ejercicio> ejercicios;

  DiaRutina({
    required this.id,
    required this.diaSemana,
    this.tipo = Metodologia.musculacion,
    this.nombre,
    this.rondas = 1,
    this.descansoRondaSeg,
    this.tiempoLimiteSeg,
    this.intervaloSeg,
    this.descansoBloqueSeg,
    List<Ejercicio>? ejercicios,
  }) : ejercicios = ejercicios ?? [];

  int get totalEjercicios => ejercicios.length;

  bool get esFuncional => !Metodologia.de(tipo).esSeries;

  PlanBloque get plan => PlanBloque(
    tipo: tipo,
    diaSemana: diaSemana,
    nombre: nombre,
    rondas: rondas,
    descansoRondaSeg: descansoRondaSeg,
    tiempoLimiteSeg: tiempoLimiteSeg,
    intervaloSeg: intervaloSeg,
    descansoBloqueSeg: descansoBloqueSeg,
    ejercicios: [
      for (final e in ejercicios)
        PlanEjercicio(
          nombre: e.nombre,
          series: e.series,
          repeticiones: e.repeticiones,
          trabajoSeg: e.trabajoSeg,
          pesoKg: e.pesoKg,
          descansoSeg: e.descansoSeg,
          tempoBajadaSeg: e.tempoBajadaSeg,
          tempoSubidaSeg: e.tempoSubidaSeg,
          velocidad: e.velocidad,
          observaciones: e.observaciones,
          imagenUrl: e.imagenUrl,
        ),
    ],
  );
}
