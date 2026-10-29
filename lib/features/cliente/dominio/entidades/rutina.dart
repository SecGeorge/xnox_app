import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';

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

  /// True si el administrador armó esta rutina para ESTE cliente. Sigue siendo
  /// de solo lectura, pero no la ve nadie más, así que se muestra aparte.
  final bool personalizada;

  /// Metodología de sus bloques (MUSCULACION, CIRCUITO, HIIT, EMOM, AMRAP,
  /// ESTACIONES) o MIXTO si combina. Las propias del socio son de musculación.
  final String tipo;
  final String? objetivo;
  final String? nivel;

  /// Duración estimada que calculó el backend (segundos).
  final int? duracionSeg;

  final List<DiaRutina> dias;

  Rutina({
    required this.id,
    this.servidorId,
    required this.nombre,
    this.descripcion = '',
    this.origen = OrigenRutina.cliente,
    this.personalizada = false,
    this.tipo = Metodologia.musculacion,
    this.objetivo,
    this.nivel,
    this.duracionSeg,
    List<DiaRutina>? dias,
  }) : dias = dias ?? [];

  /// True si viene del administrador (solo lectura): general o personalizada.
  bool get esSugerida => origen == OrigenRutina.admin;

  /// True si es una rutina general de la sucursal (la ven todos los clientes).
  bool get esGeneral => esSugerida && !personalizada;

  /// Todos los ejercicios de todos los días (para reportes y conteos).
  List<Ejercicio> get ejercicios => [for (final d in dias) ...d.ejercicios];

  int get totalEjercicios => ejercicios.length;

  /// Días distintos con entrenamiento (un día puede tener varios bloques).
  int get totalDias => {for (final d in dias) d.diaSemana}.length;

  Metodologia get metodologia => Metodologia.de(tipo);

  /// True si tiene bloques por tiempo/circuito: esos bloques se siguen con el
  /// temporizador de [PlanRutina] en vez de registrar series.
  bool get esFuncional => dias.any((d) => d.esFuncional);

  /// La rutina en el formato del motor del temporizador.
  PlanRutina get plan => PlanRutina(
    nombre: nombre,
    objetivo: objetivo,
    nivel: nivel,
    bloques: [for (final d in dias) d.plan],
  );

  /// Resumen de los días para mostrar en la tarjeta (ej. "Lunes · Miércoles").
  String get resumenDias =>
      dias.isEmpty ? 'Sin días' : dias.map((d) => d.diaSemana).join(' · ');
}
