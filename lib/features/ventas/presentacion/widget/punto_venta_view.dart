import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';
import 'package:xnox_app/features/ventas/presentacion/screen/cobrar_venta_screen.dart';

/// Punto de venta del admin: mismo catálogo que ve el cliente, pero armando
/// una venta que se cobra en el momento (equivalente a `TiendaProducto.vue`).
class PuntoVentaView extends StatefulWidget {
  const PuntoVentaView({super.key});

  @override
  State<PuntoVentaView> createState() => _PuntoVentaViewState();
}

class _PuntoVentaViewState extends State<PuntoVentaView> {
  final _controlador = ControladorVentas();
  CatalogoTienda? _catalogo;
  bool _cargando = true;
  String _busqueda = '';

  /// Carrito indexado por producto + unidad.
  final Map<String, ItemCarrito> _carrito = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final catalogo = await _controlador.obtenerCatalogo();
      if (!mounted) return;
      setState(() {
        _catalogo = catalogo;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudo cargar el catálogo de productos',
          tipo: TipoMensaje.error);
    }
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  String _urlImagen(String img) {
    if (img.isEmpty) return '';
    final limpio = img.startsWith('./') ? img.substring(2) : img;
    return '${HttpService().rutaActual}$limpio';
  }

  int get _totalItems => _carrito.values.fold(0, (a, i) => a + i.cantidad);
  double get _totalCarrito =>
      _carrito.values.fold(0.0, (a, i) => a + i.subtotal);

  List<ProductoTienda> get _productosFiltrados {
    final productos = _catalogo?.productos ?? const <ProductoTienda>[];
    if (_busqueda.trim().isEmpty) return productos;
    final t = _busqueda.toLowerCase();
    return productos
        .where((p) =>
            p.nombre.toLowerCase().contains(t) ||
            p.codigo.toLowerCase().contains(t) ||
            p.nombreMarca.toLowerCase().contains(t) ||
            p.nombreCategoria.toLowerCase().contains(t))
        .toList();
  }

  /// Stock que le queda al producto descontando lo ya puesto en el carrito.
  double _stockDisponible(ProductoTienda p) {
    final item = _carrito[ItemCarrito.desdeProducto(p).clave];
    return p.stock - (item?.cantidad ?? 0);
  }

  void _agregar(ProductoTienda producto) {
    if (_stockDisponible(producto) <= 0) {
      mostrarMensaje(context, 'No hay más stock de ${producto.nombre}',
          tipo: TipoMensaje.advertencia);
      return;
    }
    final item = ItemCarrito.desdeProducto(producto);
    final existente = _carrito[item.clave];
    setState(() {
      if (existente != null) {
        existente.cantidad++;
      } else {
        _carrito[item.clave] = item;
      }
    });
  }

  /// Abre la pantalla de cobro. Si la venta se registra, vacía el carrito y
  /// recarga el catálogo (el stock ya cambió).
  Future<void> _cobrar() async {
    final catalogo = _catalogo;
    if (catalogo == null || _carrito.isEmpty) return;
    final vendido = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CobrarVentaScreen(
          organizadorId: catalogo.organizadorId,
          items: _carrito.values.toList(),
        ),
      ),
    );
    if (vendido != true || !mounted) return;
    setState(() => _carrito.clear());
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: Column(
                children: [
                  _buscador(),
                  Expanded(child: _listaProductos()),
                ],
              ),
            ),
      floatingActionButton: _totalItems == 0 ? null : _botonCarrito(),
    );
  }

  Widget _buscador() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, AppEspaciado.sm, AppEspaciado.md, AppEspaciado.sm),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: const InputDecoration(
          hintText: 'Buscar por nombre, código o marca...',
          prefixIcon: Icon(Icons.search),
        ),
      ),
    );
  }

  Widget _listaProductos() {
    final productos = _productosFiltrados;
    if (productos.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 100),
          EstadoVacio(
            icono: Icons.inventory_2_outlined,
            mensaje: 'No hay productos con stock disponible',
          ),
        ],
      );
    }
    return ListView.separated(
      padding:
          const EdgeInsets.fromLTRB(AppEspaciado.md, 0, AppEspaciado.md, 96),
      itemCount: productos.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppEspaciado.sm + 4),
      itemBuilder: (_, i) => _tarjetaProducto(productos[i]),
    );
  }

  Widget _tarjetaProducto(ProductoTienda p) {
    final disponible = _stockDisponible(p);
    return TarjetaApp(
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
      onTap: () => _agregar(p),
      child: Row(
        children: [
          _imagen(p.imagen, 56),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  p.codigo,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      _soles(p.precio),
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColores.primario,
                      ),
                    ),
                    const SizedBox(width: AppEspaciado.sm),
                    // A diferencia de la tienda del cliente, el admin sí ve el
                    // stock: lo necesita para vender en mostrador.
                    EtiquetaEstado(
                      texto: 'Stock ${disponible.toStringAsFixed(0)}',
                      color: disponible > 0
                          ? AppColores.verde
                          : AppColores.moroso,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          ElevatedButton(
            onPressed: disponible > 0 ? () => _agregar(p) : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppEspaciado.md, vertical: 10),
            ),
            child: const Icon(Icons.add_shopping_cart, size: 18),
          ),
        ],
      ),
    );
  }

  Widget _imagen(String img, double size) {
    final url = _urlImagen(img);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      child: Container(
        width: size,
        height: size,
        color: AppColores.fondo,
        child: url.isEmpty
            ? const Icon(Icons.inventory_2_outlined,
                color: AppColores.textoSecundario)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                    Icons.inventory_2_outlined,
                    color: AppColores.textoSecundario),
              ),
      ),
    );
  }

  Widget _botonCarrito() {
    return FloatingActionButton.extended(
      onPressed: _mostrarCarrito,
      backgroundColor: AppColores.primario,
      icon: Badge(
        label: Text('$_totalItems'),
        backgroundColor: AppColores.naranja,
        child: const Icon(Icons.shopping_cart, color: Colors.white),
      ),
      label: Text(
        _soles(_totalCarrito),
        style:
            const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
      ),
    );
  }

  void _mostrarCarrito() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => StatefulBuilder(
        builder: (_, setSheet) => _contenidoCarrito(setSheet),
      ),
    );
  }

  Widget _contenidoCarrito(StateSetter setSheet) {
    final items = _carrito.values.toList();
    return Padding(
      padding: EdgeInsets.only(
        left: AppEspaciado.md,
        right: AppEspaciado.md,
        top: AppEspaciado.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppEspaciado.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.point_of_sale, color: AppColores.primario),
              const SizedBox(width: AppEspaciado.sm),
              const Text(
                'Venta actual',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const Spacer(),
              if (items.isNotEmpty)
                TextButton(
                  onPressed: () {
                    setSheet(() => _carrito.clear());
                    setState(() {});
                  },
                  child: const Text('Vaciar'),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          if (items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Text('No hay productos en la venta',
                  style: TextStyle(color: AppColores.textoSecundario)),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: items.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (_, i) => _filaCarrito(items[i], setSheet),
              ),
            ),
          const Divider(height: AppEspaciado.lg),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                _soles(_totalCarrito),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColores.primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: items.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop();
                      _cobrar();
                    },
              icon: const Icon(Icons.point_of_sale),
              label: const Text('Continuar al cobro'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filaCarrito(ItemCarrito item, StateSetter setSheet) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                '${_soles(item.precio)} · ${item.unidadNombre}',
                style: const TextStyle(
                    fontSize: 12, color: AppColores.textoSecundario),
              ),
            ],
          ),
        ),
        _botonCantidad(Icons.remove, () {
          if (item.cantidad > 1) {
            setSheet(() => item.cantidad--);
          } else {
            setSheet(() => _carrito.remove(item.clave));
          }
          setState(() {});
        }),
        SizedBox(
          width: 28,
          child: Text(
            '${item.cantidad}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        _botonCantidad(Icons.add, () {
          if (item.cantidad < item.stock) {
            setSheet(() => item.cantidad++);
            setState(() {});
          } else {
            mostrarMensaje(context, 'No hay más stock de ${item.nombre}',
                tipo: TipoMensaje.advertencia);
          }
        }),
        const SizedBox(width: AppEspaciado.sm),
        SizedBox(
          width: 74,
          child: Text(
            _soles(item.subtotal),
            textAlign: TextAlign.right,
            style: const TextStyle(
                fontWeight: FontWeight.w800, color: AppColores.primario),
          ),
        ),
      ],
    );
  }

  Widget _botonCantidad(IconData icono, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: AppColores.borde),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icono, size: 16, color: AppColores.primario),
      ),
    );
  }
}
