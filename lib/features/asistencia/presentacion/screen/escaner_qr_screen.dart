import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Cámara a pantalla completa para leer el QR del pase del socio. Devuelve el
/// texto del primer código leído (el DNI del socio).
class EscanerQrScreen extends StatefulWidget {
  const EscanerQrScreen({super.key});

  @override
  State<EscanerQrScreen> createState() => _EscanerQrScreenState();
}

class _EscanerQrScreenState extends State<EscanerQrScreen> {
  final _camara = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    formats: const [BarcodeFormat.qrCode],
  );
  bool _leido = false;

  @override
  void dispose() {
    _camara.dispose();
    super.dispose();
  }

  void _alDetectar(BarcodeCapture captura) {
    if (_leido) return;
    final valor = captura.barcodes
        .map((b) => b.rawValue?.trim() ?? '')
        .firstWhere((v) => v.isNotEmpty, orElse: () => '');
    if (valor.isEmpty) return;
    _leido = true;
    Navigator.of(context).pop(valor);
  }

  @override
  Widget build(BuildContext context) {
    const lado = 250.0;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _camara,
            onDetect: _alDetectar,
            errorBuilder: (context, error) => Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  error.errorCode == MobileScannerErrorCode.permissionDenied
                      ? 'Da permiso a la cámara para escanear el QR.'
                      : 'No se pudo abrir la cámara.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),
            ),
          ),
          // Oscurece todo menos el recuadro.
          ColorFiltered(
            colorFilter: ColorFilter.mode(
              Colors.black.withValues(alpha: 0.55),
              BlendMode.srcOut,
            ),
            child: Stack(
              children: [
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black,
                    backgroundBlendMode: BlendMode.dstOut,
                  ),
                ),
                Center(
                  child: Container(
                    width: lado,
                    height: lado,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Center(
            child: Container(
              width: lado,
              height: lado,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                border: Border.all(color: AppColores.destacado, width: 3),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(AppEspaciado.md),
              child: Column(
                children: [
                  Row(
                    children: [
                      _botonRedondo(
                        Icons.close_rounded,
                        () => Navigator.of(context).pop(),
                      ),
                      const Spacer(),
                      ValueListenableBuilder(
                        valueListenable: _camara,
                        builder: (_, estado, _) => _botonRedondo(
                          estado.torchState == TorchState.on
                              ? Icons.flash_on_rounded
                              : Icons.flash_off_rounded,
                          () => _camara.toggleTorch(),
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const Text(
                    'Escanea el pase del socio',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Pídele que abra "Mi pase" en su app',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 13.5,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonRedondo(IconData icono, VoidCallback onTap) {
    return Material(
      color: Colors.black.withValues(alpha: 0.45),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Icon(icono, color: Colors.white),
        ),
      ),
    );
  }
}
