import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/cliente_destinatario.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/plantilla_mensaje.dart';
import 'package:xnox_app/features/marketing/presentacion/controlador/controlador_mensajeria.dart';

/// Cola de envío: abre el chat de WhatsApp de cada cliente, uno por uno.
class ColaEnvioScreen extends StatefulWidget {
  final List<ClienteDestinatario> clientes;
  final String mensajeBase;
  final PlantillaMensaje? plantilla;
  final String filtroEtiqueta;

  const ColaEnvioScreen({
    super.key,
    required this.clientes,
    required this.mensajeBase,
    required this.plantilla,
    required this.filtroEtiqueta,
  });

  @override
  State<ColaEnvioScreen> createState() => _ColaEnvioScreenState();
}

class _ColaEnvioScreenState extends State<ColaEnvioScreen> {
  final _controlador = ControladorMensajeria();
  int _indice = 0;
  bool _finalizado = false;

  @override
  void initState() {
    super.initState();
    // Abre automáticamente el primer chat al entrar.
    WidgetsBinding.instance.addPostFrameCallback((_) => _abrirWhatsApp());
  }

  ClienteDestinatario get _actual => widget.clientes[_indice];
  String get _mensajeActual => _actual.generarMensaje(widget.mensajeBase);

  Future<void> _abrirWhatsApp() async {
    final url = Uri.parse(
        'https://wa.me/${_actual.telefonoWhatsApp}?text=${Uri.encodeComponent(_mensajeActual)}');
    try {
      final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        mostrarMensaje(context, 'No se pudo abrir WhatsApp',
            tipo: TipoMensaje.error);
      }
    } catch (_) {
      if (mounted) {
        mostrarMensaje(context, 'No se pudo abrir WhatsApp',
            tipo: TipoMensaje.error);
      }
    }
  }

  void _siguiente() {
    if (_indice + 1 >= widget.clientes.length) {
      setState(() => _indice = widget.clientes.length);
      _finalizar('Completado');
      return;
    }
    setState(() => _indice++);
    _abrirWhatsApp();
  }

  Future<void> _cancelar() async {
    final ok = await confirmarDialog(
      context,
      titulo: '¿Cancelar envío?',
      mensaje:
          'Se han procesado $_indice de ${widget.clientes.length} clientes.',
      icono: Icons.close,
      textoConfirmar: 'Sí, cancelar',
      textoCancelar: 'Continuar',
      peligro: true,
    );
    if (ok) _finalizar('Cancelado');
  }

  Future<void> _finalizar(String estado) async {
    setState(() => _finalizado = true);
    await _controlador.registrarCampania(
      plantillaId: widget.plantilla?.id,
      plantillaNombre: widget.plantilla?.nombre ?? 'Mensaje personalizado',
      filtro: widget.filtroEtiqueta,
      totalClientes:
          estado == 'Cancelado' ? _indice : widget.clientes.length,
      estado: estado,
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.clientes.length;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Enviando mensajes'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: _finalizado ? _vistaFinal(total) : _vistaEnvio(total),
      ),
    );
  }

  Widget _vistaEnvio(int total) {
    final progreso = (_indice + 1) / total;
    return Padding(
      padding: const EdgeInsets.all(AppEspaciado.lg),
      child: Column(
        children: [
          // Progreso
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              value: progreso,
              minHeight: 22,
              backgroundColor: AppColores.borde,
              valueColor: const AlwaysStoppedAnimation(AppColores.primario),
            ),
          ),
          const SizedBox(height: 6),
          Text('${_indice + 1} de $total',
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColores.primario)),
          const SizedBox(height: AppEspaciado.lg),

          // Tarjeta del cliente
          TarjetaApp(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppEspaciado.md),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColores.primario, AppColores.primarioClaro],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(AppEspaciado.radio),
                      topRight: Radius.circular(AppEspaciado.radio),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.white,
                        child: Text(_actual.iniciales,
                            style: const TextStyle(
                                color: AppColores.primario,
                                fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: AppEspaciado.sm + 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_actual.nombre,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                const Icon(Icons.phone,
                                    color: Colors.white70, size: 14),
                                const SizedBox(width: 4),
                                Text(_actual.telefono,
                                    style: const TextStyle(
                                        color: Colors.white70, fontSize: 13)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(AppEspaciado.md),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('MENSAJE',
                          style: TextStyle(
                              fontSize: 11,
                              letterSpacing: 0.5,
                              fontWeight: FontWeight.w700,
                              color: AppColores.textoSecundario)),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(AppEspaciado.sm + 4),
                        decoration: BoxDecoration(
                          color: AppColores.fondo,
                          borderRadius:
                              BorderRadius.circular(AppEspaciado.radioSm),
                          border: Border.all(color: AppColores.borde),
                        ),
                        child: Text(_mensajeActual,
                            style: const TextStyle(fontSize: 14, height: 1.35)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          const Text(
            'Abre WhatsApp → envía → vuelve aquí → Siguiente.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
          ),
          const Spacer(),

          // Botones
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _abrirWhatsApp,
              icon: const Icon(Icons.chat),
              label: const Text('Abrir WhatsApp'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF25D366),
                  foregroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _cancelar,
                  icon: const Icon(Icons.close),
                  label: const Text('Cancelar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColores.error,
                    side: const BorderSide(color: AppColores.error),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
              const SizedBox(width: AppEspaciado.sm + 4),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _siguiente,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(_indice + 1 >= total ? 'Finalizar' : 'Siguiente'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _vistaFinal(int total) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppEspaciado.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: AppColores.exito, size: 84),
            const SizedBox(height: AppEspaciado.md),
            const Text('¡Envío finalizado!',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textoPrincipal)),
            const SizedBox(height: 6),
            Text('Se procesaron $_indice de $total clientes.',
                style: const TextStyle(color: AppColores.textoSecundario)),
            const SizedBox(height: AppEspaciado.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
