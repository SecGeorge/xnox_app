import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/cliente_venta.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/pedido_pendiente.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/tipo_pago.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/venta_realizada.dart';

/// Acceso al backend de ventas de tienda para el ADMIN: registrar una venta
/// directa (punto de venta) y gestionar los pedidos que llegan de la app.
///
/// Reutiliza exactamente los mismos endpoints del panel web
/// (`TiendaProducto.vue` / `VentaActual.vue` / `PedidosPendientes.vue`), así el
/// stock, la caja, los puntos y los comprobantes se comportan igual en ambos.
class RepositorioVentas {
  final HttpService _http;

  RepositorioVentas([HttpService? http]) : _http = http ?? HttpService();

  Future<int> _sucursalId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
  }

  Future<String> _usuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('idUsuario') ?? '';
  }

  /// Lee `datos` de una respuesta del backend como lista de mapas.
  List<Map<String, dynamic>> _lista(dynamic resp) {
    final datos = (resp is Map) ? resp['datos'] : null;
    if (datos is! List) return const [];
    return datos
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  /// Interpreta la respuesta estándar del backend (`success` / `warning`).
  ResultadoOperacion _resultado(dynamic resp, String mensajeDefecto) {
    if (resp is Map && resp['success'] == true) {
      return ResultadoOperacion(
        true,
        resp['mensaje']?.toString() ?? mensajeDefecto,
      );
    }
    final mensaje = (resp is Map)
        ? (resp['mensaje']?.toString() ??
            resp['error']?.toString() ??
            'No se pudo completar la operación')
        : 'No se pudo completar la operación';
    return ResultadoOperacion(false, mensaje);
  }

  // ------------------------------------------------------------ Datos comunes

  /// Métodos de pago configurados (efectivo, Yape, tarjeta…).
  Future<List<TipoPago>> obtenerTiposPago() async {
    final resp = await _http.obtenerConDatos({'metodo': 'get'}, 'tipo_pago.php');
    return _lista(resp).map(TipoPago.fromJson).toList();
  }

  /// Turnos de caja abiertos en la sucursal. Vacío = no hay caja abierta.
  Future<List<SesionCaja>> obtenerCajasAbiertas() async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'sesiones_abiertas', 'sucursal_id': await _sucursalId()},
      'caja.php',
    );
    return _lista(resp).map(SesionCaja.fromJson).toList();
  }

  /// Resuelve (y registra si hace falta) el cliente de una boleta por su DNI.
  /// Devuelve null si el documento no existe.
  Future<ClienteVenta?> buscarClientePorDni(String dni) =>
      _buscarCliente('get_dni', {'dni': dni});

  /// Resuelve (y registra si hace falta) la empresa de una factura por su RUC.
  Future<ClienteVenta?> buscarClientePorRuc(String ruc) =>
      _buscarCliente('get_ruc', {'ruc': ruc});

  Future<ClienteVenta?> _buscarCliente(
      String metodo, Map<String, dynamic> documento) async {
    final resp = await _http.obtenerConDatos(
      {
        'metodo': metodo,
        'cliente': {...documento, 'usuario_creacion': await _usuarioId()},
      },
      'clientes.php',
    );
    if (resp is! Map || resp['success'] != true) return null;
    final datos = _lista(resp);
    if (datos.isEmpty) return null;
    return ClienteVenta.fromJson(datos.first);
  }

  // ------------------------------------------------------------ Punto de venta

  /// Registra la venta directa del carrito (descuenta stock y emite el
  /// comprobante). Equivale al botón GUARDAR de `VentaActual.vue`.
  ///
  /// [cajaSesionId] puede ir en null cuando el Administrador cobra sin caja
  /// abierta, igual que en el web.
  Future<ResultadoOperacion> registrarVenta({
    required int clienteId,
    required int organizadorId,
    required int tipoPagoId,
    required String tipoComprobante,
    required double totalPagar,
    required double montoEntregado,
    required List<ItemCarrito> items,
    int? cajaSesionId,
  }) async {
    final resp = await _http.registrar({
      'metodo': 'realiza_pago',
      'pago': {
        'cliente_id': clienteId,
        'total_pagar': totalPagar.toStringAsFixed(2),
        'monto_entregado': montoEntregado.toStringAsFixed(2),
        'tipo_pago': tipoPagoId,
        'tipo_comprobante': tipoComprobante,
        'usuario_creacion': await _usuarioId(),
        'sucursal_id': await _sucursalId(),
        'organizador_id': organizadorId,
        'caja_sesion_id': cajaSesionId,
        'productos': items
            .map((i) => {
                  'id': i.productoId,
                  'cantidad': i.cantidad,
                  'precio': i.precio,
                  'descuento': 0,
                  'unidad_medidad_id': i.unidadMedidaId,
                })
            .toList(),
      },
    }, 'tienda.php');

    if (resp is Map && resp['success'] == true) {
      final datos = _lista(resp);
      return ResultadoOperacion(
        true,
        'Venta registrada correctamente',
        ventaId: datos.isEmpty
            ? null
            : int.tryParse(datos.first['venta_id']?.toString() ?? ''),
      );
    }
    return _resultado(resp, 'No se pudo registrar la venta');
  }

  // ----------------------------------------------------- Ventas ya realizadas

  /// Historial de ventas de la sucursal. Sin fechas el backend devuelve las de
  /// HOY (mismo comportamiento que el panel web).
  ///
  /// La respuesta trae varios bloques (`totalVentas`, `ventas`,
  /// `producto_mas_vendido`); aquí solo interesa `ventas`.
  Future<List<VentaRealizada>> obtenerVentas({
    DateTime? desde,
    DateTime? hasta,
  }) async {
    String? aFecha(DateTime? f) => f == null
        ? null
        : '${f.year.toString().padLeft(4, '0')}-'
            '${f.month.toString().padLeft(2, '0')}-'
            '${f.day.toString().padLeft(2, '0')}';

    final resp = await _http.obtenerConDatos({
      'metodo': 'obtener',
      'filtros': {
        'fechaInicio': aFecha(desde),
        'fechaFin': aFecha(hasta),
        'sucursal_id': await _sucursalId(),
      },
    }, 'ventas.php');

    final bloque = (resp is Map) ? resp['ventas'] : null;
    if (bloque is! Map || bloque['success'] != true) return const [];
    return _lista(bloque).map(VentaRealizada.fromJson).toList();
  }

  // --------------------------------------------------------- Pedidos de la app

  /// Pedidos pendientes de la sucursal (los que los clientes hacen desde la app).
  Future<List<PedidoPendiente>> obtenerPedidos() async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'obtener', 'sucursal_id': await _sucursalId()},
      'pedidos.php',
    );
    return _lista(resp).map(PedidoPendiente.fromJson).toList();
  }

  /// Productos de un pedido.
  Future<List<DetallePedido>> obtenerDetalle(int pedidoId) async {
    final resp = await _http.obtenerConDatos(
      {'metodo': 'detalle', 'pedido_id': pedidoId},
      'pedidos.php',
    );
    return _lista(resp).map(DetallePedido.fromJson).toList();
  }

  /// Cobra el pedido: genera la venta y descuenta el stock.
  Future<ResultadoOperacion> atenderPedido(int pedidoId, int tipoPagoId) async {
    final resp = await _http.registrar({
      'metodo': 'atender',
      'pedido': {
        'pedido_id': pedidoId,
        'tipo_pago': tipoPagoId,
        'usuario_creacion': await _usuarioId(),
      },
    }, 'pedidos.php');
    return _resultado(resp, 'Pedido pagado y venta generada');
  }

  /// Cobra un pedido pagado por Yape validando el código del comprobante.
  Future<ResultadoOperacion> validarPagoYape(
      int pedidoId, String codigo) async {
    final resp = await _http.registrar({
      'metodo': 'validar_pago_yape',
      'pedido_id': pedidoId,
      'codigo': codigo,
      'usuario_creacion': await _usuarioId(),
    }, 'pedidos.php');
    return _resultado(resp, 'Pago validado y venta generada');
  }

  /// Reactiva un código Yape expirado para poder reintentar la validación.
  Future<ResultadoOperacion> reactivarCodigoYape(String codigo) async {
    final resp = await _http.registrar({
      'metodo': 'reactivar_codigo',
      'codigo': codigo,
      'sucursal_id': await _sucursalId(),
    }, 'recibir_notificacion.php');
    return _resultado(resp, 'Código reactivado');
  }

  /// Marca como entregado un pedido canjeado con puntos (no genera venta).
  Future<ResultadoOperacion> entregarPedido(int pedidoId) async {
    final resp = await _http.registrar({
      'metodo': 'entregar',
      'pedido_id': pedidoId,
      'usuario_creacion': await _usuarioId(),
    }, 'pedidos.php');
    return _resultado(resp, 'Pedido entregado');
  }

  /// Cancela un pedido pendiente.
  Future<ResultadoOperacion> cancelarPedido(int pedidoId) async {
    final resp = await _http.registrar(
      {'metodo': 'cancelar', 'pedido_id': pedidoId},
      'pedidos.php',
    );
    return _resultado(resp, 'Pedido cancelado');
  }
}
