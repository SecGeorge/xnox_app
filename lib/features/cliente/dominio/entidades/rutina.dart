import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';

/// Una rutina de entrenamiento del cliente (un día / grupo muscular).
class Rutina {
  final int id;
  final String nombre;
  final String dia; // ej. "Lunes — Pecho y tríceps"
  final List<Ejercicio> ejercicios;

  Rutina({
    required this.id,
    required this.nombre,
    required this.dia,
    List<Ejercicio>? ejercicios,
  }) : ejercicios = ejercicios ?? [];

  int get totalEjercicios => ejercicios.length;
}
