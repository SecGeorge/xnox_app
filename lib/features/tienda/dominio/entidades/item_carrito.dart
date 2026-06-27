import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';

/// Una línea del carrito de compra del cliente.
class ItemCarrito {
  final int productoId;
  final String codigo;
  final String nombre;
  final String imagen;
  final int unidadMedidaId;
  final String unidadNombre;
  final double precio;
  final double stock;
  int cantidad;

  ItemCarrito({
    required this.productoId,
    required this.codigo,
    required this.nombre,
    required this.imagen,
    required this.unidadMedidaId,
    required this.unidadNombre,
    required this.precio,
    required this.stock,
    this.cantidad = 1,
  });

  /// Clave única por producto + unidad.
  String get clave => '$productoId-$unidadMedidaId';

  double get subtotal => precio * cantidad;

  factory ItemCarrito.desdeProducto(ProductoTienda p) {
    final u = p.unidadPrincipal!;
    return ItemCarrito(
      productoId: p.id,
      codigo: p.codigo,
      nombre: p.nombre,
      imagen: p.imagen,
      unidadMedidaId: u.unidadMedidaId,
      unidadNombre: u.unidadMedida,
      precio: u.precioVenta,
      stock: u.stockActual,
    );
  }

  Map<String, dynamic> aJsonPedido() => {
        'id': productoId,
        'producto_nombre': nombre,
        'codigo': codigo,
        'unidad_medida_id': unidadMedidaId,
        'unidad_nombre': unidadNombre,
        'cantidad': cantidad,
        'precio': precio,
      };
}
