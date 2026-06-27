/// Una asistencia (ingreso) del cliente al gimnasio.
class AsistenciaCliente {
  final int id;
  final DateTime fecha;
  final String hora; // HH:mm
  final int contratoId;
  final String membresia;
  final String usuario;

  const AsistenciaCliente({
    required this.id,
    required this.fecha,
    required this.hora,
    required this.contratoId,
    required this.membresia,
    required this.usuario,
  });

  factory AsistenciaCliente.desdeJson(Map<String, dynamic> j) {
    final fechaStr = j['fecha']?.toString() ?? '';
    final horaRaw = j['hora']?.toString() ?? '';
    return AsistenciaCliente(
      id: int.tryParse(j['id']?.toString() ?? '') ?? 0,
      fecha: DateTime.tryParse(fechaStr) ?? DateTime(1970),
      hora: horaRaw.length >= 5 ? horaRaw.substring(0, 5) : horaRaw,
      contratoId: int.tryParse(j['contrato_id']?.toString() ?? '') ?? 0,
      membresia: j['membresia_descripcion']?.toString() ?? '—',
      usuario: j['usuario']?.toString() ?? '—',
    );
  }

  /// Clave normalizada del día (yyyy-MM-dd) para indexar el calendario.
  String get claveDia =>
      '${fecha.year.toString().padLeft(4, '0')}-'
      '${fecha.month.toString().padLeft(2, '0')}-'
      '${fecha.day.toString().padLeft(2, '0')}';
}
