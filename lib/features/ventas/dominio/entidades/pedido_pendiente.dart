/// Un pedido hecho por un cliente desde la app y que el admin todavía no cobra.
/// Es la misma lista que el web muestra en "Ventas > Pedidos pendientes"
/// (pedidos.php, método `obtener`).
class PedidoPendiente {
  final int id;
  final String codigo;
  final int miembroId;

  /// Nombre completo del miembro que hizo el pedido.
  final String cliente;

  /// Código del miembro (el backend lo devuelve como `dni`).
  final String dni;
  final double montoTotal;

  /// 0 = pendiente · 1 = atendido/vendido.
  final int estado;

  /// 1 = canje por puntos (se entrega, no se cobra).
  final int tipo;
  final String fecha;
  final int items;

  const PedidoPendiente({
    required this.id,
    required this.codigo,
    required this.miembroId,
    required this.cliente,
    required this.dni,
    required this.montoTotal,
    required this.estado,
    required this.tipo,
    required this.fecha,
    required this.items,
  });

  /// Un pedido de canje ya se pagó con puntos: solo se entrega.
  bool get esCanje => tipo == 1;

  /// Inicial para el avatar de la lista.
  String get inicial =>
      cliente.trim().isEmpty ? '?' : cliente.trim()[0].toUpperCase();

  factory PedidoPendiente.fromJson(Map<String, dynamic> json) {
    return PedidoPendiente(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      miembroId: int.tryParse(json['miembro_id']?.toString() ?? '') ?? 0,
      cliente: json['cliente']?.toString() ?? '',
      dni: json['dni']?.toString() ?? '',
      montoTotal: double.tryParse(json['monto_total']?.toString() ?? '') ?? 0,
      estado: int.tryParse(json['estado']?.toString() ?? '') ?? 0,
      tipo: int.tryParse(json['tipo']?.toString() ?? '') ?? 0,
      fecha: json['fecha_creacion']?.toString() ?? '',
      items: int.tryParse(json['items']?.toString() ?? '') ?? 0,
    );
  }
}

/// Una línea del detalle de un pedido (pedidos.php, método `detalle`).
class DetallePedido {
  final String productoNombre;
  final double cantidad;
  final double precio;
  final String unidadNombre;
  final double subtotal;

  const DetallePedido({
    required this.productoNombre,
    required this.cantidad,
    required this.precio,
    required this.unidadNombre,
    required this.subtotal,
  });

  factory DetallePedido.fromJson(Map<String, dynamic> json) {
    double aDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return DetallePedido(
      productoNombre: json['producto_nombre']?.toString() ?? '',
      cantidad: aDouble(json['cantidad']),
      precio: aDouble(json['precio']),
      unidadNombre: json['unidad_nombre']?.toString() ?? '',
      subtotal: aDouble(json['subtotal']),
    );
  }
}
