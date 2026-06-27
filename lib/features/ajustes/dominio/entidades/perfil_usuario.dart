/// Estadísticas de actividad del usuario logueado.
/// Provienen de `usuarios.php` -> método `informacion_perfil`
/// (procedimiento `sp_usuarios_estadisticas_perfil`).
class PerfilUsuario {
  final int totalVisitas;
  final int visitasHoy;
  final int visitasSemana;
  final int visitasMes;

  final double totalPagos;
  final double pagosHoy;
  final double pagosSemana;
  final double pagosMes;

  const PerfilUsuario({
    required this.totalVisitas,
    required this.visitasHoy,
    required this.visitasSemana,
    required this.visitasMes,
    required this.totalPagos,
    required this.pagosHoy,
    required this.pagosSemana,
    required this.pagosMes,
  });

  factory PerfilUsuario.fromJson(Map<String, dynamic> json) {
    int aInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    double aDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;

    return PerfilUsuario(
      totalVisitas: aInt(json['totalVisitas']),
      visitasHoy: aInt(json['visitasHoy']),
      visitasSemana: aInt(json['visitasSemana']),
      visitasMes: aInt(json['visitasMes']),
      totalPagos: aDouble(json['totalPagos']),
      pagosHoy: aDouble(json['pagosHoy']),
      pagosSemana: aDouble(json['pagosSemana']),
      pagosMes: aDouble(json['pagosMes']),
    );
  }
}
