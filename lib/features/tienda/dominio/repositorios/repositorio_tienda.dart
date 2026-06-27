import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';

class ResultadoPedido {
  final bool exito;
  final String mensaje;
  const ResultadoPedido(this.exito, this.mensaje);
}

abstract class RepositorioTienda {
  /// Catálogo de productos del almacén activo de la sucursal del cliente.
  Future<CatalogoTienda> obtenerCatalogo();

  /// Registra un pedido pendiente con los items del carrito.
  Future<ResultadoPedido> crearPedido(int organizadorId, List<ItemCarrito> items);
}
