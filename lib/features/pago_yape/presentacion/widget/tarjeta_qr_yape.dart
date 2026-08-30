import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/datos/repositorio_pago_yape.dart';
import 'package:xnox_app/features/pago_yape/dominio/config_pago_yape.dart';

/// QR y número de Yape del negocio (los que se suben en Ajustes > Pago por
/// Yape) para mostrárselos al cliente en el momento del cobro.
///
/// Se usa en el punto de venta y en el cobro de pedidos: en cuanto el admin
/// elige Yape como método de pago, el cliente ya puede escanear desde su app.
/// Con [compacta] en true se dibuja un QR más chico, pensado para diálogos.
class TarjetaQrYape extends StatefulWidget {
  final bool compacta;

  const TarjetaQrYape({super.key, this.compacta = false});

  @override
  State<TarjetaQrYape> createState() => _TarjetaQrYapeState();
}

class _TarjetaQrYapeState extends State<TarjetaQrYape> {
  final _repositorio = RepositorioPagoYape();
  ConfigPagoYape? _config;
  bool _cargando = true;

  double get _lado => widget.compacta ? 170 : 220;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
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

  void _copiarNumero(String numero) {
    Clipboard.setData(ClipboardData(text: numero));
    mostrarMensaje(context, 'Número copiado: $numero', tipo: TipoMensaje.info);
  }

  /// Amplía el QR a pantalla completa: en mostrador es más cómodo girar el
  /// teléfono hacia el cliente con el código lo más grande posible.
  void _ampliar(String url) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.all(AppEspaciado.md),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppEspaciado.radio),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InteractiveViewer(
                maxScale: 4,
                child: Image.network(url, fit: BoxFit.contain),
              ),
              const SizedBox(height: AppEspaciado.sm),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_cargando) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: AppEspaciado.md),
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    final c = _config;
    if (c == null || !c.disponible) return _aviso();

    return Container(
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          const Text(
            'Muestra este QR al cliente para que pague con Yape',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          if (c.tieneQr) _qr(c.qrUrl!) else _sinQr(),
          const SizedBox(height: AppEspaciado.sm + 4),
          _numero(c),
        ],
      ),
    );
  }

  Widget _qr(String url) {
    return InkWell(
      onTap: () => _ampliar(url),
      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.all(AppEspaciado.sm),
        child: Image.network(
          url,
          width: _lado,
          height: _lado,
          fit: BoxFit.contain,
          loadingBuilder: (_, child, progress) => progress == null
              ? child
              : SizedBox(
                  width: _lado,
                  height: _lado,
                  child: const Center(child: CircularProgressIndicator()),
                ),
          errorBuilder: (_, _, _) => SizedBox(
            width: _lado,
            height: _lado,
            child: const Center(
              child: Text(
                'No se pudo cargar el QR',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColores.textoSecundario),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// El negocio tiene número de Yape pero no subió la imagen del QR.
  Widget _sinQr() {
    return SizedBox(
      width: _lado,
      height: _lado * 0.5,
      child: const Center(
        child: Text(
          'Aún no subes la imagen del QR.\nEl cliente puede pagar al número.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
        ),
      ),
    );
  }

  Widget _numero(ConfigPagoYape c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.numero,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: AppColores.textoPrincipal,
                ),
              ),
              if (c.titular.trim().isNotEmpty)
                Text(
                  c.titular,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textoSecundario),
                ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _copiarNumero(c.numero),
          icon: const Icon(Icons.copy, size: 18, color: AppColores.acento),
          tooltip: 'Copiar número',
          visualDensity: VisualDensity.compact,
        ),
      ],
    );
  }

  /// Sin número configurado no hay nada que mostrar: se guía al admin a Ajustes.
  Widget _aviso() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
      decoration: BoxDecoration(
        color: AppColores.deudor.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: const Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: AppColores.deudor),
          SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              'Configura tu número y QR en Ajustes > Pago por Yape para '
              'mostrárselo al cliente.',
              style: TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
            ),
          ),
        ],
      ),
    );
  }
}
