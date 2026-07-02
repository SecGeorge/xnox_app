/// Datos de cobro por Yape del negocio que ve el cliente al pagar.
class ConfigPagoYape {
  final String numero;
  final String titular;

  /// URL absoluta de la imagen del QR de Yape (o null si no se subió).
  final String? qrUrl;

  const ConfigPagoYape({
    required this.numero,
    required this.titular,
    this.qrUrl,
  });

  /// `true` si el negocio configuró al menos un número de Yape.
  bool get disponible => numero.trim().isNotEmpty;

  bool get tieneQr => (qrUrl ?? '').isNotEmpty;
}
