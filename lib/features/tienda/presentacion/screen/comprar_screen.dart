import 'package:flutter/material.dart';
import 'package:xnox_app/features/pago_yape/presentacion/pago_yape_screen.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/hoja_mis_pedidos.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/hoja_mis_puntos.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/presentacion/controlador/controlador_tienda.dart';

/// Tienda del socio: catálogo en cuadrícula con categorías, ficha de cada
/// producto, carrito y pedido (queda pendiente hasta que se paga por Yape o
/// se cobra en recepción). Sigue el formato de Inicio y Rutinas: cabecera
/// propia, tarjeta con foto teñida de la marca y secciones con ícono.
class ComprarScreen extends StatefulWidget {
  const ComprarScreen({super.key});

  @override
  State<ComprarScreen> createState() => _ComprarScreenState();
}

class _ComprarScreenState extends State<ComprarScreen> {
  final _controlador = ControladorTienda();
  final _promo = ControladorPromociones();
  CatalogoTienda? _catalogo;
  ResumenPuntos _resumen = ResumenPuntos.vacio;
  bool _cargando = true;
  bool _enviando = false;
  String _busqueda = '';
  String? _categoria; // null = todas

  /// Pedidos del socio aún pendientes de pago (abre "Mis pedidos").
  int _pedidosPendientes = 0;

  /// Producto -> puntos que otorga (para el distintivo "+X pts").
  Map<int, int> get _puntosPorProducto => {
    for (final g in _resumen.gana) g.productoId: g.puntos,
  };

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
      // Los puntos y los pedidos son secundarios: si fallan, no rompen la
      // tienda.
      ResumenPuntos resumen;
      try {
        resumen = await _promo.obtenerResumen();
      } catch (_) {
        resumen = ResumenPuntos.vacio;
      }
      final pendientes = await _contarPendientes();
      if (!mounted) return;
      setState(() {
        _catalogo = catalogo;
        _resumen = resumen;
        _pedidosPendientes = pendientes;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(
        context,
        'No se pudo cargar la tienda',
        tipo: TipoMensaje.error,
      );
    }
  }

  Future<void> _recargarPuntos() async {
    try {
      final resumen = await _promo.obtenerResumen();
      if (!mounted) return;
      setState(() => _resumen = resumen);
    } catch (_) {
      /* silencioso */
    }
  }

  Future<void> _abrirMisPuntos() async {
    await mostrarHojaMisPuntos(context, resumen: _resumen);
    await _recargarPuntos();
  }

  Future<int> _contarPendientes() async {
    try {
      final pedidos = await _controlador.obtenerMisPedidos();
      return pedidos.where((p) => p.pendiente).length;
    } catch (_) {
      return 0;
    }
  }

  Future<void> _recargarPedidos() async {
    final pendientes = await _contarPendientes();
    if (!mounted) return;
    setState(() => _pedidosPendientes = pendientes);
  }

  Future<void> _abrirMisPedidos() async {
    await mostrarHojaMisPedidos(context);
    await _recargarPedidos();
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  String _urlImagen(String img) {
    if (img.isEmpty) return '';
    final limpio = img.startsWith('./') ? img.substring(2) : img;
    // Ruta de la empresa activa, no la constante: cada empresa tiene su
    // servidor y con la constante las fotos se pedían al de desarrollo.
    return '${HttpService().rutaActual}$limpio';
  }

  int get _totalItems =>
      _carrito.values.fold(0, (acc, it) => acc + it.cantidad);

  double get _totalCarrito =>
      _carrito.values.fold(0.0, (acc, it) => acc + it.subtotal);

  /// Puntos que ganará con el carrito actual.
  int get _puntosCarrito => _carrito.values.fold(
    0,
    (acc, it) => acc + (_puntosPorProducto[it.productoId] ?? 0) * it.cantidad,
  );

  List<String> get _categorias {
    final set = <String>{};
    for (final p in _catalogo?.productos ?? const <ProductoTienda>[]) {
      if (p.nombreCategoria.trim().isNotEmpty) {
        set.add(p.nombreCategoria.trim());
      }
    }
    return set.toList()..sort();
  }

  List<ProductoTienda> get _productosFiltrados {
    var productos = _catalogo?.productos ?? const <ProductoTienda>[];
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

  ItemCarrito? _enCarrito(ProductoTienda p) {
    if (p.unidadPrincipal == null) return null;
    return _carrito[ItemCarrito.desdeProducto(p).clave];
  }

  /// Suma [cantidad] del producto al carrito respetando el stock.
  bool _agregar(ProductoTienda producto, {int cantidad = 1}) {
    if (!producto.disponible) {
      mostrarMensaje(
        context,
        '${producto.nombre} está agotado',
        tipo: TipoMensaje.advertencia,
      );
      return false;
    }
    final nuevo = ItemCarrito.desdeProducto(producto);
    final existente = _carrito[nuevo.clave];
    final base = existente?.cantidad ?? 0;
    if (base + cantidad > producto.stock) {
      mostrarMensaje(
        context,
        'No hay más stock de ${producto.nombre}',
        tipo: TipoMensaje.advertencia,
      );
      return false;
    }
    setState(() {
      if (existente != null) {
        existente.cantidad = base + cantidad;
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

  // ------------------------------------------------------------------ Vista

  @override
  Widget build(BuildContext context) {
    final productos = _productosFiltrados;
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  RefreshIndicator(
                    onRefresh: _cargar,
                    child: CustomScrollView(
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
                              _cabecera(),
                              const SizedBox(height: AppEspaciado.md + 4),
                              _portada(),
                              if (_pedidosPendientes > 0) ...[
                                const SizedBox(height: AppEspaciado.sm + 4),
                                _avisoPedidos(),
                              ],
                              const SizedBox(height: AppEspaciado.md + 4),
                              _buscador(),
                              const SizedBox(height: AppEspaciado.sm + 4),
                              if (_categorias.length > 1) ...[
                                _filtroCategorias(),
                                const SizedBox(height: AppEspaciado.md),
                              ],
                              _tituloSeccion(productos.length),
                              const SizedBox(height: AppEspaciado.sm + 4),
                            ]),
                          ),
                        ),
                        if (productos.isEmpty)
                          const SliverToBoxAdapter(
                            child: Padding(
                              padding: EdgeInsets.only(top: 40),
                              child: EstadoVacio(
                                icono: Icons.inventory_2_outlined,
                                mensaje: 'No encontramos productos',
                              ),
                            ),
                          )
                        else
                          SliverPadding(
                            padding: EdgeInsets.fromLTRB(
                              AppEspaciado.md,
                              0,
                              AppEspaciado.md,
                              _totalItems > 0 ? 175 : 110,
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
                    // Encima de la barra de navegación del socio.
                    Positioned(
                      left: AppEspaciado.md,
                      right: AppEspaciado.md,
                      bottom: 92,
                      child: _barraCarrito(),
                    ),
                ],
              ),
      ),
    );
  }

  Widget _cabecera() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Tienda',
                style: TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Suplementos y más de tu gimnasio',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        // Mis pedidos, con el número de pedidos por pagar.
        Material(
          color: AppColores.superficie,
          shape: CircleBorder(side: BorderSide(color: AppColores.borde)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _abrirMisPedidos,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Center(
                child: Badge(
                  isLabelVisible: _pedidosPendientes > 0,
                  label: Text('$_pedidosPendientes'),
                  backgroundColor: AppColores.naranja,
                  child: Icon(
                    Icons.receipt_long_rounded,
                    color: AppColores.primario,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Tarjeta con foto: los puntos del socio (si el gimnasio usa puntos) o una
  /// invitación a comprar.
  Widget _portada() {
    final conPuntos =
        _resumen.saldo > 0 ||
        _resumen.canje.isNotEmpty ||
        _resumen.gana.isNotEmpty;
    final puedeCanjear = _resumen.canje.isNotEmpty;
    return SizedBox(
      height: 150,
      child: FotoTarjeta(
        foto: 'assets/imagenes/inicio/tienda.jpg',
        alineacion: const Alignment(0.4, 0.2),
        radio: AppEspaciado.radio + 6,
        degradadoHorizontal: true,
        onTap: conPuntos ? _abrirMisPuntos : null,
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                conPuntos ? 'TUS PUNTOS' : 'COMPRA EN LA APP',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColores.destacado,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                conPuntos ? '${_resumen.saldo} pts' : 'Pide y recoge',
                style: const TextStyle(
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 210,
                child: Text(
                  conPuntos
                      ? (puedeCanjear
                            ? 'Gana puntos con cada compra y canjéalos por premios.'
                            : 'Gana puntos con cada compra.')
                      : yapeEnTiendaDisponible
                      ? 'Arma tu pedido y págalo con Yape o en recepción.'
                      : 'Arma tu pedido y págalo en recepción.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: Colors.white.withValues(alpha: 0.82),
                  ),
                ),
              ),
              if (conPuntos) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      puedeCanjear ? 'Ver y canjear' : 'Ver historial',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppColores.destacado,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColores.destacado,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _avisoPedidos() {
    final n = _pedidosPendientes;
    final radio = BorderRadius.circular(AppEspaciado.radio);
    return Material(
      color: AppColores.naranja.withValues(alpha: 0.08),
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: _abrirMisPedidos,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(
              color: AppColores.naranja.withValues(alpha: 0.35),
            ),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.schedule_rounded,
                color: AppColores.naranja,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  n == 1
                      ? 'Tienes 1 pedido por pagar'
                      : 'Tienes $n pedidos por pagar',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              const Text(
                'Pagar',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColores.naranja,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColores.naranja,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buscador() {
    return TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar proteína, creatina, bebidas…',
        prefixIcon: const Icon(Icons.search_rounded),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColores.borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColores.borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide(color: AppColores.primario, width: 1.6),
        ),
      ),
    );
  }

  Widget _filtroCategorias() {
    final opciones = <String?>[null, ..._categorias];
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: opciones.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final c = opciones[i];
          final activa = c == _categoria;
          return GestureDetector(
            onTap: () => setState(() => _categoria = c),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: activa ? AppColores.degradadoRelleno : null,
                color: activa ? null : AppColores.superficie,
                borderRadius: BorderRadius.circular(20),
                border: activa
                    ? AppColores.bordeCabecera
                    : Border.all(color: AppColores.borde),
              ),
              child: Text(
                c == null ? 'Todo' : _bonito(c),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
                  color: activa
                      ? AppColores.sobreRelleno
                      : AppColores.textoPrincipal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// "HIGIENE PERSONAL" -> "Higiene personal" (el backend guarda en
  /// mayúsculas).
  static String _bonito(String t) {
    final l = t.trim().toLowerCase();
    return l.isEmpty ? l : l[0].toUpperCase() + l.substring(1);
  }

  Widget _tituloSeccion(int cantidad) {
    return Row(
      children: [
        Icon(Icons.storefront_rounded, color: AppColores.primario),
        const SizedBox(width: AppEspaciado.sm),
        Expanded(
          child: Text(
            _categoria == null ? 'Productos' : _bonito(_categoria!),
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
              color: AppColores.textoPrincipal,
            ),
          ),
        ),
        Text(
          '$cantidad ${cantidad == 1 ? 'producto' : 'productos'}',
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _tarjetaProducto(ProductoTienda p) {
    final enCarrito = _enCarrito(p);
    final puntos = _puntosPorProducto[p.id];
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
              // Foto con los distintivos encima.
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppEspaciado.radio - 2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _imagen(p.imagen),
                        if (puntos != null)
                          Positioned(
                            left: 6,
                            top: 6,
                            child: _chip(
                              '+$puntos pts',
                              AppColores.naranja,
                              icono: Icons.star_rounded,
                            ),
                          ),
                        if (!p.disponible)
                          Container(
                            color: Colors.white.withValues(alpha: 0.6),
                            alignment: Alignment.center,
                            child: _chip('Agotado', AppColores.vencido),
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
                    if (p.nombreMarca.trim().isNotEmpty)
                      Text(
                        p.nombreMarca.toUpperCase(),
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
                            _soles(p.precio),
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w800,
                              color: AppColores.primario,
                            ),
                          ),
                        ),
                        if (enCarrito == null)
                          _botonMas(p.disponible ? () => _agregar(p) : null)
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

  Widget _chip(String texto, Color color, {IconData? icono}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: Colors.white),
            const SizedBox(width: 3),
          ],
          Text(
            texto,
            style: const TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
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

  Widget _imagen(String img, {double tamanoIcono = 36}) {
    final url = _urlImagen(img);
    final vacio = Container(
      color: AppColores.primario.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: tamanoIcono,
        color: AppColores.primario.withValues(alpha: 0.4),
      ),
    );
    if (url.isEmpty) return vacio;
    return Container(
      color: Colors.white,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 600,
        errorBuilder: (_, _, _) => vacio,
      ),
    );
  }

  /// Barra flotante del carrito: cantidad, total y acceso al carrito.
  Widget _barraCarrito() {
    final radio = BorderRadius.circular(AppEspaciado.radio + 4);
    return Material(
      elevation: 0,
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radio,
        onTap: _mostrarCarrito,
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
                decoration: BoxDecoration(
                  color: AppColores.sobreRelleno.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Badge(
                  label: Text('$_totalItems'),
                  backgroundColor: AppColores.naranja,
                  child: Icon(
                    Icons.shopping_bag_rounded,
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
                      'Ver mi carrito',
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
                _soles(_totalCarrito),
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

  /// Ficha del producto: foto grande, datos, cantidad y "Agregar".
  Future<void> _abrirProducto(ProductoTienda p) async {
    var cantidad = 1;
    final puntos = _puntosPorProducto[p.id];
    await mostrarHojaModerna<void>(
      context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setHoja) => HojaModerna(
          titulo: p.nombre,
          subtitulo: [
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
                onMas: cantidad < p.stock
                    ? () => setHoja(() => cantidad++)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: BotonHoja(
                  texto: 'Agregar · ${_soles(p.precio * cantidad)}',
                  icono: Icons.add_shopping_cart_rounded,
                  onPressed: p.disponible
                      ? () {
                          if (_agregar(p, cantidad: cantidad)) {
                            Navigator.pop(ctx);
                            mostrarMensaje(
                              context,
                              'Agregado al carrito: ${p.nombre}',
                              tipo: TipoMensaje.exito,
                            );
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
                  child: _imagen(p.imagen, tamanoIcono: 64),
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              Row(
                children: [
                  Text(
                    _soles(p.precio),
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
                  if (!p.disponible) _chip('Agotado', AppColores.vencido),
                ],
              ),
              if (puntos != null) ...[
                const SizedBox(height: AppEspaciado.sm + 4),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColores.naranja.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    border: Border.all(
                      color: AppColores.naranja.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        color: AppColores.naranja,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Ganas $puntos puntos por cada unidad que compres.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
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

  void _mostrarCarrito() {
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
            icono: Icons.shopping_bag_rounded,
            titulo: 'Tu carrito',
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
                if (_puntosCarrito > 0) ...[
                  Row(
                    children: [
                      const Icon(
                        Icons.stars_rounded,
                        size: 18,
                        color: AppColores.naranja,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Ganarás $_puntosCarrito puntos',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColores.naranja,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
                Row(
                  children: [
                    const Text(
                      'Total',
                      style: TextStyle(
                        fontSize: 15,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      _soles(_totalCarrito),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppEspaciado.sm + 4),
                BotonHoja(
                  texto: 'Confirmar pedido',
                  icono: Icons.check_rounded,
                  cargando: _enviando,
                  onPressed: items.isEmpty
                      ? null
                      : () => _enviarPedido(ctx, setHoja),
                ),
              ],
            ),
            child: Column(
              children: [
                for (final item in items)
                  _filaCarrito(item, (cambio) => refrescar(cambio)),
                const SizedBox(height: AppEspaciado.sm),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _filaCarrito(ItemCarrito item, void Function(VoidCallback) refrescar) {
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
              child: _imagen(item.imagen, tamanoIcono: 24),
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
                  _soles(item.subtotal),
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

  Future<void> _enviarPedido(BuildContext hoja, StateSetter setHoja) async {
    if (_carrito.isEmpty || _catalogo == null) return;
    setHoja(() => _enviando = true);

    final resultado = await _controlador.crearPedido(
      _catalogo!.organizadorId,
      _carrito.values.toList(),
    );
    if (!mounted) return;
    _enviando = false;

    if (resultado.exito) {
      setState(() => _carrito.clear());
      if (hoja.mounted) Navigator.of(hoja).pop();
      await _recargarPedidos();
      if (!mounted) return;
      final pagarAhora = await _preguntarPago(resultado.total);
      if (pagarAhora != true || !mounted) return;
      // "Mis pedidos" muestra el recién creado de primero para pagarlo.
      await _abrirMisPedidos();
    } else {
      setHoja(() {});
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.error);
    }
  }

  /// Pedido registrado: confirma y pregunta cómo pagar.
  Future<bool?> _preguntarPago(double total) {
    Widget opcion({
      required IconData icono,
      required String titulo,
      required String detalle,
      required bool principal,
      required VoidCallback onTap,
      bool proximamente = false,
    }) {
      final radio = BorderRadius.circular(AppEspaciado.radio + 2);
      // "Próximamente": se ve atenuada y no responde al toque.
      return Opacity(
        opacity: proximamente ? 0.6 : 1,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radio,
            onTap: proximamente ? null : onTap,
            child: Ink(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: principal ? AppColores.degradadoRelleno : null,
                color: principal ? null : AppColores.fondo,
                borderRadius: radio,
                border: principal
                    ? AppColores.bordeCabecera
                    : Border.all(color: AppColores.borde),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: principal
                          ? AppColores.sobreRelleno.withValues(alpha: 0.15)
                          : AppColores.primario.withValues(alpha: 0.10),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icono,
                      color: principal
                          ? AppColores.sobreRelleno
                          : AppColores.primario,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: principal
                                ? AppColores.sobreRelleno
                                : AppColores.textoPrincipal,
                          ),
                        ),
                        Text(
                          detalle,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: principal
                                ? AppColores.sobreRellenoSuave
                                : AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (proximamente)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColores.naranja.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Próximamente',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: AppColores.naranja,
                        ),
                      ),
                    )
                  else
                    Icon(
                      Icons.chevron_right_rounded,
                      color: principal
                          ? AppColores.sobreRelleno
                          : AppColores.textoSecundario,
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return mostrarHojaModerna<bool>(
      context,
      builder: (ctx) => HojaModerna(
        titulo: '¡Pedido registrado!',
        subtitulo: 'Total a pagar: ${_soles(total)}',
        child: Column(
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: AppColores.exito.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_circle_rounded,
                size: 52,
                color: AppColores.exito,
              ),
            ),
            const SizedBox(height: AppEspaciado.md),
            const Text(
              '¿Cómo quieres pagarlo?',
              style: TextStyle(fontSize: 14, color: AppColores.textoSecundario),
            ),
            const SizedBox(height: AppEspaciado.md),
            // Mientras Yape no esté disponible en la tienda, recepción pasa
            // a ser la opción principal y Yape queda como "Próximamente".
            if (yapeEnTiendaDisponible) ...[
              opcion(
                icono: Icons.qr_code_2_rounded,
                titulo: 'Pagar ahora con Yape',
                detalle: 'Rápido, desde la app',
                principal: true,
                onTap: () => Navigator.pop(ctx, true),
              ),
              const SizedBox(height: AppEspaciado.sm + 2),
            ],
            opcion(
              icono: Icons.storefront_rounded,
              titulo: 'Pagar en recepción',
              detalle: 'Lo recoges y pagas en el gimnasio',
              principal: !yapeEnTiendaDisponible,
              onTap: () => Navigator.pop(ctx, false),
            ),
            if (!yapeEnTiendaDisponible) ...[
              const SizedBox(height: AppEspaciado.sm + 2),
              opcion(
                icono: Icons.qr_code_2_rounded,
                titulo: 'Pagar con Yape',
                detalle: 'Pronto podrás pagar desde la app',
                principal: false,
                proximamente: true,
                onTap: () {},
              ),
            ],
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
  }
}
