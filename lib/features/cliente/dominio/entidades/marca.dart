/// Una marca registrada por el cliente en un ejercicio (peso levantado en
/// una fecha dada). El historial de marcas permite ver su progreso.
class Marca {
  final DateTime fecha;
  final double peso; // kg
  final int repeticiones;

  Marca({
    required this.fecha,
    required this.peso,
    required this.repeticiones,
  });
}
