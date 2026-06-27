/// Datos del negocio configurables (tabla `ajustes` en el backend).
/// Provienen de `ajustes.php` -> método `obtener`.
class DatosNegocio {
  final int? id;
  final String nombre;
  final String telefono;
  final String direccion;

  /// Ruta cruda del logo tal como la guarda el backend (ej. "imagenes/logo/x.png").
  final String logo;

  /// URL absoluta lista para mostrar en un `Image.network`, o null si no hay logo.
  final String? logoUrl;

  const DatosNegocio({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.logo,
    this.logoUrl,
  });

  factory DatosNegocio.vacio() => const DatosNegocio(
        nombre: '',
        telefono: '',
        direccion: '',
        logo: '',
      );

  DatosNegocio copyWith({
    String? nombre,
    String? telefono,
    String? direccion,
  }) {
    return DatosNegocio(
      id: id,
      nombre: nombre ?? this.nombre,
      telefono: telefono ?? this.telefono,
      direccion: direccion ?? this.direccion,
      logo: logo,
      logoUrl: logoUrl,
    );
  }
}
