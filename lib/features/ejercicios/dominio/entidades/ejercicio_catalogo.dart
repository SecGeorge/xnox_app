/// Un ejercicio del catálogo del gimnasio (tabla `ejercicio` del backend).
///
/// Es lo que la app autocompleta cuando el cliente agrega un ejercicio a su
/// rutina. No confundir con [Ejercicio], que es el ejercicio YA colocado dentro
/// de un día de una rutina (con sus series, reps y marcas).
///
/// `miembroId` distingue el ámbito:
///   null  -> catálogo general del gimnasio (lo arma el admin en el web)
///   valor -> ejercicio privado de ese cliente, creado desde la app
class EjercicioCatalogo {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? grupoMuscular;
  final int? miembroId;

  /// URL absoluta de la portada, ya resuelta contra el servidor de la empresa.
  final String? imagenUrl;

  /// URL absoluta del video de ejecución que subió el gimnasio (opcional).
  final String? videoUrl;

  /// Galería completa (URLs absolutas, en el orden que fijó el gimnasio).
  ///
  /// Solo viene llena al pedir el ejercicio con `obtener`: la búsqueda y el
  /// listado devuelven únicamente la portada, así que ahí queda vacía.
  final List<String> imagenes;

  const EjercicioCatalogo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.grupoMuscular,
    this.miembroId,
    this.imagenUrl,
    this.videoUrl,
    this.imagenes = const [],
  });

  bool get esPropio => miembroId != null && miembroId != 0;

  bool get tieneVideo => (videoUrl ?? '').isNotEmpty;
}
