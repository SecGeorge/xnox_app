import 'package:flutter/material.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';

int _entero(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;
double? _decimal(dynamic v) => v == null ? null : double.tryParse(v.toString());
bool _verdad(dynamic v) => v == true || v == 1 || v == '1';
String _texto(dynamic v) => (v ?? '').toString().trim();

/// Especialidad de las citas (igual que `CitasDominio::ESPECIALIDADES`).
enum Especialidad {
  masajes(1, 'Masajes', Icons.spa_rounded),
  nutricion(2, 'Nutricionista', Icons.restaurant_menu_rounded),
  otra(3, 'Otras citas', Icons.medical_services_rounded);

  final int valor;
  final String nombre;
  final IconData icono;

  const Especialidad(this.valor, this.nombre, this.icono);

  static Especialidad desde(int v) =>
      values.firstWhere((e) => e.valor == v, orElse: () => otra);
}

/// Lo que se reserva (Masaje relajante 60 min, Consulta nutricional 45 min).
class TipoCita {
  final int id;
  final Especialidad especialidad;
  final String nombre;
  final String descripcion;
  final int duracionMin;
  final Color color;

  /// 1 incluida en cualquier membresía, 2 solo en algunos planes, 3 de pago.
  final int acceso;
  final double? precio;
  final int cancelarHoras;

  /// Si hoy la tiene incluida en su membresía.
  final bool incluida;

  /// Por qué no puede reservar ('' = puede).
  final String motivo;
  final List<ProfesionalCita> profesionales;

  const TipoCita({
    required this.id,
    required this.especialidad,
    required this.nombre,
    required this.descripcion,
    required this.duracionMin,
    required this.color,
    required this.acceso,
    required this.precio,
    required this.cancelarHoras,
    required this.incluida,
    required this.motivo,
    required this.profesionales,
  });

  bool get puedeReservar => motivo.isEmpty;

  String get duracionTexto {
    if (duracionMin < 60) return '$duracionMin min';
    final h = duracionMin ~/ 60;
    final r = duracionMin % 60;
    return r == 0 ? '$h h' : '$h h $r min';
  }

  factory TipoCita.fromJson(Map<String, dynamic> j) => TipoCita(
    id: _entero(j['id']),
    especialidad: Especialidad.desde(_entero(j['especialidad'])),
    nombre: _texto(j['nombre']),
    descripcion: _texto(j['descripcion']),
    duracionMin: _entero(j['duracion_min']),
    color: colorDesdeHex(_texto(j['color'])),
    acceso: _entero(j['acceso']),
    precio: _decimal(j['precio']),
    cancelarHoras: _entero(j['cancelar_horas']),
    incluida: _verdad(j['incluida']),
    motivo: _texto(j['motivo']),
    profesionales:
        (j['profesionales'] is List ? j['profesionales'] as List : const [])
            .whereType<Map>()
            .map((p) => ProfesionalCita.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
  );
}

class ProfesionalCita {
  final int id;
  final String nombre;
  final String descripcion;

  const ProfesionalCita(this.id, this.nombre, this.descripcion);

  factory ProfesionalCita.fromJson(Map<String, dynamic> j) => ProfesionalCita(
    _entero(j['id']),
    _texto(j['nombre']),
    _texto(j['descripcion']),
  );
}

/// Un turno libre con un profesional.
class TurnoCita {
  final DateTime fecha;
  final int profesionalId;
  final String profesional;
  final String horaInicio;
  final String horaFin;

  const TurnoCita({
    required this.fecha,
    required this.profesionalId,
    required this.profesional,
    required this.horaInicio,
    required this.horaFin,
  });
}

/// Una cita del socio (`mis_citas`).
class CitaSocio {
  final int id;
  final int tipoId;
  final String tipo;
  final Especialidad especialidad;
  final Color color;
  final String profesional;
  final DateTime fecha;
  final String horaInicio;
  final String horaFin;

  /// 1 reservada, 2 atendida, 3 no asistió.
  final int estado;
  final bool incluida;
  final double monto;
  final bool pagada;
  final bool pasada;
  final bool puedeCancelar;
  final int cancelarHoras;

  const CitaSocio({
    required this.id,
    required this.tipoId,
    required this.tipo,
    required this.especialidad,
    required this.color,
    required this.profesional,
    required this.fecha,
    required this.horaInicio,
    required this.horaFin,
    required this.estado,
    required this.incluida,
    required this.monto,
    required this.pagada,
    required this.pasada,
    required this.puedeCancelar,
    required this.cancelarHoras,
  });

  bool get pendiente => estado == 1 && !pasada;

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

  factory CitaSocio.fromJson(Map<String, dynamic> j) => CitaSocio(
    id: _entero(j['id']),
    tipoId: _entero(j['tipo_id']),
    tipo: _texto(j['tipo']),
    especialidad: Especialidad.desde(_entero(j['especialidad'])),
    color: colorDesdeHex(_texto(j['color'])),
    profesional: _texto(j['profesional']),
    fecha: DateTime.tryParse(_texto(j['fecha'])) ?? DateTime.now(),
    horaInicio: _texto(j['hora_inicio']),
    horaFin: _texto(j['hora_fin']),
    estado: _entero(j['estado']),
    incluida: _verdad(j['incluida']),
    monto: _decimal(j['monto']) ?? 0,
    pagada: _verdad(j['pagada']),
    pasada: _verdad(j['pasada']),
    puedeCancelar: _verdad(j['puede_cancelar']),
    cancelarHoras: _entero(j['cancelar_horas']),
  );
}

/// Tipos que ofrece el gimnasio y las citas del socio.
class CatalogoCitas {
  final List<TipoCita> tipos;
  final List<CitaSocio> citas;

  const CatalogoCitas(this.tipos, this.citas);

  static const vacio = CatalogoCitas([], []);

  List<Especialidad> get especialidades => Especialidad.values
      .where((e) => tipos.any((t) => t.especialidad == e))
      .toList();

  List<CitaSocio> get proximas =>
      citas.where((c) => c.pendiente).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));
}
