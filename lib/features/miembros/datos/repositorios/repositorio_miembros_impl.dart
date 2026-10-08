import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/dominio/repositorios/repositorio_miembros.dart';

class RepositorioMiembrosImpl implements RepositorioMiembros {
  final HttpService _httpService;

  RepositorioMiembrosImpl(this._httpService);

  @override
  Future<List<Miembro>> buscar() async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    final payload = {
      'metodo': 'buscar',
      'sucursal_id': sucursalId,
      // Sin filtros: el backend devuelve todos los miembros de la sucursal.
      'filtros': <String, dynamic>{},
    };

    final response = await _httpService.obtenerConDatos(
      payload,
      'miembros.php',
    );

    // El endpoint `buscar` responde con un arreglo JSON de miembros.
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => Miembro.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    final mensaje = response is Map && response['error'] != null
        ? response['error'].toString()
        : 'No se pudieron cargar los miembros';
    throw Exception(mensaje);
  }

  @override
  Future<List<MiembroAlerta>> proximosVencer({int dias = 7}) =>
      _reporte('proximos_vencer', dias, 'dias_restantes');

  @override
  Future<List<MiembroAlerta>> vencidosRecuperar({int dias = 30}) =>
      _reporte('vencidos_recuperar', dias, 'dias_vencido');

  /// Reportes de vencimientos del panel web (mismos stored procedures).
  Future<List<MiembroAlerta>> _reporte(
    String metodo,
    int dias,
    String campoDias,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
    final response = await _httpService.obtenerConDatos({
      'metodo': metodo,
      'sucursal_id': sucursalId,
      'dias': dias,
    }, 'reportes.php');
    final filas = response is Map ? response['response'] : null;
    if (filas is List) {
      return filas
          .whereType<Map>()
          .map(
            (e) =>
                MiembroAlerta.fromJson(Map<String, dynamic>.from(e), campoDias),
          )
          .toList();
    }
    throw Exception('No se pudo cargar el reporte de vencimientos');
  }
}
