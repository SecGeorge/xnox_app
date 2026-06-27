/// Una marca registrada por el cliente en un ejercicio (peso levantado en
/// una fecha dada). El historial de marcas permite ver su progreso.
class Marca {
  final DateTime fecha;
  final double peso; // kg

  /// Total de repeticiones (suma de todas las series). Se conserva para los
  /// reportes/gráficos de avance que ya dependían de este valor.
  final int repeticiones;

  /// Repeticiones realizadas en cada serie, por ejemplo [12, 10, 8, 8].
  final List<int> repsPorSerie;

  Marca({
    required this.fecha,
    required this.peso,
    required this.repeticiones,
    List<int>? repsPorSerie,
  }) : repsPorSerie = repsPorSerie ?? const [];

  /// Texto del desglose por serie, p. ej. "12 · 10 · 8 · 8".
  /// Si no hay desglose (marcas antiguas), muestra el total.
  String get repsTexto =>
      repsPorSerie.isNotEmpty ? repsPorSerie.join(' · ') : '$repeticiones';

  /// Cantidad de series con repeticiones registradas.
  int get cantidadSeries => repsPorSerie.length;
}
