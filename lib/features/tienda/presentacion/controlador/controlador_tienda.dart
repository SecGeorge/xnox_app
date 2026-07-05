import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/tienda/datos/repositorios/repositorio_tienda_impl.dart';
import 'package:xnox_app/features/tienda/dominio/casos_de_uso/caso_uso_catalogo.dart';
import 'package:xnox_app/features/tienda/dominio/casos_de_uso/caso_uso_crear_pedido.dart';
import 'package:xnox_app/features/tienda/dominio/casos_de_uso/caso_uso_mis_pedidos.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/pedido_cliente.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/dominio/repositorios/repositorio_tienda.dart';

class ControladorTienda {
  final CasoUsoCatalogo _casoUsoCatalogo;
  final CasoUsoCrearPedido _casoUsoCrearPedido;
  final CasoUsoMisPedidos _casoUsoMisPedidos;

  ControladorTienda()
      : _casoUsoCatalogo =
            CasoUsoCatalogo(RepositorioTiendaImpl(HttpService())),
        _casoUsoCrearPedido =
            CasoUsoCrearPedido(RepositorioTiendaImpl(HttpService())),
        _casoUsoMisPedidos =
            CasoUsoMisPedidos(RepositorioTiendaImpl(HttpService()));

  Future<CatalogoTienda> obtenerCatalogo() => _casoUsoCatalogo.ejecutar();

  Future<ResultadoPedido> crearPedido(
          int organizadorId, List<ItemCarrito> items) =>
      _casoUsoCrearPedido.ejecutar(organizadorId, items);

  Future<List<PedidoCliente>> obtenerMisPedidos() =>
      _casoUsoMisPedidos.ejecutar();
}
