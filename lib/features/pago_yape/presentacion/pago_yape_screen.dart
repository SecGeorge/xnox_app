import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/datos/repositorio_pago_yape.dart';
import 'package:xnox_app/features/pago_yape/dominio/config_pago_yape.dart';

/// Pantalla de pago por Yape para el cliente. Muestra el QR y el número del
/// negocio, el monto y el concepto, y permite reportar el pago.
///
/// - [monto]: importe a pagar (S/).
/// - [concepto]: descripción (ej. "Pedido GYM-00021" o "Membresía").
/// - [pedidoId]: si es un pedido de la tienda, su id (para reportar el pago).
///   Para deuda de membresía u otros, dejar en null.
class PagoYapeScreen extends StatefulWidget {
  final double monto;
  final String concepto;
  final int? pedidoId;

  const PagoYapeScreen({
    super.key,
    required this.monto,
    required this.concepto,
    this.pedidoId,
  });

  @override
  State<PagoYapeScreen> createState() => _PagoYapeScreenState();
}

class _PagoYapeScreenState extends State<PagoYapeScreen> {
  final _repositorio = RepositorioPagoYape();
  final _qrKey = GlobalKey();

  ConfigPagoYape? _config;
  bool _cargando = true;
  bool _descargando = false;
  bool _reportando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
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
          ElevatedButton.icon(
            onPressed: () => _abrirYape(c),
            style: ElevatedButton.styleFrom(backgroundColor: AppColores.morado),
            icon: const Icon(Icons.account_balance_wallet),
            label: const Text('Abrir app de Yape'),
          ),
          const SizedBox(height: AppEspaciado.sm),
          OutlinedButton.icon(
            onPressed: _reportando ? null : _confirmarPago,
            icon: _reportando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: const Text('Ya pagué'),
          ),
          const SizedBox(height: AppEspaciado.md),
          const Text(
            'Tu pago será confirmado por el gimnasio.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColores.textoSecundario),
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
          colors: [AppColores.morado, Color(0xFF9D86FF)],
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
          RepaintBoundary(
            key: _qrKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(AppEspaciado.sm),
              child: Image.network(
                c.qrUrl!,
                height: 240,
                fit: BoxFit.contain,
                loadingBuilder: (ctx, child, progress) => progress == null
                    ? child
                    : const SizedBox(
                        height: 240,
                        child: Center(child: CircularProgressIndicator()),
                      ),
                errorBuilder: (_, _, _) => const SizedBox(
                  height: 240,
                  child: Center(
                    child: Text('No se pudo cargar el QR',
                        style: TextStyle(color: AppColores.textoSecundario)),
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
                icon: const Icon(Icons.copy, color: AppColores.morado),
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

  Future<void> _abrirYape(ConfigPagoYape c) async {
    // Intentamos abrir la app de Yape. Si no está instalada o el esquema no es
    // accesible, copiamos el número como respaldo.
    try {
      final abierto = await launchUrl(
        Uri.parse('yape://'),
        mode: LaunchMode.externalApplication,
      );
      if (!abierto) throw Exception('no abrió');
    } catch (_) {
      if (!mounted) return;
      Clipboard.setData(ClipboardData(text: c.numero));
      mostrarMensaje(
        context,
        'Abre tu app de Yape manualmente. Copiamos el número ${c.numero}.',
        tipo: TipoMensaje.advertencia,
      );
    }
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

  Future<void> _confirmarPago() async {
    final confirmar = await confirmarDialog(
      context,
      titulo: '¿Ya realizaste el pago?',
      mensaje:
          'Confirma solo si ya pagaste ${_soles(widget.monto)} por Yape. '
          'El gimnasio verificará tu pago.',
      icono: Icons.account_balance_wallet,
      textoConfirmar: 'Sí, ya pagué',
    );
    if (!confirmar) return;

    // Para pedidos, registramos el reporte en el backend.
    if (widget.pedidoId != null) {
      setState(() => _reportando = true);
      final error = await _repositorio.reportarPagoPedido(widget.pedidoId!);
      if (!mounted) return;
      setState(() => _reportando = false);
      if (error != null) {
        mostrarMensaje(context, error, tipo: TipoMensaje.error);
        return;
      }
    }

    if (!mounted) return;
    mostrarMensaje(
      context,
      '¡Gracias! Tu pago será confirmado por el gimnasio.',
      tipo: TipoMensaje.exito,
    );
    Navigator.of(context).pop(true);
  }
}
