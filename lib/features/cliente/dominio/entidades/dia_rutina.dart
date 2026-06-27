import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';

/// Un día de entrenamiento dentro de una rutina (ej. "Lunes") con sus
/// ejercicios asignados.
class DiaRutina {
  final int id;
  final String diaSemana; // Lunes, Martes, ...
  final List<Ejercicio> ejercicios;

  DiaRutina({
    required this.id,
    required this.diaSemana,
    List<Ejercicio>? ejercicios,
  }) : ejercicios = ejercicios ?? [];

  int get totalEjercicios => ejercicios.length;
}
