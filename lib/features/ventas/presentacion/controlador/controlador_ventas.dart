import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/presentacion/controlador/controlador_tienda.dart';
import 'package:xnox_app/features/ventas/datos/repositorio_ventas.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/cliente_venta.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/pedido_pendiente.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/tipo_pago.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/venta_realizada.dart';

/// Orquesta el punto de venta y los pedidos del admin. El catálogo se toma del
/// controlador de tienda (el mismo que usa el cliente) para no duplicar la
/// resolución de almacén y productos.
class ControladorVentas {
  final RepositorioVentas _repositorio;
  final ControladorTienda _tienda;

  ControladorVentas({RepositorioVentas? repositorio, ControladorTienda? tienda})
      : _repositorio = repositorio ?? RepositorioVentas(),
        _tienda = tienda ?? ControladorTienda();

  // Catálogo (compartido con la tienda del cliente).
  Future<CatalogoTienda> obtenerCatalogo() => _tienda.obtenerCatalogo();

  // Datos comunes.
  Future<List<TipoPago>> obtenerTiposPago() => _repositorio.obtenerTiposPago();
  Future<List<SesionCaja>> obtenerCajasAbiertas() =>
      _repositorio.obtenerCajasAbiertas();
  Future<ClienteVenta?> buscarClientePorDni(String dni) =>
      _repositorio.buscarClientePorDni(dni);
  Future<ClienteVenta?> buscarClientePorRuc(String ruc) =>
      _repositorio.buscarClientePorRuc(ruc);

  // Punto de venta.
  Future<ResultadoOperacion> registrarVenta({
    required int clienteId,
    required int organizadorId,
    required int tipoPagoId,
    required String tipoComprobante,
    required double totalPagar,
    required double montoEntregado,
    required List<ItemCarrito> items,
    int? cajaSesionId,
  }) =>
      _repositorio.registrarVenta(
        clienteId: clienteId,
        organizadorId: organizadorId,
        tipoPagoId: tipoPagoId,
        tipoComprobante: tipoComprobante,
        totalPagar: totalPagar,
        montoEntregado: montoEntregado,
        items: items,
        cajaSesionId: cajaSesionId,
      );

  // Historial de ventas ya registradas.
  Future<List<VentaRealizada>> obtenerVentas({
    DateTime? desde,
    DateTime? hasta,
  }) =>
      _repositorio.obtenerVentas(desde: desde, hasta: hasta);

  // Pedidos hechos desde la app.
  Future<List<PedidoPendiente>> obtenerPedidos() =>
      _repositorio.obtenerPedidos();
  Future<List<DetallePedido>> obtenerDetalle(int pedidoId) =>
      _repositorio.obtenerDetalle(pedidoId);
  Future<ResultadoOperacion> atenderPedido(int pedidoId, int tipoPagoId) =>
      _repositorio.atenderPedido(pedidoId, tipoPagoId);
  Future<ResultadoOperacion> validarPagoYape(int pedidoId, String codigo) =>
      _repositorio.validarPagoYape(pedidoId, codigo);
  Future<ResultadoOperacion> reactivarCodigoYape(String codigo) =>
      _repositorio.reactivarCodigoYape(codigo);
  Future<ResultadoOperacion> entregarPedido(int pedidoId) =>
      _repositorio.entregarPedido(pedidoId);
  Future<ResultadoOperacion> cancelarPedido(int pedidoId) =>
      _repositorio.cancelarPedido(pedidoId);
}
