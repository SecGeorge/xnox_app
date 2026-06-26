import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_membresia.dart';

/// Pantalla del QR de ingreso del cliente: lo muestra en grande y permite
/// descargarlo como imagen a la galería.
class QrScreen extends StatefulWidget {
  const QrScreen({super.key});

  @override
  State<QrScreen> createState() => _QrScreenState();
}

class _QrScreenState extends State<QrScreen> {
  final _controlador = ControladorMembresia();
  final _qrKey = GlobalKey();
  MembresiaCliente? _membresia;
  bool _descargando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final m = await _controlador.obtenerMembresia();
    if (!mounted) return;
    setState(() => _membresia = m);
  }

  @override
  Widget build(BuildContext context) {
    final m = _membresia;
    return SafeArea(
      child: m == null
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(AppEspaciado.lg),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Mi QR de Ingreso',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColores.textoPrincipal),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Muéstralo en recepción para registrar tu ingreso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13.5, color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: AppEspaciado.xl),
                  RepaintBoundary(
                    key: _qrKey,
                    child: Container(
                      padding: const EdgeInsets.all(AppEspaciado.lg),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(AppEspaciado.radio),
                        boxShadow: AppSombras.tarjeta,
                        border: Border.all(color: AppColores.borde),
                      ),
                      child: Column(
                        children: [
                          QrImageView(
                            data: m.codigoQr,
                            version: QrVersions.auto,
                            size: 220,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: AppColores.primario,
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: AppColores.primario,
                            ),
                          ),
                          const SizedBox(height: AppEspaciado.md),
                          Text(
                            m.nombre,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColores.textoPrincipal),
                          ),
                          Text(
                            m.codigoQr,
                            style: const TextStyle(
                                fontSize: 13,
                                letterSpacing: 1.5,
                                color: AppColores.textoSecundario),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppEspaciado.xl),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _descargando ? null : _descargarQr,
                      icon: _descargando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.download),
                      label: Text(
                          _descargando ? 'Guardando...' : 'Descargar QR'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Future<void> _descargarQr() async {
    setState(() => _descargando = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List bytes = byteData!.buffer.asUint8List();

      await Gal.putImageBytes(bytes, name: 'qr_${_membresia?.codigoQr}');

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('QR guardado en la galería')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('No se pudo guardar: $e'),
            backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }
}
