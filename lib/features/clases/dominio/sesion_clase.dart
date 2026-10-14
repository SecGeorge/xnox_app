import 'package:flutter/material.dart';

/// Una clase en un día y hora concretos (zumba del jueves 15 a las 07:00),
/// tal como la arma `clases.php → agenda_socio` para el socio que pregunta.
class SesionClase {
  final int claseId;
  final int horarioId;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;
  final String nombre;
  final String descripcion;
  final Color color;
  final String entrenador;
  final String salon;
  final int aforo;
  final int ocupados;
  final int libres;

  /// 1 incluida en cualquier membresía, 2 solo en algunos planes, 3 de pago.
  final int acceso;

  /// Lo que paga quien no la tiene incluida (null = no puede reservar).
  final double? precio;
  final String membresiasNombres;
  final bool pasada;

  /// Si la tiene incluida en su membresía vigente ese día.
  final bool incluida;
  final int? reservaId;

  /// 1 reservada, 2 asistió, 3 faltó (null = sin reserva).
  final int? reservaEstado;
  final double? reservaMonto;
  final bool puedeCancelar;
  final int cancelarHoras;

  /// Por qué no puede reservar ('' = puede).
  final String motivo;

  const SesionClase({
    required this.claseId,
    required this.horarioId,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.nombre,
    required this.descripcion,
    required this.color,
    required this.entrenador,
    required this.salon,
    required this.aforo,
    required this.ocupados,
    required this.libres,
    required this.acceso,
    required this.precio,
    required this.membresiasNombres,
    required this.pasada,
    required this.incluida,
    required this.reservaId,
    required this.reservaEstado,
    required this.reservaMonto,
    required this.puedeCancelar,
    required this.cancelarHoras,
    required this.motivo,
  });

  bool get reservada => reservaEstado != null;
  bool get puedeReservar => !reservada && motivo.isEmpty;
  bool get llena => libres <= 0;

  /// Fecha y hora de inicio, para ordenar y para "mañana 07:00".
  DateTime get inicio {
    final p = horaInicio.split(':');
    return DateTime(
      fecha.year,
      fecha.month,
      fecha.day,
      int.tryParse(p.first) ?? 0,
      p.length > 1 ? int.tryParse(p[1]) ?? 0 : 0,
    );
  }

  factory SesionClase.fromJson(Map<String, dynamic> j) {
    int entero(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
    double? decimal(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    bool verdad(dynamic v) => v == true || v == 1 || v == '1';
    String texto(dynamic v) => (v ?? '').toString().trim();

    return SesionClase(
      claseId: entero(j['clase_id']),
      horarioId: entero(j['horario_id']),
      fecha: DateTime.tryParse(texto(j['fecha'])) ?? DateTime.now(),
      horaInicio: texto(j['hora_inicio']),
      horaFin: texto(j['hora_fin']),
      nombre: texto(j['nombre']),
      descripcion: texto(j['descripcion']),
      color: colorDesdeHex(texto(j['color'])),
      entrenador: texto(j['entrenador']),
      salon: texto(j['salon']),
      aforo: entero(j['aforo']),
      ocupados: entero(j['ocupados']),
      libres: entero(j['libres']),
      acceso: entero(j['acceso']),
      precio: decimal(j['precio']),
      membresiasNombres: texto(j['membresias_nombres']),
      pasada: verdad(j['pasada']),
      incluida: verdad(j['incluida']),
      reservaId: j['reserva_id'] == null ? null : entero(j['reserva_id']),
      reservaEstado: j['reserva_estado'] == null
          ? null
          : entero(j['reserva_estado']),
      reservaMonto: decimal(j['reserva_monto']),
      puedeCancelar: verdad(j['puede_cancelar']),
      cancelarHoras: entero(j['cancelar_horas']),
      motivo: texto(j['motivo']),
    );
  }
}

/// "#7C3AED" → Color. Un valor inválido cae en un morado neutro.
Color colorDesdeHex(String hex) {
  final limpio = hex.replaceFirst('#', '');
  final valor = int.tryParse(limpio, radix: 16);
  if (limpio.length != 6 || valor == null) return const Color(0xFF7C3AED);
  return Color(0xFF000000 | valor);
}

/// Respuesta de reservar o cancelar.
class ResultadoClase {
  final bool exito;
  final String mensaje;

  const ResultadoClase(this.exito, this.mensaje);
}
