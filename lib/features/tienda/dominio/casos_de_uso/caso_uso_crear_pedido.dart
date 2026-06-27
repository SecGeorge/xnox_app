import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/repositorios/repositorio_tienda.dart';

class CasoUsoCrearPedido {
  final RepositorioTienda repositorio;

  CasoUsoCrearPedido(this.repositorio);

  Future<ResultadoPedido> ejecutar(int organizadorId, List<ItemCarrito> items) =>
      repositorio.crearPedido(organizadorId, items);
}
