import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';

/// Origen de una rutina:
/// - [admin]   rutina sugerida creada en el sistema web. Solo lectura en la app.
/// - [cliente] rutina propia del cliente. CRUD local (solo SQLite).
enum OrigenRutina { admin, cliente }

/// Una rutina de entrenamiento, compuesta por uno o varios días, cada uno con
/// su lista de ejercicios.
class Rutina {
  final int id; // id local (SQLite)
  final int? servidorId; // id en el backend (solo rutinas sugeridas)
  final String nombre;
  final String descripcion;
  final OrigenRutina origen;
  final List<DiaRutina> dias;

  Rutina({
    required this.id,
    this.servidorId,
    required this.nombre,
    this.descripcion = '',
    this.origen = OrigenRutina.cliente,
    List<DiaRutina>? dias,
  }) : dias = dias ?? [];

  /// True si es una rutina sugerida del administrador (solo lectura).
  bool get esSugerida => origen == OrigenRutina.admin;

  /// Todos los ejercicios de todos los días (para reportes y conteos).
  List<Ejercicio> get ejercicios =>
      [for (final d in dias) ...d.ejercicios];

  int get totalEjercicios => ejercicios.length;

  int get totalDias => dias.length;

  /// Resumen de los días para mostrar en la tarjeta (ej. "Lunes · Miércoles").
  String get resumenDias =>
      dias.isEmpty ? 'Sin días' : dias.map((d) => d.diaSemana).join(' · ');
}
