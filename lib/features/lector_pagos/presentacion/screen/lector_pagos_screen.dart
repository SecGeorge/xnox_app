import 'package:flutter/material.dart';
import 'package:xnox_app/core/servicios/lector_pagos_channel.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';

/// Pantalla para activar/verificar el lector de pagos Yape/Plin.
///
/// El trabajo real lo hace el servicio nativo `YapeListenerService` en segundo
/// plano; aquí solo gestionamos el permiso de "Acceso a notificaciones" y
/// mostramos su estado.
class LectorPagosScreen extends StatefulWidget {
  const LectorPagosScreen({super.key});

  @override
  State<LectorPagosScreen> createState() => _LectorPagosScreenState();
}

class _LectorPagosScreenState extends State<LectorPagosScreen>
    with WidgetsBindingObserver {
  bool _activo = false;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Deja el endpoint listo para el servicio nativo y verifica el estado.
    LectorPagosChannel.sincronizarConfig();
    _verificar();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver de los ajustes del sistema, re-verificamos el permiso.
    if (state == AppLifecycleState.resumed) _verificar();
  }

  Future<void> _verificar() async {
    final activo = await LectorPagosChannel.estaActivo();
    if (!mounted) return;
    setState(() {
      _activo = activo;
      _cargando = false;
    });
  }

  Future<void> _activar() async {
    await LectorPagosChannel.abrirAjustes();
    // El estado se refresca solo en didChangeAppLifecycleState al regresar.
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Lector de pagos')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(AppEspaciado.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _tarjetaEstado(),
                    const SizedBox(height: AppEspaciado.md),
                    _tarjetaInfo(),
                    const SizedBox(height: AppEspaciado.lg),
                    ElevatedButton.icon(
                      onPressed: _activar,
                      icon: Icon(_activo ? Icons.settings : Icons.shield_outlined),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            _activo ? AppColores.primario : AppColores.activo,
                      ),
                      label: Text(
                        _activo
                            ? 'ABRIR AJUSTES DEL SISTEMA'
                            : 'ACTIVAR LECTOR DE PAGOS',
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _tarjetaEstado() {
    final color = _activo ? AppColores.activo : AppColores.advertencia;
    return TarjetaApp(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Icon(
              _activo ? Icons.check_circle : Icons.error_outline,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activo ? 'Lector activo' : 'Lector inactivo',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _activo
                      ? 'Los pagos de Yape/Plin se registran automáticamente.'
                      : 'Concede "Acceso a notificaciones" para empezar.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaInfo() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text(
            '¿Cómo funciona?',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColores.textoPrincipal,
            ),
          ),
          SizedBox(height: AppEspaciado.sm),
          _Paso(
            numero: '1',
            texto: 'Pulsa "Activar lector" y concede el acceso a XNOX en la '
                'lista de aplicaciones.',
          ),
          _Paso(
            numero: '2',
            texto: 'Cuando un cliente pague por Yape o Plin, la notificación '
                'se enviará al sistema automáticamente.',
          ),
          _Paso(
            numero: '3',
            texto: 'No necesitas tener la app abierta: el lector trabaja en '
                'segundo plano.',
          ),
        ],
      ),
    );
  }
}

class _Paso extends StatelessWidget {
  final String numero;
  final String texto;

  const _Paso({required this.numero, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColores.acento.withValues(alpha: 0.15),
            child: Text(
              numero,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColores.acento,
              ),
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              texto,
              style: const TextStyle(
                fontSize: 13,
                color: AppColores.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
