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

  const EjercicioCatalogo({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.grupoMuscular,
    this.miembroId,
    this.imagenUrl,
  });

  bool get esPropio => miembroId != null && miembroId != 0;
}
