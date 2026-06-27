import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/notificaciones/dominio/entidades/notificacion.dart';
import 'package:xnox_app/features/notificaciones/presentacion/controlador/controlador_notificaciones.dart';

/// Pantalla que lista las notificaciones de la sucursal (membresías vencidas,
/// por vencer, deudas, productos por vencer). Permite marcarlas como leídas.
///
/// Al cerrarse devuelve `true` si cambió algo (se marcó alguna como leída),
/// para que el dashboard refresque el contador de la campanita.
class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});

  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  final _controlador = ControladorNotificaciones();
  List<Notificacion> _notificaciones = [];
  bool _isLoading = true;
  bool _huboCambios = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final lista = await _controlador.obtener();
      if (!mounted) return;
      setState(() {
        _notificaciones = lista;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarMensaje(context, 'No se pudieron cargar las notificaciones',
          tipo: TipoMensaje.error);
    }
  }

  Future<void> _marcarLeido(Notificacion n) async {
    // Optimista: la quitamos de la lista de inmediato.
    setState(() {
      _notificaciones.removeWhere((x) => x.id == n.id);
      _huboCambios = true;
    });
    try {
      await _controlador.marcarLeido(n.id);
    } catch (_) {
      if (!mounted) return;
      mostrarMensaje(context, 'No se pudo marcar como leída',
          tipo: TipoMensaje.error);
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text('Notificaciones'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(_huboCambios),
        ),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargar,
          child: _buildContenido(),
        ),
      ),
    );
  }

  Widget _buildContenido() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_notificaciones.isEmpty) {
      // ListView para que el RefreshIndicator funcione aun estando vacío.
      return ListView(
        children: const [
          SizedBox(height: 120),
          EstadoVacio(
            icono: Icons.notifications_off_outlined,
            mensaje: 'No tienes notificaciones pendientes',
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(AppEspaciado.md),
      itemCount: _notificaciones.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppEspaciado.sm + 4),
      itemBuilder: (_, i) => _buildTarjeta(_notificaciones[i]),
    );
  }

  Widget _buildTarjeta(Notificacion n) {
    return Dismissible(
      key: ValueKey(n.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => _marcarLeido(n),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppEspaciado.lg),
        decoration: BoxDecoration(
          color: AppColores.activo.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(AppEspaciado.radio),
        ),
        child: const Icon(Icons.done_all, color: AppColores.activo),
      ),
      child: TarjetaApp(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: n.tipo.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
              ),
              child: Icon(n.tipo.icono, color: n.tipo.color, size: 22),
            ),
            const SizedBox(width: AppEspaciado.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    n.mensaje,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  if (n.fecha != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      _formatoFecha(n.fecha!),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColores.textoSecundario,
              tooltip: 'Marcar como leída',
              onPressed: () => _marcarLeido(n),
            ),
          ],
        ),
      ),
    );
  }

  String _formatoFecha(DateTime fecha) {
    final ahora = DateTime.now();
    final dif = ahora.difference(fecha);
    if (dif.inMinutes < 1) return 'Hace un momento';
    if (dif.inHours < 1) return 'Hace ${dif.inMinutes} min';
    if (dif.inDays < 1) return 'Hace ${dif.inHours} h';
    if (dif.inDays < 7) return 'Hace ${dif.inDays} d';
    return DateFormat('dd/MM/yyyy').format(fecha);
  }
}
