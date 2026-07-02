import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';

class ResultadoPedido {
  final bool exito;
  final String mensaje;

  /// Id y código del pedido creado (disponibles solo cuando [exito] es true).
  final int? pedidoId;
  final String? codigo;

  /// Total del pedido recién creado (para mostrar en el pago).
  final double total;

  const ResultadoPedido(
    this.exito,
    this.mensaje, {
    this.pedidoId,
    this.codigo,
    this.total = 0,
  });
}

abstract class RepositorioTienda {
  /// Catálogo de productos del almacén activo de la sucursal del cliente.
  Future<CatalogoTienda> obtenerCatalogo();

  /// Registra un pedido pendiente con los items del carrito.
  Future<ResultadoPedido> crearPedido(int organizadorId, List<ItemCarrito> items);
}
