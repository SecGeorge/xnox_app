import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/notificaciones/dominio/entidades/notificacion.dart';
import 'package:xnox_app/features/notificaciones/presentacion/controlador/controlador_notificaciones.dart';
import 'package:xnox_app/features/notificaciones/presentacion/screen/crear_notificacion_screen.dart';

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

  /// Si el rol tiene el permiso `mobile_notif_enviar` (o es Administrador) se
  /// ofrece el botón de enviar avisos. Los clientes nunca lo tienen.
  bool _puedeEnviarAvisos = false;

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarPermisos();
  }

  Future<void> _cargarPermisos() async {
    final permisos = await Permisos.cargar();
    if (!mounted) return;
    setState(
      () => _puedeEnviarAvisos = permisos.tiene(PermisosMovil.notifEnviar),
    );
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
      mostrarMensaje(
        context,
        'No se pudieron cargar las notificaciones',
        tipo: TipoMensaje.error,
      );
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
      mostrarMensaje(
        context,
        'No se pudo marcar como leída',
        tipo: TipoMensaje.error,
      );
      _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Al volver (botón o gesto) avisa si se marcó algo como leído.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) Navigator.of(context).pop(_huboCambios);
      },
      child: PantallaApp(
        onRefresh: _cargar,
        espacioAbajo: 110,
        // Solo quien tiene el permiso de enviar avisos ve el botón. Los
        // clientes nunca lo tienen: para ellos la pantalla es de solo lectura.
        botonFlotante: _puedeEnviarAvisos
            ? FloatingActionButton.extended(
                onPressed: _abrirCrear,
                icon: const Icon(Icons.campaign_rounded),
                label: const Text('Enviar aviso'),
              )
            : null,
        children: [
          const CabeceraApp(
            titulo: 'Avisos',
            subtitulo: 'Desliza un aviso para marcarlo como leído',
          ),
          const SizedBox(height: AppEspaciado.md + 4),
          PortadaFoto(
            foto: FotosApp.motivacion,
            alineacion: const Alignment(0.5, -0.3),
            altura: 130,
            etiqueta: 'Bandeja',
            titulo: _isLoading
                ? '…'
                : _notificaciones.isEmpty
                ? 'Todo al día'
                : _notificaciones.length == 1
                ? '1 aviso pendiente'
                : '${_notificaciones.length} avisos pendientes',
          ),
          const SizedBox(height: AppEspaciado.lg),
          ..._buildContenido(),
        ],
      ),
    );
  }

  /// Abre el formulario de envío y recarga la lista si se envió algo.
  Future<void> _abrirCrear() async {
    final enviado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const CrearNotificacionScreen()),
    );
    if (enviado == true) {
      _huboCambios = true;
      await _cargar();
    }
  }

  List<Widget> _buildContenido() {
    if (_isLoading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_notificaciones.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.notifications_off_rounded,
          titulo: 'No tienes avisos pendientes',
          texto: 'Aquí aparecerán los mensajes del gimnasio.',
        ),
      ];
    }
    return [
      for (final n in _notificaciones) ...[
        _buildTarjeta(n),
        const SizedBox(height: AppEspaciado.sm + 4),
      ],
    ];
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
          borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
        ),
        child: const Icon(Icons.done_all_rounded, color: AppColores.activo),
      ),
      child: TarjetaPlana(
        padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconoSuave(n.tipo.icono, color: n.tipo.color, circular: true),
            const SizedBox(width: AppEspaciado.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo,
                    style: TextStyle(
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
