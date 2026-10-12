/// Una marca registrada por el cliente en un ejercicio (peso levantado en
/// una fecha dada). El historial de marcas permite ver su progreso.
class Marca {
  /// Id de la fila en SQLite (la sesión). Null en marcas derivadas/demo.
  final int? id;

  final DateTime fecha;
  /// Carga de la sesión en kg: la más alta de sus series (la que cuenta para
  /// el récord y las gráficas).
  final double peso;

  /// Total de repeticiones (suma de todas las series). Se conserva para los
  /// reportes/gráficos de avance que ya dependían de este valor.
  final int repeticiones;

  /// Repeticiones realizadas en cada serie, por ejemplo [12, 10, 8, 8].
  final List<int> repsPorSerie;

  /// Peso usado en cada serie (mismo orden que [repsPorSerie]); cada serie
  /// puede llevar una carga distinta.
  final List<double> pesoPorSerie;

  /// Repeticiones por lado de cada serie (mismo orden que [repsPorSerie]);
  /// null en las series hechas con ambos lados a la vez.
  final List<int?> repsIzqPorSerie;
  final List<int?> repsDerPorSerie;

  Marca({
    this.id,
    required this.fecha,
    required this.peso,
    required this.repeticiones,
    List<int>? repsPorSerie,
    List<double>? pesoPorSerie,
    List<int?>? repsIzqPorSerie,
    List<int?>? repsDerPorSerie,
  }) : repsPorSerie = repsPorSerie ?? const [],
       pesoPorSerie = pesoPorSerie ?? const [],
       repsIzqPorSerie = repsIzqPorSerie ?? const [],
       repsDerPorSerie = repsDerPorSerie ?? const [];

  /// Repeticiones (izquierdo, derecho) de la serie [i], o null si se hizo con
  /// ambos lados a la vez.
  (int, int)? ladosDeSerie(int i) {
    final izq = i < repsIzqPorSerie.length ? repsIzqPorSerie[i] : null;
    final der = i < repsDerPorSerie.length ? repsDerPorSerie[i] : null;
    return izq == null || der == null ? null : (izq, der);
  }

  /// Texto de una serie: "10" o, si fue unilateral, "I10/D9".
  String textoSerie(int i) {
    final lados = ladosDeSerie(i);
    if (lados != null) return 'I${lados.$1}/D${lados.$2}';
    return i < repsPorSerie.length ? '${repsPorSerie[i]}' : '';
  }

  /// Peso de la serie [i] (0-based); si no se guardó, el de la sesión.
  double pesoDeSerie(int i) =>
      i < pesoPorSerie.length ? pesoPorSerie[i] : peso;

  /// True si la sesión es de hoy (la única editable serie por serie).
  bool get esHoy {
    final h = DateTime.now();
    return fecha.year == h.year && fecha.month == h.month && fecha.day == h.day;
  }

  /// Texto del desglose por serie, p. ej. "12 · 10 · 8 · 8".
  /// Si no hay desglose (marcas antiguas), muestra el total.
  String get repsTexto => repsPorSerie.isNotEmpty
      ? [for (var i = 0; i < repsPorSerie.length; i++) textoSerie(i)].join(' · ')
      : '$repeticiones';

  /// Cantidad de series con repeticiones registradas.
  int get cantidadSeries => repsPorSerie.length;
}
