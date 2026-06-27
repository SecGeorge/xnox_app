import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/presentacion/controlador/controlador_tienda.dart';

/// Catálogo de la tienda para el cliente: ve productos, arma su carrito y
/// envía el pedido (queda pendiente hasta que el admin lo cobra).
class ComprarScreen extends StatefulWidget {
  const ComprarScreen({super.key});

  @override
  State<ComprarScreen> createState() => _ComprarScreenState();
}

class _ComprarScreenState extends State<ComprarScreen> {
  final _controlador = ControladorTienda();
  CatalogoTienda? _catalogo;
  bool _cargando = true;
  bool _enviando = false;
  String _busqueda = '';

  /// Carrito indexado por clave (producto + unidad).
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudo cargar la tienda',
          tipo: TipoMensaje.error);
    }
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  String _urlImagen(String img) {
    if (img.isEmpty) return '';
    final limpio = img.startsWith('./') ? img.substring(2) : img;
    return '${HttpService.RUTA_GLOBAL}$limpio';
  }

  int get _totalItems =>
      _carrito.values.fold(0, (acc, it) => acc + it.cantidad);

  double get _totalCarrito =>
      _carrito.values.fold(0.0, (acc, it) => acc + it.subtotal);

  List<ProductoTienda> get _productosFiltrados {
    final productos = _catalogo?.productos ?? const [];
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

  void _agregar(ProductoTienda producto) {
    final item = ItemCarrito.desdeProducto(producto);
    final existente = _carrito[item.clave];
    if (existente != null) {
      if (existente.cantidad < existente.stock) {
        setState(() => existente.cantidad++);
      } else {
        mostrarMensaje(context, 'No hay más stock de ${producto.nombre}',
            tipo: TipoMensaje.advertencia);
        return;
      }
    } else {
      setState(() => _carrito[item.clave] = item);
    }
    mostrarMensaje(context, 'Agregado: ${producto.nombre}',
        tipo: TipoMensaje.exito);
  }

  Future<void> _enviarPedido(StateSetter setSheet) async {
    if (_carrito.isEmpty || _catalogo == null) return;
    setSheet(() => _enviando = true);
    setState(() {});

    final resultado = await _controlador.crearPedido(
      _catalogo!.organizadorId,
      _carrito.values.toList(),
    );

    if (!mounted) return;
    _enviando = false;

    if (resultado.exito) {
      setState(() => _carrito.clear());
      Navigator.of(context).pop(); // cierra el bottom sheet
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.exito);
      _cargar();
    } else {
      setSheet(() {});
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.error);
    }
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
          AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, AppEspaciado.sm),
      child: TextField(
        onChanged: (v) => setState(() => _busqueda = v),
        decoration: const InputDecoration(
          hintText: 'Buscar producto...',
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
          SizedBox(height: 120),
          EstadoVacio(
            icono: Icons.inventory_2_outlined,
            mensaje: 'No hay productos disponibles',
          ),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, 0, AppEspaciado.md, 96),
      itemCount: productos.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppEspaciado.sm + 4),
      itemBuilder: (_, i) => _tarjetaProducto(productos[i]),
    );
  }

  Widget _tarjetaProducto(ProductoTienda p) {
    return TarjetaApp(
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
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
                  [p.nombreMarca, 'Stock: ${p.stock.toStringAsFixed(0)}']
                      .where((e) => e.trim().isNotEmpty)
                      .join(' · '),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _soles(p.precio),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColores.primario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          ElevatedButton(
            onPressed: () => _agregar(p),
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
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
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
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) => _contenidoCarrito(setSheet),
        );
      },
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
              const Icon(Icons.shopping_cart_outlined,
                  color: AppColores.primario),
              const SizedBox(width: AppEspaciado.sm),
              const Text(
                'Mi pedido',
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
              child: Text('Tu carrito está vacío',
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
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600)),
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
              onPressed:
                  (items.isEmpty || _enviando) ? null : () => _enviarPedido(setSheet),
              icon: _enviando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.send),
              label: Text(_enviando ? 'Enviando...' : 'Hacer pedido'),
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
          }
        }),
        const SizedBox(width: AppEspaciado.sm),
        SizedBox(
          width: 70,
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
