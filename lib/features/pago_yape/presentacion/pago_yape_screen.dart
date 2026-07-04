import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/datos/repositorio_pago_yape.dart';
import 'package:xnox_app/features/pago_yape/dominio/config_pago_yape.dart';

/// Pantalla de pago por Yape para el cliente. Muestra el QR y el número del
/// negocio, el monto y el concepto, y permite reportar el pago.
///
/// - [monto]: importe a pagar (S/).
/// - [concepto]: descripción (ej. "Pedido GYM-00021" o "Membresía").
/// - [pedidoId]: si es un pedido de la tienda, su id (para validar el pago).
/// - [contratoId]: si es deuda de membresía, el id del contrato (para validar
///   el pago y saldar la deuda). Se usa cuando [pedidoId] es null.
class PagoYapeScreen extends StatefulWidget {
  final double monto;
  final String concepto;
  final int? pedidoId;
  final int? contratoId;

  const PagoYapeScreen({
    super.key,
    required this.monto,
    required this.concepto,
    this.pedidoId,
    this.contratoId,
  });

  @override
  State<PagoYapeScreen> createState() => _PagoYapeScreenState();
}

class _PagoYapeScreenState extends State<PagoYapeScreen> {
  final _repositorio = RepositorioPagoYape();
  final _qrKey = GlobalKey();
  final _codigoController = TextEditingController();

  ConfigPagoYape? _config;
  bool _cargando = true;
  bool _descargando = false;
  bool _validando = false;

  /// `true` si tenemos con qué validar el pago (pedido o contrato).
  bool get _puedeValidar => widget.pedidoId != null || widget.contratoId != null;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _codigoController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final config = await _repositorio.obtenerConfig();
      if (!mounted) return;
      setState(() {
        _config = config;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Pagar por Yape')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _config == null || !_config!.disponible
              ? _sinConfig()
              : _contenido(_config!),
    );
  }

  Widget _sinConfig() {
    return ListView(
      children: const [
        SizedBox(height: 100),
        EstadoVacio(
          icono: Icons.qr_code_2_outlined,
          mensaje:
              'El gimnasio aún no configuró un número de Yape para cobrar.\n'
              'Comunícate con recepción.',
        ),
      ],
    );
  }

  Widget _contenido(ConfigPagoYape c) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppEspaciado.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _tarjetaMonto(),
          const SizedBox(height: AppEspaciado.md),
          if (c.tieneQr) _tarjetaQr(c) else _tarjetaSinQr(),
          const SizedBox(height: AppEspaciado.md),
          _tarjetaNumero(c),
          const SizedBox(height: AppEspaciado.lg),
          if (_puedeValidar)
            _tarjetaCodigo()
          else
            const Text(
              'Tu pago será confirmado por el gimnasio.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColores.textoSecundario),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaCodigo() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Confirma tu pago',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Escribe el código de seguridad que aparece en tu comprobante de '
            'Yape (ej. 815). Verificaremos tu pago al instante.',
            style: TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
          ),
          const SizedBox(height: AppEspaciado.md),
          TextField(
            controller: _codigoController,
            enabled: !_validando,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 12,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
            ),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '– – –',
              border: OutlineInputBorder(),
              labelText: 'Código de seguridad',
            ),
            onSubmitted: (_) => _validando ? null : _validarPago(),
          ),
          const SizedBox(height: AppEspaciado.sm),
          ElevatedButton.icon(
            onPressed: _validando ? null : _validarPago,
            icon: _validando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.verified_outlined),
            label: Text(_validando ? 'Verificando...' : 'Validar y confirmar'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaMonto() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        children: [
          Text(
            widget.concepto,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 6),
          Text(
            _soles(widget.monto),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaQr(ConfigPagoYape c) {
    return TarjetaApp(
      child: Column(
        children: [
          const Text(
            'Escanea este QR desde tu app de Yape',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Center(
            child: RepaintBoundary(
              key: _qrKey,
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppEspaciado.sm),
                child: Image.network(
                  c.qrUrl!,
                  width: 240,
                  height: 240,
                  fit: BoxFit.contain,
                  loadingBuilder: (ctx, child, progress) => progress == null
                      ? child
                      : const SizedBox(
                          width: 240,
                          height: 240,
                          child: Center(child: CircularProgressIndicator()),
                        ),
                  errorBuilder: (_, _, _) => const SizedBox(
                    width: 240,
                    height: 240,
                    child: Center(
                      child: Text('No se pudo cargar el QR',
                          style: TextStyle(color: AppColores.textoSecundario)),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          TextButton.icon(
            onPressed: _descargando ? null : _descargarQr,
            icon: _descargando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.download, size: 18),
            label: Text(_descargando ? 'Guardando...' : 'Descargar QR'),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaSinQr() {
    return TarjetaApp(
      child: Row(
        children: const [
          Icon(Icons.info_outline, color: AppColores.deudor),
          SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              'Paga directamente al número de Yape de abajo.',
              style: TextStyle(fontSize: 13, color: AppColores.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaNumero(ConfigPagoYape c) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Número de Yape',
              style: TextStyle(fontSize: 12, color: AppColores.textoSecundario)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  c.numero,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _copiarNumero(c.numero),
                icon: const Icon(Icons.copy, color: AppColores.acento),
                tooltip: 'Copiar número',
              ),
            ],
          ),
          if (c.titular.trim().isNotEmpty) ...[
            const Divider(height: AppEspaciado.lg),
            Row(
              children: [
                const Icon(Icons.person_outline,
                    size: 18, color: AppColores.textoSecundario),
                const SizedBox(width: AppEspaciado.sm),
                Expanded(
                  child: Text(
                    c.titular,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _copiarNumero(String numero) {
    Clipboard.setData(ClipboardData(text: numero));
    mostrarMensaje(context, 'Número copiado: $numero', tipo: TipoMensaje.info);
  }

  Future<void> _descargarQr() async {
    setState(() => _descargando = true);
    try {
      final boundary =
          _qrKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();
      await Gal.putImageBytes(bytes, name: 'yape_qr_${widget.pedidoId ?? 'pago'}');
      if (!mounted) return;
      mostrarMensaje(context, 'QR guardado en la galería',
          tipo: TipoMensaje.exito);
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo guardar el QR',
          tipo: TipoMensaje.error);
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }

  Future<void> _validarPago() async {
    final codigo = _codigoController.text.trim();
    if (codigo.isEmpty) {
      mostrarMensaje(
        context,
        'Escribe el código de seguridad de tu pago Yape',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    // Cerramos el teclado antes de validar.
    FocusScope.of(context).unfocus();
    setState(() => _validando = true);

    ResultadoPagoYape resultado;
    if (widget.pedidoId != null) {
      resultado = await _repositorio.validarPagoPedido(widget.pedidoId!, codigo);
    } else {
      resultado = await _repositorio.validarPagoMembresia(
        widget.contratoId!,
        widget.monto,
        codigo,
      );
    }

    if (!mounted) return;
    setState(() => _validando = false);

    if (resultado.ok) {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.exito);
      Navigator.of(context).pop(true);
    } else {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.error);
    }
  }
}
