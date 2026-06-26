/// Resumen de indicadores del negocio mostrado en el dashboard.
///
/// Pensado para un gimnasio/club con membresías: lo que de verdad importa
/// es la cobranza (ingresos, morosos, por vencer) y la retención.
class EstadisticasDashboard {
  /// Ingresos cobrados en el mes actual (S/).
  final double ingresosMes;

  /// Miembros con membresía vigente y al día.
  final int miembrosActivos;

  /// Total de dinero pendiente de cobro (deudores + morosos).
  final double montoPorCobrar;

  /// Membresías que vencen en los próximos 7 días.
  final int porVencer;

  /// Nuevos miembros registrados en el mes.
  final int nuevosRegistros;

  // Desglose por estado para el gráfico de dona.
  final int totalDeudores;
  final int totalMorosos;
  final int totalVencidos;

  EstadisticasDashboard({
    required this.ingresosMes,
    required this.miembrosActivos,
    required this.montoPorCobrar,
    required this.porVencer,
    required this.nuevosRegistros,
    required this.totalDeudores,
    required this.totalMorosos,
    required this.totalVencidos,
  });

  /// Total de miembros en el padrón (todos los estados).
  int get totalMiembros =>
      miembrosActivos + totalDeudores + totalMorosos + totalVencidos;

  factory EstadisticasDashboard.fromJson(Map<String, dynamic> json) {
    double aDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    int aInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;

    return EstadisticasDashboard(
      ingresosMes: aDouble(json['ingresos_mes']),
      miembrosActivos: aInt(json['miembros_activos']),
      montoPorCobrar: aDouble(json['monto_por_cobrar']),
      porVencer: aInt(json['por_vencer']),
      nuevosRegistros: aInt(json['nuevos_registros']),
      totalDeudores: aInt(json['total_deudores']),
      totalMorosos: aInt(json['total_morosos']),
      totalVencidos: aInt(json['total_vencidos']),
    );
  }

  /// Datos de prueba para ver el diseño antes de conectar la base de datos.
  factory EstadisticasDashboard.demo() {
    return EstadisticasDashboard(
      ingresosMes: 8450,
      miembrosActivos: 142,
      montoPorCobrar: 1240,
      porVencer: 11,
      nuevosRegistros: 14,
      totalDeudores: 18,
      totalMorosos: 9,
      totalVencidos: 23,
    );
  }
}
