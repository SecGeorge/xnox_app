import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';
import 'package:xnox_app/features/dashboard/dominio/repositorios/repositorio_dashboard.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';

class RepositorioDashboardImpl implements RepositorioDashboard {
  final HttpService _httpService;

  RepositorioDashboardImpl(this._httpService);

  @override
  Future<EstadisticasDashboard> obtenerEstadisticas() async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    // 1) Padrón de miembros -> conteos por estado y cobranza.
    final miembrosResp = await _httpService.obtenerConDatos(
      {
        'metodo': 'buscar',
        'sucursal_id': sucursalId,
        'filtros': <String, dynamic>{},
      },
      'miembros.php',
    );

    if (miembrosResp is! List) {
      throw Exception('No se pudieron cargar las estadísticas de miembros');
    }

    // 2) Ingresos del mes (pagos) desde el dashboard de inicio.
    double ingresosMes = 0;
    try {
      final dash = await _httpService.obtenerConDatos(
        {'metodo': 'obtener', 'sucursal_id': sucursalId},
        'inicio.php',
      );
      if (dash is Map && dash['datosPagos'] is Map) {
        ingresosMes =
            double.tryParse(dash['datosPagos']['pagosMes']?.toString() ?? '0') ??
                0;
      }
    } catch (_) {
      // Si el módulo de pagos falla, mostramos el resto igual con ingresos en 0.
    }

    int activos = 0, deudores = 0, morosos = 0, vencidos = 0;
    int porVencer = 0, nuevosRegistros = 0;
    double montoPorCobrar = 0;

    final ahora = DateTime.now();
    final hoy = DateTime(ahora.year, ahora.month, ahora.day);
    final limite7Dias = hoy.add(const Duration(days: 7));

    for (final raw in miembrosResp.whereType<Map>()) {
      final json = Map<String, dynamic>.from(raw);
      final m = Miembro.fromJson(json);

      switch (m.estado) {
        case EstadoMiembro.activo:
          activos++;
          break;
        case EstadoMiembro.deudor:
          deudores++;
          break;
        case EstadoMiembro.moroso:
          morosos++;
          break;
        case EstadoMiembro.vencido:
          vencidos++;
          break;
      }

      montoPorCobrar += m.saldoPendiente;

      // Por vencer: la membresía caduca dentro de los próximos 7 días.
      final fv = m.fechaVencimiento;
      if (fv != null && !fv.isBefore(hoy) && fv.isBefore(limite7Dias)) {
        porVencer++;
      }

      // Nuevos registros del mes en curso.
      final fechaRegistro =
          DateTime.tryParse(json['fechaRegistro']?.toString() ?? '');
      if (fechaRegistro != null &&
          fechaRegistro.year == ahora.year &&
          fechaRegistro.month == ahora.month) {
        nuevosRegistros++;
      }
    }

    return EstadisticasDashboard(
      ingresosMes: ingresosMes,
      miembrosActivos: activos,
      montoPorCobrar: montoPorCobrar,
      porVencer: porVencer,
      nuevosRegistros: nuevosRegistros,
      totalDeudores: deudores,
      totalMorosos: morosos,
      totalVencidos: vencidos,
    );
  }
}
