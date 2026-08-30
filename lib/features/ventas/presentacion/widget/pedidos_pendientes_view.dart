import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/presentacion/widget/tarjeta_qr_yape.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/pedido_pendiente.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/tipo_pago.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';

/// Pedidos que los clientes hacen desde la app y que el admin todavía no cobra.
/// Es la versión móvil de `Ventas > Pedidos pendientes` del panel web.
class PedidosPendientesView extends StatefulWidget {
  const PedidosPendientesView({super.key});

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

  Future<void> _cargar() async {
    setState(() => _cargando = true);
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
      mostrarMensaje(context, 'No se pudieron cargar los pedidos',
          tipo: TipoMensaje.error);
    }
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  String _fecha(String valor) {
    final f = DateTime.tryParse(valor);
    return f == null ? valor : DateFormat('dd/MM/yyyy').format(f);
  }

  List<PedidoPendiente> get _filtrados {
    final t = _busqueda.toLowerCase().trim();
    if (t.isEmpty) return _pedidos;
    return _pedidos
        .where((p) =>
            p.codigo.toLowerCase().contains(t) ||
            p.cliente.toLowerCase().contains(t) ||
            p.dni.toLowerCase().contains(t))
        .toList();
  }

  double get _totalPendiente =>
      _filtrados.fold(0.0, (a, p) => a + (p.esCanje ? 0 : p.montoTotal));
  int get _totalProductos => _filtrados.fold(0, (a, p) => a + p.items);
  int get _clientesDistintos => _filtrados.map((p) => p.miembroId).toSet().length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                    AppEspaciado.sm, AppEspaciado.md, AppEspaciado.lg),
                children: [
                  _banner(),
                  const SizedBox(height: AppEspaciado.md),
                  _resumen(),
                  const SizedBox(height: AppEspaciado.md),
                  _buscador(),
                  const SizedBox(height: AppEspaciado.md),
                  if (_filtrados.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EstadoVacio(
                        icono: Icons.receipt_long_outlined,
                        mensaje: 'No hay pedidos pendientes',
                      ),
                    )
                  else
                    for (final p in _filtrados) ...[
                      _tarjetaPedido(p),
                      const SizedBox(height: AppEspaciado.sm + 4),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: const Icon(Icons.shopping_basket_outlined,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppEspaciado.md),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pedidos de clientes',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Revisa y cobra los pedidos hechos desde la app',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _resumen() {
    return Row(
      children: [
        Expanded(
          child: _tarjetaDato('Pendientes', '${_filtrados.length}',
              Icons.assignment_outlined, AppColores.azul),
        ),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: _tarjetaDato('Por cobrar', _soles(_totalPendiente),
              Icons.payments_outlined, AppColores.verde),
        ),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: _tarjetaDato('Productos', '$_totalProductos',
              Icons.inventory_2_outlined, AppColores.naranja),
        ),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: _tarjetaDato('Clientes', '$_clientesDistintos',
              Icons.groups_outlined, AppColores.morado),
        ),
      ],
    );
  }

  Widget _tarjetaDato(String titulo, String valor, IconData icono, Color color) {
    return TarjetaApp(
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.sm, vertical: AppEspaciado.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: AppEspaciado.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(
                fontSize: 11, color: AppColores.textoSecundario),
          ),
        ],
      ),
    );
  }

  Widget _buscador() {
    return TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar por cliente, código o documento...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
          onPressed: _cargar,
        ),
      ),
    );
  }

  Widget _tarjetaPedido(PedidoPendiente p) {
    return TarjetaApp(
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColores.primario.withValues(alpha: 0.10),
                child: Text(
                  p.inicial,
                  style: const TextStyle(
                    color: AppColores.primario,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppEspaciado.sm + 4),
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
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${p.codigo} · ${_fecha(p.fecha)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColores.textoSecundario),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    p.esCanje ? 'Gratis' : _soles(p.montoTotal),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: p.esCanje ? AppColores.morado : AppColores.verde,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${p.items} ${p.items == 1 ? 'ítem' : 'ítems'}',
                    style: const TextStyle(
                        fontSize: 11.5, color: AppColores.textoSecundario),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          Row(
            children: [
              EtiquetaEstado(
                texto: p.esCanje ? 'Canje por puntos' : 'Pendiente',
                color: p.esCanje ? AppColores.morado : AppColores.naranja,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.visibility_outlined),
                color: AppColores.primario,
                tooltip: 'Ver detalle',
                onPressed: () => _verDetalle(p),
              ),
              IconButton(
                icon: const Icon(Icons.cancel_outlined),
                color: AppColores.moroso,
                tooltip: 'Cancelar pedido',
                onPressed: () => _cancelar(p),
              ),
              const SizedBox(width: AppEspaciado.xs),
              ElevatedButton.icon(
                onPressed: () => p.esCanje ? _entregar(p) : _cobrar(p),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      p.esCanje ? AppColores.morado : AppColores.verde,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppEspaciado.md, vertical: 10),
                ),
                icon: Icon(
                    p.esCanje ? Icons.card_giftcard : Icons.point_of_sale,
                    size: 17),
                label: Text(p.esCanje ? 'Entregar' : 'Cobrar'),
              ),
            ],
          ),
        ],
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
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppEspaciado.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoSeccion(
              titulo: 'Detalle del pedido',
              subtitulo: '${p.codigo} · ${p.cliente}',
            ),
            const SizedBox(height: AppEspaciado.md),
            if (items.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Sin productos',
                    style: TextStyle(color: AppColores.textoSecundario)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final d = items[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.productoNombre,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d.cantidad.toStringAsFixed(0)} x ${_soles(d.precio)} · ${d.unidadNombre}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColores.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _soles(d.subtotal),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColores.textoPrincipal),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const Divider(height: AppEspaciado.lg),
            Row(
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  _soles(total),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColores.primario,
                  ),
                ),
              ],
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
      mostrarMensaje(context, 'No hay métodos de pago configurados',
          tipo: TipoMensaje.advertencia);
      return;
    }
    final hecho = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoCobro(
        pedido: p,
        tiposPago: _tiposPago,
        controlador: _controlador,
        formatearSoles: _soles,
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
    mostrarMensaje(context, resultado.mensaje,
        tipo: resultado.exito ? TipoMensaje.exito : TipoMensaje.error);
    if (resultado.exito) await _cargar();
  }

  // --------------------------------------------------------------- Cancelar
  Future<void> _cancelar(PedidoPendiente p) async {
    final confirmado = await confirmarDialog(
      context,
      titulo: '¿Cancelar pedido?',
      mensaje:
          'Se cancelará el pedido ${p.codigo} por ${_soles(p.montoTotal)}.',
      icono: Icons.cancel_outlined,
      textoConfirmar: 'Sí, cancelar',
      peligro: true,
    );
    if (!confirmado || !mounted) return;

    final resultado = await _controlador.cancelarPedido(p.id);
    if (!mounted) return;
    mostrarMensaje(context, resultado.mensaje,
        tipo: resultado.exito ? TipoMensaje.exito : TipoMensaje.error);
    if (resultado.exito) await _cargar();
  }
}

/// Diálogo de cobro de un pedido: elige el método de pago y, si es Yape, valida
/// el código de verificación del comprobante (con opción de reactivarlo si
/// expiró, igual que en el web).
class _DialogoCobro extends StatefulWidget {
  final PedidoPendiente pedido;
  final List<TipoPago> tiposPago;
  final ControladorVentas controlador;
  final String Function(double) formatearSoles;

  const _DialogoCobro({
    required this.pedido,
    required this.tiposPago,
    required this.controlador,
    required this.formatearSoles,
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
      mostrarMensaje(context, 'Ingresa el código de verificación del pago Yape',
          tipo: TipoMensaje.advertencia);
      return;
    }

    setState(() {
      _procesando = true;
      _puedeReactivar = false;
    });
    final resultado = esYape
        ? await widget.controlador.validarPagoYape(widget.pedido.id, codigo)
        : await widget.controlador
            .atenderPedido(widget.pedido.id, _tipoPagoId);
    if (!mounted) return;
    setState(() => _procesando = false);

    if (resultado.exito) {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.exito);
      Navigator.of(context).pop(true);
      return;
    }
    // Si el código expiró se ofrece reactivarlo sin salir del diálogo.
    setState(() => _puedeReactivar =
        esYape && RegExp('expir', caseSensitive: false).hasMatch(resultado.mensaje));
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
    return AlertDialog(
      backgroundColor: AppColores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
      ),
      title: const Text('Confirmar cobro', style: TextStyle(fontSize: 18)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(AppEspaciado.sm + 4),
              decoration: BoxDecoration(
                color: AppColores.fondo,
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Pedido ${p.codigo}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    widget.formatearSoles(p.montoTotal),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColores.verde,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppEspaciado.sm + 4),
            const Text(
              'Al confirmar se genera la venta y se descuenta el stock.',
              style:
                  TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
            ),
            const SizedBox(height: AppEspaciado.md),
            Wrap(
              spacing: AppEspaciado.sm,
              runSpacing: AppEspaciado.sm,
              children: [
                for (final t in widget.tiposPago)
                  ChoiceChip(
                    label: Text(t.nombre),
                    selected: _tipoPagoId == t.id,
                    onSelected: _procesando
                        ? null
                        : (_) => setState(() => _tipoPagoId = t.id),
                    selectedColor: AppColores.primario,
                    labelStyle: TextStyle(
                      color: _tipoPagoId == t.id
                          ? Colors.white
                          : AppColores.textoPrincipal,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
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
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _procesando ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        ElevatedButton.icon(
          onPressed: _procesando ? null : _confirmar,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColores.verde,
            foregroundColor: Colors.white,
          ),
          icon: _procesando
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check, size: 18),
          label: const Text('Confirmar venta'),
        ),
      ],
    );
  }
}
