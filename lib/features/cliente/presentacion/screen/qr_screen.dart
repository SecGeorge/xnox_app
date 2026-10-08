import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/core/widgets/logo_gimnasio.dart';
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
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        child: m == null
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppEspaciado.md,
                  AppEspaciado.md,
                  AppEspaciado.md,
                  120,
                ),
                children: [
                  CabeceraApp(
                    titulo: 'Mi pase',
                    subtitulo:
                        'Muéstralo en recepción para registrar tu ingreso',
                    atras: false,
                    acciones: [
                      BotonRedondo(
                        icono: Icons.download_rounded,
                        tooltip: 'Guardar en la galería',
                        onTap: _descargando ? null : _descargarQr,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  RepaintBoundary(key: _qrKey, child: _pase(m)),
                  const SizedBox(height: AppEspaciado.lg),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _descargando ? null : _descargarQr,
                      icon: _descargando
                          ? SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColores.sobreRelleno,
                              ),
                            )
                          : const Icon(Icons.download_rounded),
                      label: Text(
                        _descargando
                            ? 'Guardando…'
                            : 'Guardar pase en la galería',
                      ),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppEspaciado.radio,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  /// Pase tipo ticket: foto con el logo arriba, el QR en el centro y el
  /// estado de la membresía al pie. Es lo que se guarda como imagen.
  Widget _pase(MembresiaCliente m) {
    final dias = m.diasRestantes;
    final conPlan = m.contratoId != null;
    final vigente = conPlan && dias >= 0;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 8),
        border: Border.all(color: AppColores.borde),
        boxShadow: [
          BoxShadow(
            color: AppColores.primario.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 96,
            child: FotoTarjeta(
              foto: FotosApp.rutinas,
              alineacion: const Alignment(0, -0.2),
              radio: 0,
              degradadoHorizontal: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    const LogoGimnasio(tamano: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ValueListenableBuilder<MarcaGimnasio>(
                        valueListenable: ControladorMarca.instancia.marca,
                        builder: (_, marca, _) => Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'PASE DE INGRESO',
                              style: TextStyle(
                                fontSize: 11,
                                letterSpacing: 1.4,
                                fontWeight: FontWeight.w800,
                                color: AppColores.destacado,
                              ),
                            ),
                            Text(
                              (marca.nombre ?? '').isEmpty
                                  ? 'Mi gimnasio'
                                  : marca.nombre!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
            child: Column(
              children: [
                QrImageView(
                  data: m.codigoQr,
                  version: QrVersions.auto,
                  size: 230,
                  eyeStyle: QrEyeStyle(
                    eyeShape: QrEyeShape.square,
                    color: AppColores.primario,
                  ),
                  dataModuleStyle: QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square,
                    color: AppColores.primario,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  m.nombre.isEmpty ? 'Socio' : m.nombre,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.codigoQr,
                  style: const TextStyle(
                    fontSize: 13.5,
                    letterSpacing: 2,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          // Corte del ticket.
          Row(
            children: [
              for (var i = 0; i < 26; i++)
                Expanded(
                  child: Container(
                    height: 1.5,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    color: i.isEven ? AppColores.borde : Colors.transparent,
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Row(
              children: [
                IconoSuave(
                  vigente ? Icons.verified_rounded : Icons.event_busy_rounded,
                  color: vigente ? AppColores.activo : AppColores.vencido,
                  circular: true,
                  tamano: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conPlan ? m.plan : 'Sin membresía activa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      Text(
                        !conPlan
                            ? 'Acércate a recepción'
                            : dias < 0
                            ? 'Venció el ${DateFormat('d MMM', 'es').format(m.fechaVencimiento)}'
                            : 'Vence el ${DateFormat('d MMM yyyy', 'es').format(m.fechaVencimiento)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                if (conPlan)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (vigente ? AppColores.activo : AppColores.vencido)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      dias < 0
                          ? 'Vencida'
                          : dias == 0
                          ? 'Hoy'
                          : '$dias d',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: vigente ? AppColores.activo : AppColores.vencido,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
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
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _descargando = false);
    }
  }
}
