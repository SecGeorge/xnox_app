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

  // ----------------------------------------------------------- Pago por Yape
  /// Número de Yape del negocio al que pagan los clientes.
  final String yapeNumero;

  /// Nombre del titular de la cuenta Yape (como aparece en la app).
  final String yapeTitular;

  /// Ruta cruda de la imagen del QR de Yape (ej. "imagenes/yape/x.png").
  final String yapeQr;

  /// URL absoluta del QR de Yape lista para `Image.network`, o null si no hay.
  final String? yapeQrUrl;

  const DatosNegocio({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.direccion,
    required this.logo,
    this.logoUrl,
    this.yapeNumero = '',
    this.yapeTitular = '',
    this.yapeQr = '',
    this.yapeQrUrl,
  });

  factory DatosNegocio.vacio() => const DatosNegocio(
        nombre: '',
        telefono: '',
        direccion: '',
        logo: '',
      );

  /// `true` si el negocio ya configuró un número de Yape para cobrar.
  bool get tieneYape => yapeNumero.trim().isNotEmpty;

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
      yapeNumero: yapeNumero,
      yapeTitular: yapeTitular,
      yapeQr: yapeQr,
      yapeQrUrl: yapeQrUrl,
    );
  }
}
