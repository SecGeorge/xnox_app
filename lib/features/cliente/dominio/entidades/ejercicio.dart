import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';

/// Un ejercicio dentro de un día de una rutina, con su historial de marcas (PR).
class Ejercicio {
  final int id;
  final String nombre;
  final int series;
  final int repeticiones;
  final String? observaciones;
  final List<Marca> marcas;

  /// Id del ejercicio en el catálogo del gimnasio, si se eligió de ahí.
  /// Null cuando el nombre se escribió a mano y no se pudo catalogar.
  final int? catalogoId;

  /// URL absoluta de la imagen de referencia (la portada del catálogo).
  final String? imagenUrl;

  /// URL absoluta del video de ejecución que subió el gimnasio, si lo tiene.
  final String? videoUrl;

  Ejercicio({
    required this.id,
    required this.nombre,
    required this.series,
    required this.repeticiones,
    this.observaciones,
    this.catalogoId,
    this.imagenUrl,
    this.videoUrl,
    List<Marca>? marcas,
  }) : marcas = marcas ?? [];

  bool get tieneVideo => (videoUrl ?? '').isNotEmpty;

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

  /// Marca de la sesión anterior (penúltima por fecha), para comparar el avance.
  Marca? get marcaAnterior {
    if (marcas.length < 2) return null;
    final ord = marcasOrdenadas;
    return ord[ord.length - 2];
  }
}
