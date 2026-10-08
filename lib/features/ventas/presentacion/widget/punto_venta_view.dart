import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';
import 'package:xnox_app/features/ventas/presentacion/screen/cobrar_venta_screen.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/piezas_ventas.dart';

/// Punto de venta del admin: mismo catálogo y mismo formato que la tienda del
/// socio (cuadrícula con fotos, categorías, barra del carrito), pero armando
/// una venta que se cobra en el momento (equivalente a `TiendaProducto.vue`).
class PuntoVentaView extends StatefulWidget {
  /// Cabecera de Ventas (título y pestañas), va arriba del desplazamiento.
  final Widget cabecera;

  /// Pestaña visible. Al volver a ella se recargan los datos: una venta
  /// hecha en otra pestaña tiene que verse sin jalar para actualizar.
  final bool activa;

  const PuntoVentaView({super.key, required this.cabecera, this.activa = true});

  @override
  State<PuntoVentaView> createState() => _PuntoVentaViewState();
}

class _PuntoVentaViewState extends State<PuntoVentaView> {
  final _controlador = ControladorVentas();
  CatalogoTienda? _catalogo;
  bool _cargando = true;
  String _busqueda = '';
  String? _categoria; // null = todas

  /// Carrito indexado por producto + unidad.
  final Map<String, ItemCarrito> _carrito = {};

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PuntoVentaView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa && !oldWidget.activa) _cargar(silencioso: true);
  }

  /// [silencioso]: sin el indicador de carga, la lista se reemplaza al llegar.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
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
      mostrarMensaje(
        context,
        'No se pudo cargar el catálogo de productos',
        tipo: TipoMensaje.error,
      );
    }
  }

  List<ProductoTienda> get _productos =>
      _catalogo?.productos ?? const <ProductoTienda>[];

  int get _totalItems => _carrito.values.fold(0, (a, i) => a + i.cantidad);
  double get _totalCarrito =>
      _carrito.values.fold(0.0, (a, i) => a + i.subtotal);

  List<String> get _categorias {
    final set = <String>{};
    for (final p in _productos) {
      if (p.nombreCategoria.trim().isNotEmpty) {
        set.add(p.nombreCategoria.trim());
      }
    }
    return set.toList()..sort();
  }

  List<ProductoTienda> get _productosFiltrados {
    var productos = _productos;
    if (_categoria != null) {
      productos = productos
          .where((p) => p.nombreCategoria.trim() == _categoria)
          .toList();
    }
    if (_busqueda.trim().isEmpty) return productos;
    final t = _busqueda.toLowerCase();
    return productos
        .where(
          (p) =>
              p.nombre.toLowerCase().contains(t) ||
              p.codigo.toLowerCase().contains(t) ||
              p.nombreMarca.toLowerCase().contains(t) ||
              p.nombreCategoria.toLowerCase().contains(t),
        )
        .toList();
  }

  /// "HIGIENE PERSONAL" -> "Higiene personal" (el backend guarda en
  /// mayúsculas).
  static String _bonito(String t) {
    final l = t.trim().toLowerCase();
    return l.isEmpty ? l : l[0].toUpperCase() + l.substring(1);
  }

  ItemCarrito? _enCarrito(ProductoTienda p) {
    if (p.unidadPrincipal == null) return null;
    return _carrito[ItemCarrito.desdeProducto(p).clave];
  }

  /// Stock que le queda al producto descontando lo ya puesto en el carrito.
  double _stockDisponible(ProductoTienda p) =>
      p.stock - (_enCarrito(p)?.cantidad ?? 0);

  /// Suma [cantidad] del producto a la venta respetando el stock.
  bool _agregar(ProductoTienda producto, {int cantidad = 1}) {
    if (!producto.disponible || _stockDisponible(producto) < cantidad) {
      mostrarMensaje(
        context,
        'No hay más stock de ${producto.nombre}',
        tipo: TipoMensaje.advertencia,
      );
      return false;
    }
    final nuevo = ItemCarrito.desdeProducto(producto);
    final existente = _carrito[nuevo.clave];
    setState(() {
      if (existente != null) {
        existente.cantidad += cantidad;
      } else {
        nuevo.cantidad = cantidad;
        _carrito[nuevo.clave] = nuevo;
      }
    });
    return true;
  }

  void _quitarUno(ProductoTienda p) {
    final item = _enCarrito(p);
    if (item == null) return;
    setState(() {
      if (item.cantidad > 1) {
        item.cantidad--;
      } else {
        _carrito.remove(item.clave);
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
    await _cargar(silencioso: true);
  }

  // ------------------------------------------------------------------ Vista

  @override
  Widget build(BuildContext context) {
    final productos = _productosFiltrados;
    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: _cargar,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppEspaciado.md,
                  AppEspaciado.md,
                  AppEspaciado.md,
                  0,
                ),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    widget.cabecera,
                    const SizedBox(height: AppEspaciado.md),
                    if (_cargando)
                      const Padding(
                        padding: EdgeInsets.only(top: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else ...[
                      _portada(),
                      const SizedBox(height: AppEspaciado.md + 4),
                      BuscadorApp(
                        hint: 'Buscar por nombre, código o marca…',
                        onChanged: (v) => setState(() => _busqueda = v),
                      ),
                      const SizedBox(height: AppEspaciado.sm + 4),
                      if (_categorias.length > 1) ...[
                        FilaChips(
                          chips: [
                            for (final c in <String?>[null, ..._categorias])
                              ChipApp(
                                texto: c == null ? 'Todo' : _bonito(c),
                                activo: c == _categoria,
                                onTap: () => setState(() => _categoria = c),
                              ),
                          ],
                        ),
                        const SizedBox(height: AppEspaciado.md),
                      ],
                      TituloSeccion(
                        icono: Icons.storefront_rounded,
                        titulo: _categoria == null
                            ? 'Productos'
                            : _bonito(_categoria!),
                        detalle:
                            '${productos.length} ${productos.length == 1 ? 'producto' : 'productos'}',
                      ),
                    ],
                  ]),
                ),
              ),
              if (!_cargando && productos.isEmpty)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      AppEspaciado.md,
                      AppEspaciado.sm,
                      AppEspaciado.md,
                      110,
                    ),
                    child: VacioApp(
                      icono: Icons.inventory_2_outlined,
                      titulo: 'No encontramos productos',
                      texto: 'Prueba con otra búsqueda o categoría.',
                    ),
                  ),
                )
              else if (!_cargando)
                SliverPadding(
                  // Aire para el botón del menú y la barra de la venta.
                  padding: EdgeInsets.fromLTRB(
                    AppEspaciado.md,
                    0,
                    AppEspaciado.md,
                    _totalItems > 0 ? 180 : 110,
                  ),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: AppEspaciado.sm + 6,
                          crossAxisSpacing: AppEspaciado.sm + 6,
                          childAspectRatio: 0.64,
                        ),
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => _tarjetaProducto(productos[i]),
                      childCount: productos.length,
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (_totalItems > 0)
          // Encima del botón del menú del admin (abajo a la izquierda).
          Positioned(
            left: AppEspaciado.md,
            right: AppEspaciado.md,
            bottom: 84,
            child: _barraVenta(),
          ),
      ],
    );
  }

  /// Portada con foto: cuántos productos hay para vender y su stock.
  Widget _portada() {
    final conStock = _productos.where((p) => p.disponible).length;
    final agotados = _productos.length - conStock;
    return PortadaFoto(
      foto: FotosApp.tienda,
      alineacion: const Alignment(0.4, 0.2),
      altura: 170,
      etiqueta: 'Punto de venta',
      titulo: '$conStock ${conStock == 1 ? 'producto' : 'productos'}',
      texto: 'Toca un producto para venderlo.',
      pie: Row(
        children: [
          DatoPortada(
            icono: Icons.category_rounded,
            valor: '${_categorias.length}',
            pie: _categorias.length == 1 ? 'categoría' : 'categorías',
          ),
          const SizedBox(width: AppEspaciado.lg),
          DatoPortada(
            icono: Icons.remove_shopping_cart_rounded,
            valor: '$agotados',
            pie: agotados == 1 ? 'agotado' : 'agotados',
          ),
        ],
      ),
    );
  }

  Widget _tarjetaProducto(ProductoTienda p) {
    final enCarrito = _enCarrito(p);
    final disponible = _stockDisponible(p);
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Material(
      color: AppColores.superficie,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: () => _abrirProducto(p),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(
              color: enCarrito != null
                  ? AppColores.primario.withValues(alpha: 0.45)
                  : AppColores.borde,
              width: enCarrito != null ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppEspaciado.radio - 2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FotoProducto(p.imagen),
                        // El admin sí ve el stock: lo necesita en mostrador.
                        if (p.disponible)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: PildoraVenta(
                              'Stock ${disponible.toStringAsFixed(0)}',
                              disponible > 0
                                  ? AppColores.verde
                                  : AppColores.naranja,
                              icono: Icons.inventory_2_rounded,
                            ),
                          ),
                        if (!p.disponible)
                          Container(
                            color: Colors.white.withValues(alpha: 0.6),
                            alignment: Alignment.center,
                            child: PildoraVenta('Agotado', AppColores.vencido),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 8, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.nombreMarca.trim().isNotEmpty
                          ? p.nombreMarca.toUpperCase()
                          : p.codigo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                    Text(
                      p.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            soles(p.precio),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColores.primario,
                            ),
                          ),
                        ),
                        if (enCarrito == null)
                          _botonMas(disponible > 0 ? () => _agregar(p) : null)
                        else
                          _cantidadMini(p, enCarrito.cantidad),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _botonMas(VoidCallback? onTap) {
    return Material(
      color: onTap == null ? AppColores.borde : AppColores.relleno,
      shape: CircleBorder(side: AppColores.ladoBoton ?? BorderSide.none),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(
            Icons.add_rounded,
            size: 20,
            color: onTap == null
                ? AppColores.textoSecundario
                : AppColores.sobreRelleno,
          ),
        ),
      ),
    );
  }

  Widget _cantidadMini(ProductoTienda p, int cantidad) {
    Widget boton(IconData icono, VoidCallback onTap) => InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icono, size: 17, color: AppColores.sobreRelleno),
      ),
    );
    return Container(
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            boton(Icons.remove_rounded, () => _quitarUno(p)),
            Text(
              '$cantidad',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColores.sobreRelleno,
              ),
            ),
            boton(Icons.add_rounded, () => _agregar(p)),
          ],
        ),
      ),
    );
  }

  /// Barra flotante de la venta: cantidad, total y acceso al detalle.
  Widget _barraVenta() {
    final radio = BorderRadius.circular(AppEspaciado.radio + 4);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radio,
        onTap: _mostrarVenta,
        child: Ink(
          height: 62,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            gradient: AppColores.degradadoRelleno,
            border: AppColores.bordeCabecera,
            borderRadius: radio,
            boxShadow: [
              BoxShadow(
                color: AppColores.primario.withValues(alpha: 0.35),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColores.sobreRelleno.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  label: Text('$_totalItems'),
                  backgroundColor: AppColores.naranja,
                  child: Icon(
                    Icons.point_of_sale_rounded,
                    color: AppColores.sobreRelleno,
                    size: 20,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Ver venta',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColores.sobreRelleno,
                      ),
                    ),
                    Text(
                      '$_totalItems ${_totalItems == 1 ? 'producto' : 'productos'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColores.sobreRellenoSuave,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                soles(_totalCarrito),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColores.sobreRelleno,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColores.sobreRelleno),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Modales

  /// Ficha del producto: foto grande, precio, stock, cantidad y "Agregar".
  Future<void> _abrirProducto(ProductoTienda p) async {
    var cantidad = 1;
    final disponible = _stockDisponible(p);
    await mostrarHojaModerna<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setHoja) => HojaModerna(
          titulo: p.nombre,
          subtitulo: [
            p.codigo,
            p.nombreMarca,
            p.nombreCategoria,
          ].where((t) => t.trim().isNotEmpty).join(' · '),
          accion: IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColores.textoSecundario,
            ),
          ),
          pie: Row(
            children: [
              _selectorCantidad(
                cantidad,
                onMenos: cantidad > 1 ? () => setHoja(() => cantidad--) : null,
                onMas: cantidad < disponible
                    ? () => setHoja(() => cantidad++)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BotonHoja(
                  texto: 'Agregar · ${soles(p.precio * cantidad)}',
                  icono: Icons.add_shopping_cart_rounded,
                  onPressed: disponible > 0
                      ? () {
                          if (_agregar(p, cantidad: cantidad)) {
                            Navigator.pop(ctx);
                          }
                        }
                      : null,
                ),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
                child: AspectRatio(
                  aspectRatio: 1.3,
                  child: FotoProducto(p.imagen, tamanoIcono: 64),
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              Row(
                children: [
                  Text(
                    soles(p.precio),
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColores.primario,
                    ),
                  ),
                  if ((p.unidadPrincipal?.unidadMedida ?? '').isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Text(
                      '/ ${p.unidadPrincipal!.unidadMedida.toLowerCase()}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                  const Spacer(),
                  PildoraVenta(
                    disponible > 0
                        ? 'Stock ${disponible.toStringAsFixed(0)}'
                        : 'Agotado',
                    disponible > 0 ? AppColores.verde : AppColores.vencido,
                    suave: true,
                  ),
                ],
              ),
              const SizedBox(height: AppEspaciado.md),
            ],
          ),
        ),
      ),
    );
  }

  Widget _selectorCantidad(
    int cantidad, {
    VoidCallback? onMenos,
    VoidCallback? onMas,
  }) {
    Widget boton(IconData icono, VoidCallback? onTap) => InkWell(
      customBorder: const CircleBorder(),
      onTap: onTap,
      child: SizedBox(
        width: 40,
        height: 54,
        child: Icon(
          icono,
          color: onTap == null ? AppColores.borde : AppColores.primario,
        ),
      ),
    );
    return Container(
      height: 54,
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Material(
        color: Colors.transparent,
        child: Row(
          children: [
            boton(Icons.remove_rounded, onMenos),
            SizedBox(
              width: 26,
              child: Text(
                '$cantidad',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ),
            boton(Icons.add_rounded, onMas),
          ],
        ),
      ),
    );
  }

  /// La venta armada: fotos, cantidades y "Continuar al cobro".
  void _mostrarVenta() {
    mostrarHojaModerna<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setHoja) {
          final items = _carrito.values.toList();
          void refrescar(VoidCallback cambio) {
            setHoja(cambio);
            setState(() {});
            if (_carrito.isEmpty) Navigator.pop(ctx);
          }

          return HojaModerna(
            icono: Icons.point_of_sale_rounded,
            titulo: 'Venta actual',
            subtitulo:
                '$_totalItems ${_totalItems == 1 ? 'producto' : 'productos'}',
            accion: TextButton(
              onPressed: () => refrescar(() => _carrito.clear()),
              child: const Text(
                'Vaciar',
                style: TextStyle(color: AppColores.moroso),
              ),
            ),
            pie: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TotalVenta(_totalCarrito),
                const SizedBox(height: AppEspaciado.sm + 4),
                BotonHoja(
                  texto: 'Continuar al cobro',
                  icono: Icons.payments_rounded,
                  onPressed: items.isEmpty
                      ? null
                      : () {
                          Navigator.pop(ctx);
                          _cobrar();
                        },
                ),
              ],
            ),
            child: Column(
              children: [
                for (final item in items) _filaVenta(item, refrescar),
                const SizedBox(height: AppEspaciado.sm),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filaVenta(ItemCarrito item, void Function(VoidCallback) refrescar) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.sm + 2),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            child: SizedBox(
              width: 58,
              height: 58,
              child: FotoProducto(item.imagen, tamanoIcono: 24),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  soles(item.subtotal),
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColores.primario,
                  ),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColores.superficie,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColores.borde),
            ),
            child: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () => refrescar(() {
                    if (item.cantidad > 1) {
                      item.cantidad--;
                    } else {
                      _carrito.remove(item.clave);
                    }
                  }),
                  icon: Icon(
                    item.cantidad > 1
                        ? Icons.remove_rounded
                        : Icons.delete_outline_rounded,
                    color: item.cantidad > 1
                        ? AppColores.primario
                        : AppColores.moroso,
                  ),
                ),
                Text(
                  '${item.cantidad}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  iconSize: 18,
                  onPressed: () {
                    if (item.cantidad < item.stock) {
                      refrescar(() => item.cantidad++);
                    } else {
                      mostrarMensaje(
                        context,
                        'No hay más stock de ${item.nombre}',
                        tipo: TipoMensaje.advertencia,
                      );
                    }
                  },
                  icon: Icon(Icons.add_rounded, color: AppColores.primario),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
