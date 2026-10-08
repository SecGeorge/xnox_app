import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/datos_negocio.dart';
import 'package:xnox_app/features/ajustes/presentacion/controlador/controlador_ajustes.dart';

/// Configuración del pago por Yape del negocio (solo administrador):
/// número de Yape, titular y la imagen del QR que verán los clientes.
class ConfigYapeScreen extends StatefulWidget {
  const ConfigYapeScreen({super.key});

  @override
  State<ConfigYapeScreen> createState() => _ConfigYapeScreenState();
}

class _ConfigYapeScreenState extends State<ConfigYapeScreen> {
  final _controlador = ControladorAjustes();
  final _formKey = GlobalKey<FormState>();

  final _numeroController = TextEditingController();
  final _titularController = TextEditingController();

  DatosNegocio? _datos;
  File? _qrNuevo; // QR recién elegido (aún no subido).
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _numeroController.dispose();
    _titularController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final datos = await _controlador.obtenerDatosNegocio();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _numeroController.text = datos.yapeNumero;
        _titularController.text = datos.yapeTitular;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarMensaje(
        context,
        'No se pudo cargar la configuración',
        tipo: TipoMensaje.error,
      );
    }
  }

  Future<void> _elegirQr() async {
    final picker = ImagePicker();
    final XFile? img = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 90,
    );
    if (img != null) {
      setState(() => _qrNuevo = File(img.path));
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final id = _datos?.id;
    if (id == null) {
      mostrarMensaje(
        context,
        'No se encontró el id del negocio',
        tipo: TipoMensaje.error,
      );
      return;
    }

    String? qrBase64;
    if (_qrNuevo != null) {
      final bytes = await _qrNuevo!.readAsBytes();
      qrBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
    }

    setState(() => _isSaving = true);
    final error = await _controlador.guardarYape(
      id: id,
      numero: _numeroController.text.trim(),
      titular: _titularController.text.trim(),
      qrBase64: qrBase64,
    );
    if (!mounted) return;
    setState(() => _isSaving = false);

    if (error == null) {
      mostrarMensaje(
        context,
        'Configuración de Yape guardada',
        tipo: TipoMensaje.exito,
      );
      Navigator.of(context).pop(true);
    } else {
      mostrarMensaje(context, error, tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: _isLoading
          ? null
          : PieBoton(
              texto: 'Guardar configuración',
              icono: Icons.check_rounded,
              cargando: _isSaving,
              onPressed: _guardar,
            ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppEspaciado.md),
                  children: [
                    const CabeceraApp(
                      titulo: 'Pago por Yape',
                      subtitulo: 'Cobra pedidos y membresías desde la app',
                    ),
                    const SizedBox(height: AppEspaciado.md + 4),
                    _tarjetaInfo(),
                    const SizedBox(height: AppEspaciado.lg),
                    const TituloSeccion(
                      icono: Icons.qr_code_2_rounded,
                      titulo: 'Tu QR de Yape',
                    ),
                    TarjetaPlana(
                      child: Column(
                        children: [
                          _qrPreview(),
                          const SizedBox(height: AppEspaciado.md),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: _elegirQr,
                              icon: const Icon(Icons.image_outlined),
                              label: Text(
                                _tieneQr
                                    ? 'Cambiar imagen del QR'
                                    : 'Subir imagen del QR',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppEspaciado.lg),
                    const TituloSeccion(
                      icono: Icons.account_balance_wallet_rounded,
                      titulo: 'Cuenta',
                    ),
                    TarjetaPlana(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _etiqueta('Número de Yape'),
                          TextFormField(
                            controller: _numeroController,
                            keyboardType: TextInputType.phone,
                            maxLength: 9,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Ej. 987654321',
                              prefixIcon: Icon(Icons.phone_iphone),
                              counterText: '',
                            ),
                            validator: (v) {
                              final t = v?.trim() ?? '';
                              if (t.isEmpty) return 'Ingresa el número de Yape';
                              if (t.length != 9) {
                                return 'El número debe tener 9 dígitos';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: AppEspaciado.md),
                          _etiqueta('Titular de la cuenta'),
                          TextFormField(
                            controller: _titularController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Ej. Gimnasio XNOX',
                              prefixIcon: Icon(Icons.person_outline),
                            ),
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

  bool get _tieneQr => _qrNuevo != null || (_datos?.yapeQrUrl != null);

  Widget _tarjetaInfo() {
    return const PortadaFoto(
      foto: FotosApp.tienda,
      alineacion: Alignment(0.4, 0.2),
      altura: 140,
      etiqueta: 'Yape en la app',
      titulo: 'Cobra al instante',
      texto:
          'Tus socios verán este QR y número para pagarte sus pedidos '
          'y su membresía.',
    );
  }

  Widget _qrPreview() {
    final qrNuevo = _qrNuevo;
    final qrUrl = _datos?.yapeQrUrl;
    Widget contenido;
    if (qrNuevo != null) {
      contenido = Image.file(qrNuevo, fit: BoxFit.contain);
    } else if (qrUrl != null) {
      contenido = Image.network(
        qrUrl,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => _qrPlaceholder(),
      );
    } else {
      contenido = _qrPlaceholder();
    }

    return Center(
      child: Container(
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(AppEspaciado.radio),
          border: Border.all(color: AppColores.borde),
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.all(AppEspaciado.sm),
        child: contenido,
      ),
    );
  }

  Widget _qrPlaceholder() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.qr_code_2_outlined, size: 56, color: AppColores.vencido),
          SizedBox(height: 8),
          Text(
            'Sin QR de Yape',
            style: TextStyle(color: AppColores.textoSecundario, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColores.textoPrincipal,
        ),
      ),
    );
  }
}
