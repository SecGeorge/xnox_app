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

  /// Texto exacto del estado (ACTIVO, DEUDOR, MOROSO, VENCIDO, SIN MEMBRESÍA),
  /// replicando la lógica del panel web.
  final String etiquetaEstado;
  final DateTime? fechaVencimiento;
  final double saldoPendiente;

  Miembro({
    this.id,
    required this.nombre,
    required this.documento,
    required this.plan,
    required this.estado,
    String? etiquetaEstado,
    this.fechaVencimiento,
    this.saldoPendiente = 0,
  }) : etiquetaEstado = etiquetaEstado ?? estado.etiqueta;

  /// Iniciales para el avatar.
  String get iniciales {
    final partes = nombre.trim().split(RegExp(r'\s+'));
    if (partes.isEmpty) return '?';
    if (partes.length == 1) return partes.first.characters.first.toUpperCase();
    return (partes.first.characters.first + partes.last.characters.first)
        .toUpperCase();
  }

  /// Construye un miembro a partir de una fila del endpoint `buscar`.
  /// Deriva el estado igual que el panel web (estado_membresia + deuda).
  factory Miembro.fromJson(Map<String, dynamic> json) {
    final nombreCompleto = [
      json['nombre'],
      json['apellidoPaterno'],
      json['apellidoMaterno'],
    ]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString().trim())
        .join(' ')
        .trim();

    final estadoNum =
        int.tryParse(json['estado_membresia']?.toString() ?? '0') ?? 0;
    final debe = double.tryParse(json['debe']?.toString() ?? '0') ?? 0;
    final fechaFin = DateTime.tryParse(json['fecha_fin']?.toString() ?? '');
    final fechaLimiteNueva =
        DateTime.tryParse(json['fecha_limite_nueva']?.toString() ?? '');
    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);

    EstadoMiembro estado;
    String etiqueta;
    final esMorosoPorFecha = debe > 0 &&
        fechaLimiteNueva != null &&
        fechaLimiteNueva.isBefore(hoy);

    if (estadoNum == 0) {
      estado = EstadoMiembro.vencido;
      etiqueta = 'SIN MEMBRESÍA';
    } else if ((estadoNum == 7 && debe > 0) || esMorosoPorFecha) {
      estado = EstadoMiembro.moroso;
      etiqueta = 'MOROSO';
    } else if (estadoNum == 5) {
      estado = EstadoMiembro.activo;
      etiqueta = 'ACTIVO';
    } else if (estadoNum == 6) {
      estado = EstadoMiembro.deudor;
      etiqueta = 'DEUDOR';
    } else if (estadoNum == 7) {
      estado = EstadoMiembro.vencido;
      etiqueta = 'VENCIDO';
    } else {
      estado = EstadoMiembro.vencido;
      etiqueta = 'DESCONOCIDO';
    }

    final membresia = json['membresia']?.toString().trim() ?? '';

    return Miembro(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nombre: nombreCompleto.isEmpty ? 'Sin nombre' : nombreCompleto,
      documento: json['codigo']?.toString() ?? '',
      plan: (membresia.isEmpty || membresia == 'SIN CONTRATO')
          ? 'Sin membresía'
          : membresia,
      estado: estado,
      etiquetaEstado: etiqueta,
      fechaVencimiento: fechaFin,
      saldoPendiente: debe,
    );
  }
}
