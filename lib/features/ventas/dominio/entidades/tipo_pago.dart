/// Método de pago configurado en el sistema (tipo_pago.php).
class TipoPago {
  final int id;
  final String nombre;

  const TipoPago({required this.id, required this.nombre});

  /// Yape necesita validar el código de verificación del comprobante antes de
  /// generar la venta (mismo criterio que el web: se busca por nombre).
  bool get esYape => nombre.toLowerCase().contains('yape');

  bool get esEfectivo => nombre.toLowerCase().contains('efectivo');

  factory TipoPago.fromJson(Map<String, dynamic> json) => TipoPago(
        id: int.tryParse(json['tipo_pago_id']?.toString() ?? '') ?? 0,
        nombre: json['nombre']?.toString() ?? '',
      );
}

/// Un turno de caja abierto en la sucursal (caja.php, `sesiones_abiertas`).
/// La venta se estampa con el id de la caja elegida.
class SesionCaja {
  final int id;
  final String cajaCodigo;
  final String cajero;

  const SesionCaja({
    required this.id,
    required this.cajaCodigo,
    required this.cajero,
  });

  String get etiqueta =>
      '${cajaCodigo.isEmpty ? 'Caja' : cajaCodigo} — ${cajero.isEmpty ? 'cajero' : cajero}';

  factory SesionCaja.fromJson(Map<String, dynamic> json) => SesionCaja(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        cajaCodigo: json['caja_codigo']?.toString() ??
            'Caja ${json['caja_id'] ?? ''}'.trim(),
        cajero: json['cajero']?.toString() ?? '',
      );
}
