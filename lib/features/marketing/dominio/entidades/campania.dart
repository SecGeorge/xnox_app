/// Registro histórico de una campaña de mensajes enviada.
class Campania {
  final int? id;
  final String plantillaNombre;
  final String filtro;
  final int totalClientes;
  final String estado; // 'Completado' | 'Cancelado' | 'En progreso'
  final String fechaCreacion;
  final String administrador;

  Campania({
    this.id,
    required this.plantillaNombre,
    required this.filtro,
    required this.totalClientes,
    required this.estado,
    required this.fechaCreacion,
    required this.administrador,
  });

  factory Campania.fromJson(Map<String, dynamic> json) {
    return Campania(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      plantillaNombre: json['plantilla_nombre']?.toString() ?? '—',
      filtro: json['filtro']?.toString() ?? '',
      totalClientes: int.tryParse(json['total_clientes']?.toString() ?? '0') ?? 0,
      estado: json['estado']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
      administrador: json['administrador']?.toString() ?? '',
    );
  }
}
