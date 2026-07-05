import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Tarjeta base estandarizada usada en todas las pantallas.
class TarjetaApp extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  const TarjetaApp({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppEspaciado.md),
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColores.superficie,
      borderRadius: BorderRadius.circular(AppEspaciado.radio),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            color: AppColores.superficie,
            borderRadius: BorderRadius.circular(AppEspaciado.radio),
            border: Border.all(color: AppColores.borde),
            boxShadow: AppSombras.tarjeta,
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Encabezado de sección con título y acción opcional.
class EncabezadoSeccion extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final Widget? accion;

  const EncabezadoSeccion({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitulo!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ],
          ),
        ),
        ?accion,
      ],
    );
  }
}

/// Etiqueta de estado con color semántico (activo, deudor, moroso, vencido).
class EtiquetaEstado extends StatelessWidget {
  final String texto;
  final Color color;

  const EtiquetaEstado({super.key, required this.texto, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Tipos de mensaje para las notificaciones (SnackBar) de la app.
/// Colores: verde = éxito, rojo = error/validación, amarillo = alerta.
enum TipoMensaje { exito, error, advertencia, info }

extension TipoMensajeEstilo on TipoMensaje {
  Color get color {
    switch (this) {
      case TipoMensaje.exito:
        return AppColores.exito;
      case TipoMensaje.error:
        return AppColores.error;
      case TipoMensaje.advertencia:
        return AppColores.advertencia;
      case TipoMensaje.info:
        return AppColores.primario;
    }
  }

  IconData get icono {
    switch (this) {
      case TipoMensaje.exito:
        return Icons.check_circle_outline;
      case TipoMensaje.error:
        return Icons.error_outline;
      case TipoMensaje.advertencia:
        return Icons.warning_amber_rounded;
      case TipoMensaje.info:
        return Icons.info_outline;
    }
  }
}

/// Key global del ScaffoldMessenger. Se asigna en el [MaterialApp]. Se conserva
/// como respaldo por si el overlay del navigator aún no está disponible.
final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// Key global del Navigator. Se asigna en el [MaterialApp] y permite insertar
/// el toast en el overlay raíz, por encima de hojas modales y diálogos.
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

/// Construye el SnackBar estandarizado (solo se usa como respaldo).
SnackBar _construirSnackBar(String texto, TipoMensaje tipo) {
  return SnackBar(
    backgroundColor: tipo.color,
    behavior: SnackBarBehavior.floating,
    content: Row(
      children: [
        Icon(tipo.icono, color: Colors.white, size: 20),
        const SizedBox(width: AppEspaciado.sm),
        Expanded(
          child: Text(
            texto,
            style: const TextStyle(color: Colors.white),
          ),
        ),
      ],
    ),
  );
}

/// Muestra un mensaje flotante (toast) con color semántico según el [tipo].
/// Mantiene la firma con [context] por compatibilidad, pero el aviso se dibuja
/// en el overlay raíz para que sea visible también sobre hojas y diálogos.
void mostrarMensaje(
  BuildContext context,
  String texto, {
  TipoMensaje tipo = TipoMensaje.info,
}) {
  _mostrarToast(texto, tipo);
}

/// Igual que [mostrarMensaje] pero sin necesitar un [BuildContext]; útil para
/// avisos como la falta de conexión desde la capa de red.
void mostrarMensajeGlobal(
  String texto, {
  TipoMensaje tipo = TipoMensaje.info,
}) {
  _mostrarToast(texto, tipo);
}

// --- Toast flotante -------------------------------------------------------
//
// Mostramos un único aviso a la vez en el overlay raíz. Los toques repetidos
// reemplazan al anterior al instante (no se encolan) y el aviso queda por
// encima de hojas modales y diálogos.

OverlayEntry? _toastEntrada;
Timer? _toastTimer;

void _mostrarToast(String texto, TipoMensaje tipo) {
  final overlay = navigatorKey.currentState?.overlay;
  if (overlay == null) {
    // Respaldo: si aún no hay overlay, usamos el messenger global.
    scaffoldMessengerKey.currentState
      ?..clearSnackBars()
      ..showSnackBar(_construirSnackBar(texto, tipo));
    return;
  }

  // Reemplazamos cualquier aviso previo de inmediato.
  _toastTimer?.cancel();
  _toastEntrada?.remove();

  final key = GlobalKey<_ToastState>();
  final entrada = OverlayEntry(
    builder: (_) => _Toast(key: key, texto: texto, tipo: tipo),
  );
  _toastEntrada = entrada;
  overlay.insert(entrada);

  _toastTimer = Timer(const Duration(milliseconds: 2600), () async {
    await key.currentState?.cerrar();
    // Solo lo quitamos si sigue siendo el aviso vigente (no fue reemplazado).
    if (_toastEntrada == entrada) {
      entrada.remove();
      _toastEntrada = null;
    }
  });
}

/// Distancia desde el borde inferior para que el aviso quede por encima del
/// botón del carrito y la barra de navegación.
const double _kToastMargenInferior = 120;

class _Toast extends StatefulWidget {
  final String texto;
  final TipoMensaje tipo;

  const _Toast({super.key, required this.texto, required this.tipo});

  @override
  State<_Toast> createState() => _ToastState();
}

class _ToastState extends State<_Toast> with SingleTickerProviderStateMixin {
  late final AnimationController _controlador = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );
  late final Animation<double> _fade =
      CurvedAnimation(parent: _controlador, curve: Curves.easeOut);
  late final Animation<Offset> _slide = Tween<Offset>(
    begin: const Offset(0, 0.4),
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _controlador, curve: Curves.easeOut));

  @override
  void initState() {
    super.initState();
    _controlador.forward();
  }

  /// Anima la salida del aviso; el llamador se encarga de quitar la entrada.
  Future<void> cerrar() async {
    if (!mounted) return;
    try {
      await _controlador.reverse();
    } catch (_) {/* controlador liberado */}
  }

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return Positioned(
      left: AppEspaciado.md,
      right: AppEspaciado.md,
      bottom:
          media.viewInsets.bottom + media.padding.bottom + _kToastMargenInferior,
      child: IgnorePointer(
        child: FadeTransition(
          opacity: _fade,
          child: SlideTransition(
            position: _slide,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Material(
                color: Colors.transparent,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppEspaciado.md, vertical: AppEspaciado.sm + 4),
                  decoration: BoxDecoration(
                    color: widget.tipo.color,
                    borderRadius: BorderRadius.circular(AppEspaciado.radio),
                    boxShadow: AppSombras.tarjeta,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(widget.tipo.icono, color: Colors.white, size: 20),
                      const SizedBox(width: AppEspaciado.sm),
                      Flexible(
                        child: Text(
                          widget.texto,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado vacío reutilizable.
class EstadoVacio extends StatelessWidget {
  final IconData icono;
  final String mensaje;

  const EstadoVacio({super.key, required this.icono, required this.mensaje});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 56, color: AppColores.vencido),
          const SizedBox(height: AppEspaciado.md),
          Text(
            mensaje,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColores.textoSecundario,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// Diálogo de confirmación estándar de la app: compacto, moderno, con un ícono
/// en círculo de color. Todos los modales de confirmación deben usar esto.
///
/// Devuelve `true` si el usuario confirma. Con [peligro] = true usa el color de
/// error (rojo) para acciones destructivas como eliminar.
Future<bool> confirmarDialog(
  BuildContext context, {
  required String titulo,
  required String mensaje,
  IconData icono = Icons.help_outline,
  String textoConfirmar = 'Confirmar',
  String textoCancelar = 'Cancelar',
  bool peligro = false,
}) async {
  final color = peligro ? AppColores.error : AppColores.primario;
  final resultado = await showDialog<bool>(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: AppColores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppEspaciado.lg, AppEspaciado.lg,
            AppEspaciado.lg, AppEspaciado.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: color, size: 26),
            ),
            const SizedBox(height: AppEspaciado.md),
            Text(
              titulo,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: AppColores.textoPrincipal,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColores.textoSecundario,
              ),
            ),
            const SizedBox(height: AppEspaciado.lg),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColores.textoSecundario,
                      side: const BorderSide(color: AppColores.borde),
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(textoCancelar),
                  ),
                ),
                const SizedBox(width: AppEspaciado.sm + 4),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(textoConfirmar),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
  return resultado == true;
}
