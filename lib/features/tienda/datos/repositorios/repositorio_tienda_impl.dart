import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/dominio/repositorios/repositorio_tienda.dart';

class RepositorioTiendaImpl implements RepositorioTienda {
  final HttpService _httpService;

  RepositorioTiendaImpl(this._httpService);

  @override
  Future<CatalogoTienda> obtenerCatalogo() async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    // 1) Almacén (organizador) activo de la sucursal.
    final almacenResp = await _httpService.obtenerConDatos(
      {'metodo': 'get_almacenes', 'sucursal_id': sucursalId},
      'organizador.php',
    );
    final almacenes = (almacenResp is Map) ? almacenResp['datos'] : null;
    int organizadorId = 0;
    if (almacenes is List && almacenes.isNotEmpty) {
      organizadorId =
          int.tryParse((almacenes.first as Map)['id'].toString()) ?? 0;
    }
    if (organizadorId == 0) {
      throw Exception('No hay un almacén disponible para tu sucursal');
    }

    // 2) Productos de ese almacén.
    final resp = await _httpService.obtenerConDatos(
      {'metodo': 'get', 'almacen_id': organizadorId},
      'tienda.php',
    );
    final datos = (resp is Map) ? resp['datos'] : null;
    if (datos is! List) {
      throw Exception('No se pudo cargar el catálogo de productos');
    }

    final productos = datos
        .whereType<Map>()
        .map((p) => ProductoTienda.fromJson(Map<String, dynamic>.from(p)))
        .where((p) => p.disponible)
        .toList();

    return CatalogoTienda(organizadorId: organizadorId, productos: productos);
  }

  @override
  Future<ResultadoPedido> crearPedido(
      int organizadorId, List<ItemCarrito> items) async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
    final miembroId = int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;

    final payload = {
      'metodo': 'crear',
      'pedido': {
        'miembro_id': miembroId,
        'sucursal_id': sucursalId,
        'organizador_id': organizadorId,
        'productos': items.map((i) => i.aJsonPedido()).toList(),
      },
    };

    final resp = await _httpService.registrar(payload, 'pedidos.php');

    if (resp is Map && resp['success'] == true) {
      return ResultadoPedido(
        true,
        resp['mensaje']?.toString() ?? 'Pedido enviado correctamente',
      );
    }
    final mensaje = (resp is Map)
        ? (resp['mensaje']?.toString() ??
            resp['error']?.toString() ??
            'No se pudo enviar el pedido')
        : 'No se pudo enviar el pedido';
    return ResultadoPedido(false, mensaje);
  }
}
