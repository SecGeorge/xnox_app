import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/presentacion/widget/tarjeta_qr_yape.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/pedido_pendiente.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/tipo_pago.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/piezas_ventas.dart';

/// Pedidos que los clientes hacen desde la app y que el admin todavía no cobra.
/// Es la versión móvil de `Ventas > Pedidos pendientes` del panel web.
class PedidosPendientesView extends StatefulWidget {
  /// Cabecera de Ventas (título y pestañas), va arriba del desplazamiento.
  final Widget cabecera;

  /// Pestaña visible. Al volver a ella se recargan los datos: una venta
  /// hecha en otra pestaña tiene que verse sin jalar para actualizar.
  final bool activa;

  const PedidosPendientesView({
    super.key,
    required this.cabecera,
    this.activa = true,
  });

  @override
  State<PedidosPendientesView> createState() => _PedidosPendientesViewState();
}

class _PedidosPendientesViewState extends State<PedidosPendientesView> {
  final _controlador = ControladorVentas();

  List<PedidoPendiente> _pedidos = const [];
  List<TipoPago> _tiposPago = const [];
  bool _cargando = true;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void didUpdateWidget(covariant PedidosPendientesView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa && !oldWidget.activa) _cargar(silencioso: true);
  }

  /// [silencioso]: sin el indicador de carga, la lista se reemplaza al llegar.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
    try {
      final pedidos = await _controlador.obtenerPedidos();
      // Los métodos de pago solo hacen falta al cobrar: si fallan no rompen
      // la lista, el diálogo de cobro lo avisará.
      List<TipoPago> tipos = _tiposPago;
      if (tipos.isEmpty) {
        try {
          tipos = await _controlador.obtenerTiposPago();
        } catch (_) {
          tipos = const [];
        }
      }
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _tiposPago = tipos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(
        context,
        'No se pudieron cargar los pedidos',
        tipo: TipoMensaje.error,
      );
    }
  }

  List<PedidoPendiente> get _filtrados {
    final t = _busqueda.toLowerCase().trim();
    if (t.isEmpty) return _pedidos;
    return _pedidos
        .where(
          (p) =>
              p.codigo.toLowerCase().contains(t) ||
              p.cliente.toLowerCase().contains(t) ||
              p.dni.toLowerCase().contains(t),
        )
        .toList();
  }

  double get _totalPendiente =>
      _filtrados.fold(0.0, (a, p) => a + (p.esCanje ? 0 : p.montoTotal));
  int get _totalProductos => _filtrados.fold(0, (a, p) => a + p.items);
  int get _clientesDistintos =>
      _filtrados.map((p) => p.miembroId).toSet().length;

  @override
  Widget build(BuildContext context) {
    final pedidos = _filtrados;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md,
          AppEspaciado.md,
          AppEspaciado.md,
          110,
        ),
        children: [
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
              hint: 'Buscar por cliente, código o documento…',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: AppEspaciado.md + 4),
            TituloSeccion(
              icono: Icons.shopping_basket_rounded,
              titulo: 'Por atender',
              detalle:
                  '${pedidos.length} ${pedidos.length == 1 ? 'pedido' : 'pedidos'}',
            ),
            if (pedidos.isEmpty)
              const VacioApp(
                icono: Icons.receipt_long_rounded,
                titulo: 'No hay pedidos pendientes',
                texto:
                    'Los pedidos que hagan tus socios desde la app '
                    'aparecerán aquí para cobrarlos.',
              )
            else
              for (final p in pedidos) ...[
                _tarjetaPedido(p),
                const SizedBox(height: AppEspaciado.sm + 4),
              ],
          ],
        ],
      ),
    );
  }

  /// Portada con foto: lo que hay por cobrar de los pedidos de la app.
  Widget _portada() {
    return PortadaFoto(
      foto: FotosApp.motivacion,
      altura: 170,
      etiqueta: 'Pedidos de la app',
      titulo: soles(_totalPendiente),
      texto: 'Por cobrar en pedidos de tus socios.',
      pie: Row(
        children: [
          DatoPortada(
            icono: Icons.receipt_long_rounded,
            valor: '${_filtrados.length}',
            pie: 'pedidos',
          ),
          const SizedBox(width: AppEspaciado.md),
          DatoPortada(
            icono: Icons.inventory_2_rounded,
            valor: '$_totalProductos',
            pie: 'productos',
          ),
          const SizedBox(width: AppEspaciado.md),
          DatoPortada(
            icono: Icons.groups_rounded,
            valor: '$_clientesDistintos',
            pie: 'clientes',
          ),
        ],
      ),
    );
  }

  Widget _tarjetaPedido(PedidoPendiente p) {
    final color = p.esCanje ? AppColores.morado : AppColores.naranja;
    return TarjetaPlana(
      padding: const EdgeInsets.all(14),
      onTap: () => _verDetalle(p),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AvatarInicial(p.inicial),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.cliente.trim().isEmpty
                          ? 'Cliente sin nombre'
                          : p.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.codigo} · ${fechaCorta(p.fecha)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p.esCanje ? 'Gratis' : soles(p.montoTotal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: p.esCanje
                          ? AppColores.morado
                          : AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.items} ${p.items == 1 ? 'producto' : 'productos'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PildoraVenta(
                p.esCanje ? 'Canje por puntos' : 'Pendiente de pago',
                color,
                icono: p.esCanje ? Icons.stars_rounded : Icons.schedule_rounded,
                suave: true,
              ),
              const Spacer(),
              _botonIcono(
                Icons.close_rounded,
                AppColores.moroso,
                'Cancelar pedido',
                () => _cancelar(p),
              ),
              const SizedBox(width: 8),
              SizedBox(
                height: 40,
                child: ElevatedButton.icon(
                  onPressed: () => p.esCanje ? _entregar(p) : _cobrar(p),
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    shape: const StadiumBorder(),
                  ),
                  icon: Icon(
                    p.esCanje
                        ? Icons.card_giftcard_rounded
                        : Icons.payments_rounded,
                    size: 18,
                  ),
                  label: Text(p.esCanje ? 'Entregar' : 'Cobrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonIcono(
    IconData icono,
    Color color,
    String tooltip,
    VoidCallback onTap,
  ) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.10),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(icono, size: 20, color: color),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Detalle
  Future<void> _verDetalle(PedidoPendiente p) async {
    List<DetallePedido> items;
    try {
      items = await _controlador.obtenerDetalle(p.id);
    } catch (_) {
      items = const [];
    }
    if (!mounted) return;
    final total = items.fold<double>(0, (a, d) => a + d.subtotal);
    await mostrarHojaModerna<void>(
      context,
      builder: (ctx) => HojaModerna(
        cabecera: AvatarInicial(p.inicial, tamano: 44),
        titulo: p.cliente.trim().isEmpty ? 'Cliente sin nombre' : p.cliente,
        subtitulo: '${p.codigo} · ${fechaCorta(p.fecha)}',
        pie: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TotalVenta(total),
            const SizedBox(height: AppEspaciado.sm + 4),
            BotonHoja(
              texto: p.esCanje ? 'Entregar canje' : 'Cobrar pedido',
              icono: p.esCanje
                  ? Icons.card_giftcard_rounded
                  : Icons.payments_rounded,
              onPressed: () {
                Navigator.pop(ctx);
                p.esCanje ? _entregar(p) : _cobrar(p);
              },
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (items.isEmpty)
              const SinProductosHoja()
            else
              for (final d in items)
                FilaDetalleVenta(
                  nombre: d.productoNombre,
                  cantidad: d.cantidad,
                  precio: d.precio,
                  unidad: d.unidadNombre,
                  total: d.subtotal,
                ),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- Cobrar
  Future<void> _cobrar(PedidoPendiente p) async {
    if (_tiposPago.isEmpty) {
      mostrarMensaje(
        context,
        'No hay métodos de pago configurados',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    final hecho = await mostrarHojaModerna<bool>(
      context,
      builder: (_) => _DialogoCobro(
        pedido: p,
        tiposPago: _tiposPago,
        controlador: _controlador,
      ),
    );
    if (hecho == true) await _cargar();
  }

  // --------------------------------------------------------------- Entregar
  Future<void> _entregar(PedidoPendiente p) async {
    final confirmado = await confirmarDialog(
      context,
      titulo: 'Entregar canje',
      mensaje:
          'El pedido ${p.codigo} se pagó con puntos. Al confirmar solo se marca '
          'como entregado: no se genera venta ni cobro.',
      icono: Icons.card_giftcard,
      textoConfirmar: 'Confirmar entrega',
    );
    if (!confirmado || !mounted) return;

    final resultado = await _controlador.entregarPedido(p.id);
    if (!mounted) return;
    mostrarMensaje(
      context,
      resultado.mensaje,
      tipo: resultado.exito ? TipoMensaje.exito : TipoMensaje.error,
    );
    if (resultado.exito) await _cargar();
  }

  // --------------------------------------------------------------- Cancelar
  Future<void> _cancelar(PedidoPendiente p) async {
    final confirmado = await confirmarDialog(
      context,
      titulo: '¿Cancelar pedido?',
      mensaje: 'Se cancelará el pedido ${p.codigo} por ${soles(p.montoTotal)}.',
      icono: Icons.cancel_outlined,
      textoConfirmar: 'Sí, cancelar',
      peligro: true,
    );
    if (!confirmado || !mounted) return;

    final resultado = await _controlador.cancelarPedido(p.id);
    if (!mounted) return;
    mostrarMensaje(
      context,
      resultado.mensaje,
      tipo: resultado.exito ? TipoMensaje.exito : TipoMensaje.error,
    );
    if (resultado.exito) await _cargar();
  }
}

/// Hoja de cobro de un pedido: elige el método de pago y, si es Yape, valida
/// el código de verificación del comprobante (con opción de reactivarlo si
/// expiró, igual que en el web).
class _DialogoCobro extends StatefulWidget {
  final PedidoPendiente pedido;
  final List<TipoPago> tiposPago;
  final ControladorVentas controlador;

  const _DialogoCobro({
    required this.pedido,
    required this.tiposPago,
    required this.controlador,
  });

  @override
  State<_DialogoCobro> createState() => _DialogoCobroState();
}

class _DialogoCobroState extends State<_DialogoCobro> {
  final _codigoCtrl = TextEditingController();
  late int _tipoPagoId;
  bool _procesando = false;
  bool _puedeReactivar = false;

  @override
  void initState() {
    super.initState();
    // Se preselecciona efectivo si existe; el admin puede cambiarlo.
    _tipoPagoId = widget.tiposPago
        .firstWhere((t) => t.esEfectivo, orElse: () => widget.tiposPago.first)
        .id;
  }

  @override
  void dispose() {
    _codigoCtrl.dispose();
    super.dispose();
  }

  TipoPago get _tipoPago =>
      widget.tiposPago.firstWhere((t) => t.id == _tipoPagoId);

  Future<void> _confirmar() async {
    final esYape = _tipoPago.esYape;
    final codigo = _codigoCtrl.text.trim();
    if (esYape && codigo.isEmpty) {
      mostrarMensaje(
        context,
        'Ingresa el código de verificación del pago Yape',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    setState(() {
      _procesando = true;
      _puedeReactivar = false;
    });
    final resultado = esYape
        ? await widget.controlador.validarPagoYape(widget.pedido.id, codigo)
        : await widget.controlador.atenderPedido(widget.pedido.id, _tipoPagoId);
    if (!mounted) return;
    setState(() => _procesando = false);

    if (resultado.exito) {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.exito);
      Navigator.of(context).pop(true);
      return;
    }
    // Si el código expiró se ofrece reactivarlo sin salir del diálogo.
    setState(
      () => _puedeReactivar =
          esYape &&
          RegExp('expir', caseSensitive: false).hasMatch(resultado.mensaje),
    );
    mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.advertencia);
  }

  Future<void> _reactivar() async {
    final codigo = _codigoCtrl.text.trim();
    if (codigo.isEmpty) return;
    setState(() => _procesando = true);
    final resultado = await widget.controlador.reactivarCodigoYape(codigo);
    if (!mounted) return;
    setState(() => _procesando = false);
    if (!resultado.exito) {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.error);
      return;
    }
    setState(() => _puedeReactivar = false);
    await _confirmar();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return HojaModerna(
      icono: Icons.payments_rounded,
      titulo: 'Cobrar pedido',
      subtitulo: '${p.codigo} · ${p.cliente}',
      pie: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TotalVenta(p.montoTotal, etiqueta: 'A cobrar'),
          const SizedBox(height: AppEspaciado.sm + 4),
          BotonHoja(
            texto: 'Confirmar venta',
            icono: Icons.check_rounded,
            cargando: _procesando,
            onPressed: _confirmar,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Método de pago',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm + 2),
          Wrap(
            spacing: AppEspaciado.sm,
            runSpacing: AppEspaciado.sm,
            children: [
              for (final t in widget.tiposPago)
                ChipApp(
                  texto: t.nombre,
                  icono: t.esYape
                      ? Icons.qr_code_2_rounded
                      : t.esEfectivo
                      ? Icons.payments_outlined
                      : Icons.credit_card_rounded,
                  activo: _tipoPagoId == t.id,
                  onTap: _procesando
                      ? null
                      : () => setState(() => _tipoPagoId = t.id),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppEspaciado.radio),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 20,
                  color: AppColores.primario,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Al confirmar se genera la venta y se descuenta el stock.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (_tipoPago.esYape) ...[
            // El cliente escanea el QR del negocio aquí mismo; después el
            // admin ingresa el código del comprobante para validar el pago.
            const SizedBox(height: AppEspaciado.md),
            const TarjetaQrYape(compacta: true),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: _codigoCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Código de verificación Yape',
                helperText: 'Código de seguridad del comprobante (ej. 815)',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.shield_outlined),
              ),
            ),
            if (_puedeReactivar) ...[
              const SizedBox(height: AppEspaciado.sm),
              TextButton.icon(
                onPressed: _procesando ? null : _reactivar,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Reactivar código (expiró)'),
              ),
            ],
          ],
          const SizedBox(height: AppEspaciado.md),
        ],
      ),
    );
  }
}
