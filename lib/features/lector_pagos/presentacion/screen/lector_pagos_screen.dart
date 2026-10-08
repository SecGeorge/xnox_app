import 'package:flutter/material.dart';
import 'package:xnox_app/core/servicios/lector_pagos_channel.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';

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
      bottomNavigationBar: _cargando
          ? null
          : PieBoton(
              texto: _activo
                  ? 'Abrir ajustes del sistema'
                  : 'Activar lector de pagos',
              icono: _activo ? Icons.settings_rounded : Icons.shield_rounded,
              onPressed: _activar,
            ),
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppEspaciado.md),
                children: [
                  const CabeceraApp(
                    titulo: 'Lector de pagos',
                    subtitulo: 'Registra Yape y Plin automáticamente',
                  ),
                  const SizedBox(height: AppEspaciado.md + 4),
                  PortadaFoto(
                    foto: FotosApp.tienda,
                    alineacion: const Alignment(0.4, 0.2),
                    altura: 140,
                    etiqueta: 'Estado del lector',
                    titulo: _activo ? 'Activo' : 'Inactivo',
                    texto: _activo
                        ? 'Los pagos de Yape/Plin se registran solos.'
                        : 'Concede "Acceso a notificaciones" para empezar.',
                  ),
                  const SizedBox(height: AppEspaciado.md),
                  _tarjetaEstado(),
                  const SizedBox(height: AppEspaciado.lg),
                  const TituloSeccion(
                    icono: Icons.help_outline_rounded,
                    titulo: '¿Cómo funciona?',
                  ),
                  _tarjetaInfo(),
                ],
              ),
      ),
    );
  }

  Widget _tarjetaEstado() {
    final color = _activo ? AppColores.activo : AppColores.advertencia;
    return TarjetaPlana(
      color: color.withValues(alpha: 0.06),
      colorBorde: color.withValues(alpha: 0.35),
      child: Row(
        children: [
          IconoSuave(
            _activo ? Icons.check_circle_rounded : Icons.error_outline_rounded,
            color: color,
            circular: true,
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _activo ? 'Lector activo' : 'Lector inactivo',
                  style: TextStyle(
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
    return TarjetaPlana(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Paso(
            numero: '1',
            texto:
                'Pulsa "Activar lector" y concede el acceso a XNOX en la '
                'lista de aplicaciones.',
          ),
          _Paso(
            numero: '2',
            texto:
                'Cuando un cliente pague por Yape o Plin, la notificación '
                'se enviará al sistema automáticamente.',
          ),
          _Paso(
            numero: '3',
            texto:
                'No necesitas tener la app abierta: el lector trabaja en '
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
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: AppColores.degradadoRelleno,
              shape: BoxShape.circle,
            ),
            child: Text(
              numero,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColores.sobreRelleno,
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
