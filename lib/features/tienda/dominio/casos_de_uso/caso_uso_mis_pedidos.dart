import 'package:xnox_app/features/tienda/dominio/entidades/pedido_cliente.dart';
import 'package:xnox_app/features/tienda/dominio/repositorios/repositorio_tienda.dart';

class CasoUsoMisPedidos {
  final RepositorioTienda repositorio;

  CasoUsoMisPedidos(this.repositorio);

  Future<List<PedidoCliente>> ejecutar() => repositorio.obtenerMisPedidos();
}
