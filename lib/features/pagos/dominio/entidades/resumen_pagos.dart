// Indicadores y series del módulo de Pagos (membresías del gimnasio).
//
// Refleja lo que el dashboard web (`InicioComponent.vue`) muestra a partir
// del endpoint `inicio.php`: KPIs de cobranza, pagos por día de la semana,
// evolución mensual e ingresos por tipo de membresía.

const List<String> _diasCorto = [
  'Dom', 'Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb',
];

const List<String> _mesesCorto = [
  'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
  'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
];

/// Un punto de una serie de barras (un día, un mes...).
class BarraPago {
  final String etiqueta;
  final double total;

  const BarraPago(this.etiqueta, this.total);
}

/// Un item de una distribución (un plan de membresía, un turno...).
class ItemDistribucion {
  final String etiqueta;
  final double valor;

  const ItemDistribucion(this.etiqueta, this.valor);
}

class ResumenPagos {
  // KPIs de cobranza (S/).
  final double totalPagos;
  final double pagosHoy;
  final double pagosSemana;
  final double pagosMes;

  // Series para los gráficos.
  final List<BarraPago> serieSemana; // pagos por día de la semana
  final List<BarraPago> serieMeses; // evolución de ingresos por mes
  final List<ItemDistribucion> membresias; // ingresos por tipo de plan
  final List<ItemDistribucion> asistencias; // asistencias por turno

  ResumenPagos({
    required this.totalPagos,
    required this.pagosHoy,
    required this.pagosSemana,
    required this.pagosMes,
    required this.serieSemana,
    required this.serieMeses,
    required this.membresias,
    required this.asistencias,
  });

  factory ResumenPagos.fromJson(Map<String, dynamic> json) {
    double aDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    int aInt(dynamic v) => int.tryParse(v?.toString() ?? '') ?? 0;

    final dp = (json['datosPagos'] as Map?) ?? const {};

    // Semana: completamos los 7 días para tener un eje X consistente.
    final porDia = <int, double>{};
    for (final r in (json['pagosSemana'] as List? ?? const []).whereType<Map>()) {
      final nd = aInt(r['numeroDia']); // 1 = Domingo ... 7 = Sábado (DAYOFWEEK)
      if (nd >= 1 && nd <= 7) porDia[nd] = aDouble(r['total']);
    }
    final serieSemana = [
      for (var i = 1; i <= 7; i++) BarraPago(_diasCorto[i - 1], porDia[i] ?? 0),
    ];

    // Evolución mensual (lo que devuelva el SP, ordenado por mes).
    final serieMeses = (json['pagosMeses'] as List? ?? const [])
        .whereType<Map>()
        .map((r) {
          final m = aInt(r['mes']);
          final etiqueta = (m >= 1 && m <= 12) ? _mesesCorto[m - 1] : '?';
          return BarraPago(etiqueta, aDouble(r['total']));
        })
        .toList();

    final membresias = (json['membresiasReportes'] as List? ?? const [])
        .whereType<Map>()
        .map((r) => ItemDistribucion(
              (r['nombre'] ?? 'Sin nombre').toString(),
              aDouble(r['monto']),
            ))
        .where((d) => d.valor > 0)
        .toList();

    final asistencias = (json['asistenciasTurnos'] as List? ?? const [])
        .whereType<Map>()
        .map((r) => ItemDistribucion(
              _capitalizar((r['turno'] ?? '').toString()),
              aDouble(r['cantidad']),
            ))
        .where((d) => d.valor > 0)
        .toList();

    return ResumenPagos(
      totalPagos: aDouble(dp['totalPagos']),
      pagosHoy: aDouble(dp['pagosHoy']),
      pagosSemana: aDouble(dp['pagosSemana']),
      pagosMes: aDouble(dp['pagosMes']),
      serieSemana: serieSemana,
      serieMeses: serieMeses,
      membresias: membresias,
      asistencias: asistencias,
    );
  }

  /// Datos de prueba para revisar el diseño sin conexión.
  factory ResumenPagos.demo() {
    return ResumenPagos(
      totalPagos: 128450,
      pagosHoy: 640,
      pagosSemana: 3210,
      pagosMes: 8450,
      serieSemana: const [
        BarraPago('Dom', 120),
        BarraPago('Lun', 540),
        BarraPago('Mar', 380),
        BarraPago('Mié', 610),
        BarraPago('Jue', 450),
        BarraPago('Vie', 720),
        BarraPago('Sáb', 390),
      ],
      serieMeses: const [
        BarraPago('Ene', 6200),
        BarraPago('Feb', 5800),
        BarraPago('Mar', 7100),
        BarraPago('Abr', 6900),
        BarraPago('May', 8200),
        BarraPago('Jun', 8450),
      ],
      membresias: const [
        ItemDistribucion('Plan Mensual', 9400),
        ItemDistribucion('Plan Trimestral', 5200),
        ItemDistribucion('Plan Anual', 3800),
        ItemDistribucion('Pase Diario', 1200),
      ],
      asistencias: const [
        ItemDistribucion('Mañana', 120),
        ItemDistribucion('Tarde', 80),
        ItemDistribucion('Noche', 140),
      ],
    );
  }

  static String _capitalizar(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
