/// Cliente al que se le emite el comprobante de una venta de tienda.
/// Se resuelve por DNI (boleta) o por RUC (factura) contra clientes.php, que
/// lo registra automáticamente si aún no existía.
class ClienteVenta {
  final int id;
  final String nombres;
  final String apellidoPaterno;
  final String apellidoMaterno;
  final String razonSocial;

  const ClienteVenta({
    required this.id,
    this.nombres = '',
    this.apellidoPaterno = '',
    this.apellidoMaterno = '',
    this.razonSocial = '',
  });

  /// Razón social para factura; nombre y apellidos para boleta.
  String get nombreCompleto {
    if (razonSocial.trim().isNotEmpty) return razonSocial.trim();
    return [nombres, apellidoPaterno, apellidoMaterno]
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .join(' ');
  }

  factory ClienteVenta.fromJson(Map<String, dynamic> json) => ClienteVenta(
        id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
        nombres: json['nombres']?.toString() ?? '',
        apellidoPaterno: json['apellido_paterno']?.toString() ?? '',
        apellidoMaterno: json['apellido_materno']?.toString() ?? '',
        razonSocial: json['razon_social']?.toString() ?? '',
      );
}

/// Resultado de una operación de venta/pedido contra el backend.
class ResultadoOperacion {
  final bool exito;
  final String mensaje;

  /// Id de la venta generada (solo en el registro de una venta).
  final int? ventaId;

  const ResultadoOperacion(this.exito, this.mensaje, {this.ventaId});
}
