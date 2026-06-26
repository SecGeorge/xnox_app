import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Estados posibles de un miembro del club/gimnasio.
enum EstadoMiembro {
  activo,
  deudor,
  moroso,
  vencido;

  String get etiqueta {
    switch (this) {
      case EstadoMiembro.activo:
        return 'Activo';
      case EstadoMiembro.deudor:
        return 'Deudor';
      case EstadoMiembro.moroso:
        return 'Moroso';
      case EstadoMiembro.vencido:
        return 'Vencido';
    }
  }

  Color get color {
    switch (this) {
      case EstadoMiembro.activo:
        return AppColores.activo;
      case EstadoMiembro.deudor:
        return AppColores.deudor;
      case EstadoMiembro.moroso:
        return AppColores.moroso;
      case EstadoMiembro.vencido:
        return AppColores.vencido;
    }
  }

  static EstadoMiembro desdeTexto(String? valor) {
    switch (valor?.toLowerCase()) {
      case 'activo':
        return EstadoMiembro.activo;
      case 'deudor':
        return EstadoMiembro.deudor;
      case 'moroso':
        return EstadoMiembro.moroso;
      case 'vencido':
        return EstadoMiembro.vencido;
      default:
        return EstadoMiembro.activo;
    }
  }
}

class Miembro {
  final int? id;
  final String nombre;
  final String documento;
  final String plan;
  final EstadoMiembro estado;
  final DateTime fechaVencimiento;
  final double saldoPendiente;

  Miembro({
    this.id,
    required this.nombre,
    required this.documento,
    required this.plan,
    required this.estado,
    required this.fechaVencimiento,
    this.saldoPendiente = 0,
  });

  /// Iniciales para el avatar.
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first + partes.last.characters.first)
        .toUpperCase();
  }

  factory Miembro.fromJson(Map<String, dynamic> json) {
    return Miembro(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      nombre: json['nombre'] ?? '',
      documento: json['documento']?.toString() ?? '',
      plan: json['plan'] ?? 'General',
      estado: EstadoMiembro.desdeTexto(json['estado']),
      fechaVencimiento: DateTime.tryParse(json['fecha_vencimiento'] ?? '') ??
          DateTime.now(),
      saldoPendiente:
          double.tryParse(json['saldo_pendiente']?.toString() ?? '0') ?? 0,
    );
  }
}
