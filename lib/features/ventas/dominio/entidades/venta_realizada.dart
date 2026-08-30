/// Una venta ya registrada (ventas.php, método `obtener`). Incluye tanto las
/// ventas de mostrador como las generadas al cobrar un pedido de la app.
class VentaRealizada {
  final int id;
  final String codigo;
  final String cliente;
  final String dni;
  final String fecha;
  final String tipoPago;

  /// Usuario que registró la venta.
  final String usuario;
  final double montoTotal;

  /// 1 = realizada · 0 = anulada.
  final int estado;

  /// Productos de la venta: el backend ya los devuelve dentro de cada venta,
  /// así que no hace falta una segunda petición para el detalle.
  final List<DetalleVenta> detalle;

  const VentaRealizada({
    required this.id,
    required this.codigo,
    required this.cliente,
    required this.dni,
    required this.fecha,
    required this.tipoPago,
    required this.usuario,
    required this.montoTotal,
    required this.estado,
    required this.detalle,
  });

  bool get anulada => estado == 0;

  String get inicial =>
      cliente.trim().isEmpty ? '?' : cliente.trim()[0].toUpperCase();

  factory VentaRealizada.fromJson(Map<String, dynamic> json) {
    final detalleRaw = json['detalle'];
    final detalle = (detalleRaw is List)
        ? detalleRaw
            .whereType<Map>()
            .map((d) => DetalleVenta.fromJson(Map<String, dynamic>.from(d)))
            .toList()
        : <DetalleVenta>[];

    return VentaRealizada(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      codigo: json['codigo']?.toString() ?? '',
      cliente: json['cliente']?.toString().trim() ?? '',
      dni: json['dni']?.toString() ?? '',
      fecha: json['fecha']?.toString() ?? '',
      tipoPago: json['tipo_pago']?.toString() ?? '',
      usuario: json['usuario']?.toString() ?? '',
      montoTotal: double.tryParse(json['monto_total']?.toString() ?? '') ?? 0,
      estado: int.tryParse(json['estado']?.toString() ?? '') ?? 0,
      detalle: detalle,
    );
  }
}

/// Una línea de la venta (producto, cantidad y precio cobrado).
class DetalleVenta {
  final String nombre;
  final double cantidad;
  final double precio;
  final double total;
  final String unidadMedida;

  const DetalleVenta({
    required this.nombre,
    required this.cantidad,
    required this.precio,
    required this.total,
    required this.unidadMedida,
  });

  factory DetalleVenta.fromJson(Map<String, dynamic> json) {
    double aDouble(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
    return DetalleVenta(
      nombre: json['nombre']?.toString() ?? '',
      cantidad: aDouble(json['cantidad']),
      precio: aDouble(json['precio_producto']),
      total: aDouble(json['total']),
      unidadMedida: json['unidad_medida_nombre']?.toString() ?? '',
    );
  }
}
