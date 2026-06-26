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

/// Muestra un SnackBar estandarizado con color semántico según el [tipo].
void mostrarMensaje(
  BuildContext context,
  String texto, {
  TipoMensaje tipo = TipoMensaje.info,
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
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
      ),
    );
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
