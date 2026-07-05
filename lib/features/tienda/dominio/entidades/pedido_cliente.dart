/// Un pedido del cliente tal como lo lista la app (para elegir cuál pagar y ver
/// su estado). Estados del backend: 0 = pendiente, 1 = atendido/vendido.
class PedidoCliente {
  final int id;
  final String codigo;
  final double total;

  /// 0 = pendiente de pago · 1 = vendido (ya pagado/atendido).
  final int estado;
  final int items;
  final String fecha;
  final int? ventaId;

  const PedidoCliente({
    required this.id,
    required this.codigo,
    required this.total,
    required this.estado,
    required this.items,
    required this.fecha,
    this.ventaId,
  });

  bool get pendiente => estado == 0;
  bool get vendido => estado == 1;

  factory PedidoCliente.fromJson(Map<String, dynamic> json) {
    return PedidoCliente(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      total: double.tryParse(json['monto_total']?.toString() ?? '') ?? 0,
      estado: int.tryParse(json['estado']?.toString() ?? '') ?? 0,
      items: int.tryParse(json['items']?.toString() ?? '') ?? 0,
      fecha: json['fecha_creacion']?.toString() ?? '',
      ventaId: int.tryParse(json['venta_id']?.toString() ?? ''),
    );
  }
}
