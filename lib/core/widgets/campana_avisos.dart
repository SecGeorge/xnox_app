import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/notificaciones/presentacion/controlador/controlador_notificaciones.dart';
import 'package:xnox_app/features/notificaciones/presentacion/screen/notificaciones_screen.dart';

/// Campana de avisos reutilizable con contador de pendientes. Es autónoma:
/// carga su propio conteo y navega a la lista de notificaciones, refrescando el
/// contador al volver. Se coloca en el AppBar/encabezado de cada sección para
/// que el acceso a avisos esté siempre visible (no solo en Inicio).
class CampanaAvisos extends StatefulWidget {
  /// Color del ícono. En un AppBar (fondo oscuro) se deja `null` para heredar
  /// el blanco; en encabezados claros (Inicio, Ajustes) se pasa el color primario.
  final Color? color;
  const CampanaAvisos({super.key, this.color});

  @override
  State<CampanaAvisos> createState() => _CampanaAvisosState();
}

class _CampanaAvisosState extends State<CampanaAvisos> {
  final _controlador = ControladorNotificaciones();
  int _pendientes = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final lista = await _controlador.obtener();
      if (!mounted) return;
      setState(() => _pendientes = lista.length);
    } catch (_) {
      // El badge es secundario: si falla, no interrumpimos la pantalla.
    }
  }

  Future<void> _abrir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const NotificacionesScreen()),
    );
    if (!mounted) return;
    _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _abrir,
      tooltip: 'Avisos',
      color: widget.color,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(_pendientes > 0
              ? Icons.notifications
              : Icons.notifications_none),
          if (_pendientes > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: AppColores.moroso,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _pendientes > 9 ? '9+' : '$_pendientes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
