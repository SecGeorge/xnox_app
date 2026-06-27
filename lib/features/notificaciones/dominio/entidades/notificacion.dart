import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Tipo de notificación según su severidad. Coincide con el campo `tipo`
/// que devuelve el backend (`notificaciones.php`).
enum TipoNotificacion { alerta, prevencion, info }

extension TipoNotificacionEstilo on TipoNotificacion {
  /// Color representativo del tipo (rojo = alerta, naranja = prevención).
  Color get color {
    switch (this) {
      case TipoNotificacion.alerta:
        return AppColores.moroso;
      case TipoNotificacion.prevencion:
        return AppColores.naranja;
      case TipoNotificacion.info:
        return AppColores.azul;
    }
  }

  IconData get icono {
    switch (this) {
      case TipoNotificacion.alerta:
        return Icons.error_outline;
      case TipoNotificacion.prevencion:
        return Icons.warning_amber_rounded;
      case TipoNotificacion.info:
        return Icons.notifications_active_outlined;
    }
  }
}

/// Una notificación del sistema (membresía vencida, por vencer, deuda,
/// producto por vencer, etc.).
class Notificacion {
  final int id;
  final String titulo;
  final String mensaje;
  final TipoNotificacion tipo;
  final DateTime? fecha;
  final bool leido;
  final int? idMiembro;

  Notificacion({
    required this.id,
    required this.titulo,
    required this.mensaje,
    required this.tipo,
    required this.fecha,
    required this.leido,
    required this.idMiembro,
  });

  factory Notificacion.fromJson(Map<String, dynamic> json) {
    int aInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

    TipoNotificacion parseTipo(dynamic v) {
      switch (v?.toString().toLowerCase()) {
        case 'alerta':
          return TipoNotificacion.alerta;
        case 'prevencion':
          return TipoNotificacion.prevencion;
        default:
          return TipoNotificacion.info;
      }
    }

    return Notificacion(
      id: aInt(json['id']),
      titulo: json['titulo']?.toString() ?? 'Notificación',
      mensaje: json['mensaje']?.toString() ?? '',
      tipo: parseTipo(json['tipo']),
      fecha: DateTime.tryParse(json['fecha']?.toString() ?? ''),
      leido: aInt(json['leido']) == 1,
      idMiembro: int.tryParse(json['idMiembro']?.toString() ?? ''),
    );
  }
}
