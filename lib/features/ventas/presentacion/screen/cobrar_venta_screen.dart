import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/presentacion/widget/tarjeta_qr_yape.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/item_carrito.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/cliente_venta.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/tipo_pago.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';

/// Cierre de la venta del punto de venta: comprobante, cliente, método de pago
/// y vuelto. Replica las validaciones de `VentaActual.vue` del panel web.
///
/// Devuelve `true` al cerrarse si la venta llegó a registrarse.
class CobrarVentaScreen extends StatefulWidget {
  final int organizadorId;
  final List<ItemCarrito> items;

  const CobrarVentaScreen({
    super.key,
    required this.organizadorId,
    required this.items,
  });

  @override
  State<CobrarVentaScreen> createState() => _CobrarVentaScreenState();
}

class _CobrarVentaScreenState extends State<CobrarVentaScreen> {
  final _controlador = ControladorVentas();
  final _documentoCtrl = TextEditingController();
  final _montoCtrl = TextEditingController();

  /// '03' = boleta (por DNI) · '01' = factura (por RUC).
  String _tipoComprobante = '03';

  List<TipoPago> _tiposPago = const [];
  int? _tipoPagoId;
  ClienteVenta? _cliente;
  Permisos _permisos = Permisos.desde('', 0);

  bool _cargando = true;
  bool _buscando = false;
  bool _procesando = false;

  /// Método de pago elegido (null mientras no se cargan los tipos).
  TipoPago? get _tipoPagoSeleccionado {
    if (_tipoPagoId == null) return null;
    for (final t in _tiposPago) {
      if (t.id == _tipoPagoId) return t;
    }
    return null;
  }

  bool get _esFactura => _tipoComprobante == '01';
  int get _largoDocumento => _esFactura ? 11 : 8;

  double get _total => widget.items.fold(0.0, (a, i) => a + i.subtotal);
  double get _montoRecibido =>
      double.tryParse(_montoCtrl.text.replaceAll(',', '.')) ?? 0;
  double get _vuelto {
    final v = _montoRecibido - _total;
    return v > 0 ? v : 0;
  }

  @override
  void initState() {
    super.initState();
    _montoCtrl.text = _total.toStringAsFixed(2);
    _cargar();
  }

  @override
  void dispose() {
    _documentoCtrl.dispose();
    _montoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final permisos = await Permisos.cargar();
    List<TipoPago> tipos = const [];
    try {
      tipos = await _controlador.obtenerTiposPago();
    } catch (_) {
      // Sin métodos de pago no se puede cobrar; se avisa abajo con el aviso.
    }
    if (!mounted) return;
    setState(() {
      _permisos = permisos;
      _tiposPago = tipos;
      // Se preselecciona efectivo si existe, como en el mostrador.
      _tipoPagoId = tipos.isEmpty
          ? null
          : tipos.firstWhere((t) => t.esEfectivo, orElse: () => tipos.first).id;
      _cargando = false;
    });
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  void _cambiarComprobante(String tipo) {
    if (_tipoComprobante == tipo) return;
    setState(() {
      _tipoComprobante = tipo;
      // No se mezclan datos de una persona (boleta) con los de una empresa.
      _documentoCtrl.clear();
      _cliente = null;
    });
  }

  Future<void> _buscarCliente() async {
    final documento = _documentoCtrl.text.trim();
    if (documento.length != _largoDocumento) {
      mostrarMensaje(
        context,
        _esFactura
            ? 'El RUC debe tener 11 dígitos'
            : 'El DNI debe tener 8 dígitos',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    setState(() {
      _buscando = true;
      _cliente = null;
    });
    final cliente = _esFactura
        ? await _controlador.buscarClientePorRuc(documento)
        : await _controlador.buscarClientePorDni(documento);
    if (!mounted) return;
    setState(() {
      _cliente = cliente;
      _buscando = false;
    });
    if (cliente == null) {
      mostrarMensaje(
        context,
        _esFactura ? 'No se encontró el RUC' : 'El DNI no existe',
        tipo: TipoMensaje.advertencia,
      );
    }
  }

  /// Resuelve con qué caja se cobra. Devuelve `(true, id)` si se puede
  /// continuar; el id va en null cuando el Administrador cobra sin caja
  /// abierta (mismo permiso que en el web).
  Future<(bool, int?)> _resolverCaja() async {
    List<SesionCaja> abiertas = const [];
    try {
      abiertas = await _controlador.obtenerCajasAbiertas();
    } catch (_) {
      abiertas = const [];
    }
    if (!mounted) return (false, null);

    if (abiertas.isEmpty) {
      if (_permisos.esAdministrador) return (true, null);
      mostrarMensaje(
        context,
        'No hay una caja abierta en esta sucursal. Abre una caja antes de registrar la venta.',
        tipo: TipoMensaje.advertencia,
      );
      return (false, null);
    }
    if (abiertas.length == 1) return (true, abiertas.first.id);

    final elegida = await showDialog<SesionCaja>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Elige la caja'),
        children: [
          for (final s in abiertas)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(s),
              child: Text(s.etiqueta),
            ),
        ],
      ),
    );
    if (elegida == null) return (false, null);
    return (true, elegida.id);
  }

  Future<void> _registrarVenta() async {
    if (widget.items.isEmpty) return;
    final cliente = _cliente;
    if (cliente == null) {
      mostrarMensaje(
        context,
        _esFactura
            ? 'Busca la empresa por RUC antes de cobrar'
            : 'Busca al cliente por DNI antes de cobrar',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    if (_tipoPagoId == null) {
      mostrarMensaje(context, 'Selecciona el método de pago',
          tipo: TipoMensaje.advertencia);
      return;
    }
    if (_montoRecibido < _total) {
      mostrarMensaje(context, 'El monto recibido es menor que el total',
          tipo: TipoMensaje.advertencia);
      return;
    }

    setState(() => _procesando = true);
    final (puede, cajaSesionId) = await _resolverCaja();
    if (!puede) {
      if (mounted) setState(() => _procesando = false);
      return;
    }

    final resultado = await _controlador.registrarVenta(
      clienteId: cliente.id,
      organizadorId: widget.organizadorId,
      tipoPagoId: _tipoPagoId!,
      tipoComprobante: _tipoComprobante,
      totalPagar: _total,
      montoEntregado: _montoRecibido,
      items: widget.items,
      cajaSesionId: cajaSesionId,
    );
    if (!mounted) return;
    setState(() => _procesando = false);

    if (resultado.exito) {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.exito);
      Navigator.of(context).pop(true);
    } else {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Cobrar venta')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppEspaciado.md),
              children: [
                _tarjetaComprobante(),
                const SizedBox(height: AppEspaciado.md),
                _tarjetaMetodoPago(),
                const SizedBox(height: AppEspaciado.md),
                _tarjetaResumen(),
                const SizedBox(height: AppEspaciado.md),
                _tarjetaMonto(),
                const SizedBox(height: AppEspaciado.lg),
                SizedBox(
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _procesando ? null : _registrarVenta,
                    icon: _procesando
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.check_circle_outline),
                    label: Text(_procesando
                        ? 'Registrando...'
                        : 'Registrar venta · ${_soles(_total)}'),
                  ),
                ),
                const SizedBox(height: AppEspaciado.lg),
              ],
            ),
    );
  }

  // ------------------------------------------------------------- Comprobante
  Widget _tarjetaComprobante() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(
            titulo: 'Comprobante',
            subtitulo: 'Boleta por DNI o factura por RUC',
          ),
          const SizedBox(height: AppEspaciado.md),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: '03',
                label: Text('Boleta'),
                icon: Icon(Icons.receipt_long_outlined),
              ),
              ButtonSegment(
                value: '01',
                label: Text('Factura'),
                icon: Icon(Icons.description_outlined),
              ),
            ],
            selected: {_tipoComprobante},
            onSelectionChanged: (s) => _cambiarComprobante(s.first),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? AppColores.primario
                    : AppColores.superficie,
              ),
              foregroundColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? Colors.white
                    : AppColores.textoSecundario,
              ),
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          TextField(
            controller: _documentoCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(_largoDocumento),
            ],
            onSubmitted: (_) => _buscarCliente(),
            decoration: InputDecoration(
              labelText: _esFactura ? 'RUC' : 'DNI',
              hintText: _esFactura ? 'Ingresa el RUC' : 'Ingresa el DNI',
              prefixIcon: Icon(_esFactura
                  ? Icons.domain_outlined
                  : Icons.badge_outlined),
              suffixIcon: _buscando
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _buscarCliente,
                    ),
            ),
          ),
          if (_cliente != null) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            Row(
              children: [
                const Icon(Icons.check_circle,
                    color: AppColores.verde, size: 18),
                const SizedBox(width: AppEspaciado.sm),
                Expanded(
                  child: Text(
                    _cliente!.nombreCompleto,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Tipo de pago
  Widget _tarjetaMetodoPago() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(titulo: 'Método de pago'),
          const SizedBox(height: AppEspaciado.md),
          if (_tiposPago.isEmpty)
            const Text(
              'No hay métodos de pago configurados',
              style: TextStyle(color: AppColores.textoSecundario),
            )
          else
            Wrap(
              spacing: AppEspaciado.sm,
              runSpacing: AppEspaciado.sm,
              children: [
                for (final t in _tiposPago)
                  ChoiceChip(
                    label: Text(t.nombre),
                    selected: _tipoPagoId == t.id,
                    onSelected: (_) => setState(() => _tipoPagoId = t.id),
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
          // Con Yape se muestra el QR del negocio para que el cliente escanee
          // y pague ahí mismo, antes de confirmar la venta.
          if (_tipoPagoSeleccionado?.esYape ?? false) ...[
            const SizedBox(height: AppEspaciado.md),
            const TarjetaQrYape(),
          ],
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Resumen
  Widget _tarjetaResumen() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(
            titulo: 'Productos',
            subtitulo: '${widget.items.length} en la venta',
          ),
          const SizedBox(height: AppEspaciado.sm),
          for (final item in widget.items)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
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
                        Text(
                          '${item.cantidad} x ${_soles(item.precio)} · ${item.unidadNombre}',
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.textoSecundario),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    _soles(item.subtotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal),
                  ),
                ],
              ),
            ),
          const Divider(height: AppEspaciado.lg),
          Row(
            children: [
              const Text('Total',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text(
                _soles(_total),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColores.primario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Monto
  Widget _tarjetaMonto() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(titulo: 'Monto recibido'),
          const SizedBox(height: AppEspaciado.md),
          TextField(
            controller: _montoCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              prefixText: 'S/ ',
              prefixIcon: Icon(Icons.payments_outlined),
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              const Text('Vuelto',
                  style: TextStyle(
                      fontSize: 14, color: AppColores.textoSecundario)),
              const Spacer(),
              Text(
                _soles(_vuelto),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: AppColores.verde,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
