import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';

/// Un ejercicio dentro de una rutina, con su historial de marcas (PR).
class Ejercicio {
  final int id;
  final String nombre;
  final int series;
  final int repeticiones;
  final List<Marca> marcas;

  Ejercicio({
    required this.id,
    required this.nombre,
    required this.series,
    required this.repeticiones,
    List<Marca>? marcas,
  }) : marcas = marcas ?? [];

  /// Mejor marca histórica (mayor peso) = récord personal.
  Marca? get mejorMarca {
    if (marcas.isEmpty) return null;
    return marcas.reduce((a, b) => a.peso >= b.peso ? a : b);
  }

  /// Última marca registrada por fecha.
  Marca? get ultimaMarca {
    if (marcas.isEmpty) return null;
    return marcas.reduce((a, b) => a.fecha.isAfter(b.fecha) ? a : b);
  }

  /// Marcas ordenadas cronológicamente (para gráficos de progreso).
  List<Marca> get marcasOrdenadas {
    final lista = [...marcas]..sort((a, b) => a.fecha.compareTo(b.fecha));
    return lista;
  }
}
