class EstadisticasDashboard {
  final String miembrosActivos;
  final String visitasHoy;
  final String ventasMes;
  final String nuevosRegistros;

  EstadisticasDashboard({
    required this.miembrosActivos,
    required this.visitasHoy,
    required this.ventasMes,
    required this.nuevosRegistros,
  });

  factory EstadisticasDashboard.fromJson(Map<String, dynamic> json) {
    return EstadisticasDashboard(
      miembrosActivos: json['miembros_activos']?.toString() ?? '0',
      visitasHoy: json['visitas_hoy']?.toString() ?? '0',
      ventasMes: json['ventas_mes']?.toString() ?? '0',
      nuevosRegistros: json['nuevos_registros']?.toString() ?? '0',
    );
  }
}
