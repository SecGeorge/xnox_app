import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/asistencia_cliente.dart';

/// Opción del filtro de contratos/membresías del cliente.
class OpcionMembresia {
  final int id;
  final String nombre;
  const OpcionMembresia(this.id, this.nombre);
}

/// Provee las asistencias del cliente y sus contratos para filtrar el
/// calendario. Reutiliza los endpoints del panel web (`miembros.php`).
class ControladorAsistencias {
  final HttpService _httpService = HttpService();

  Future<int> _miembroId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;
  }

  /// Carga inicial: lista de membresías (contratos) del cliente + asistencias
  /// recientes. Resuelve todo en una sola petición (`data_detalle_miembro`).
  Future<
      ({
        List<OpcionMembresia> membresias,
        List<AsistenciaCliente> asistencias,
      })> cargarInicial() async {
    final id = await _miembroId();
    if (id == 0) {
      return (
        membresias: <OpcionMembresia>[],
        asistencias: <AsistenciaCliente>[],
      );
    }

    final membresias = <OpcionMembresia>[];
    final asistencias = <AsistenciaCliente>[];

    try {
      final res = await _httpService.obtenerConDatos(
        {'metodo': 'data_detalle_miembro', 'id': id},
        'miembros.php',
      );
      if (res is Map) {
        final contratos = res['contratos'];
        if (contratos is List) {
          final vistos = <int>{};
          for (final c in contratos) {
            if (c is! Map) continue;
            final mid =
                int.tryParse(c['membresia_id']?.toString() ?? '') ?? 0;
            if (mid > 0 && vistos.add(mid)) {
              membresias.add(OpcionMembresia(
                mid,
                c['membresia_descripcion']?.toString() ?? 'Plan $mid',
              ));
            }
          }
        }
        final lista = res['asistencias'];
        if (lista is List) {
          asistencias.addAll(_mapear(lista));
        }
      }
    } catch (_) {
      // Sin red: devolvemos lo que se haya podido cargar.
    }

    return (membresias: membresias, asistencias: asistencias);
  }

  /// Asistencias filtradas por contrato/membresía. Con [membresiaId] = 0 el
  /// backend devuelve solo los últimos 2 meses; con un id concreto devuelve
  /// todas las asistencias de ese contrato.
  Future<List<AsistenciaCliente>> obtenerAsistencias(
      {int membresiaId = 0}) async {
    final id = await _miembroId();
    if (id == 0) return [];
    try {
      final res = await _httpService.obtenerConDatos(
        {
          'metodo': 'obtener_asistencias',
          'id_miembro': id,
          'sucursal_id': null,
          'id_membresia': membresiaId,
        },
        'miembros.php',
      );
      if (res is List) return _mapear(res);
    } catch (_) {
      // Sin red.
    }
    return [];
  }

  List<AsistenciaCliente> _mapear(List<dynamic> data) => data
      .whereType<Map>()
      .map((e) => AsistenciaCliente.desdeJson(Map<String, dynamic>.from(e)))
      .toList();
}
