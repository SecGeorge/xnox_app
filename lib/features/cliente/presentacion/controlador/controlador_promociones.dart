import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';

/// Resumen de puntos de fidelidad del cliente: saldo, historial de
/// movimientos y el catálogo de promociones activas (cómo ganar / qué canjear).
class ResumenPuntos {
  final int saldo;
  final List<MovimientoPuntos> movimientos;
  final List<PromocionCliente> promociones;

  const ResumenPuntos({
    required this.saldo,
    required this.movimientos,
    required this.promociones,
  });

  static const ResumenPuntos vacio =
      ResumenPuntos(saldo: 0, movimientos: [], promociones: []);
}

class MovimientoPuntos {
  final int tipo; // 1 = ganó, 2 = canjeó
  final int puntos;
  final String concepto;
  final String fecha;

  const MovimientoPuntos({
    required this.tipo,
    required this.puntos,
    required this.concepto,
    required this.fecha,
  });

  bool get esGanancia => tipo == 1;
}

/// Una regla de acumulación o de canje dentro de una promoción.
class LineaPromocion {
  final String nombre;
  final int puntos;
  final int tipo; // en canje: 1 = producto, 2 = membresía

  const LineaPromocion(
      {required this.nombre, required this.puntos, this.tipo = 0});
}

class PromocionCliente {
  final String nombre;
  final String? descripcion;
  final List<LineaPromocion> gana;
  final List<LineaPromocion> canje;

  const PromocionCliente({
    required this.nombre,
    this.descripcion,
    required this.gana,
    required this.canje,
  });
}

class ControladorPromociones {
  final HttpService _httpService = HttpService();

  Future<ResumenPuntos> obtenerResumen() async {
    final prefs = await SharedPreferences.getInstance();
    final miembroId = int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    if (miembroId == 0) return ResumenPuntos.vacio;

    final resp = await _httpService.obtenerConDatos(
      {
        'metodo': 'mis_puntos',
        'miembro_id': miembroId,
        'sucursal_id': sucursalId,
      },
      'promociones.php',
    );

    if (resp is! Map || resp['success'] != true || resp['datos'] is! Map) {
      return ResumenPuntos.vacio;
    }

    final datos = Map<String, dynamic>.from(resp['datos'] as Map);

    final saldo = int.tryParse(datos['saldo']?.toString() ?? '0') ?? 0;

    final movimientos = <MovimientoPuntos>[];
    if (datos['movimientos'] is List) {
      for (final m in (datos['movimientos'] as List)) {
        final mp = Map<String, dynamic>.from(m as Map);
        movimientos.add(MovimientoPuntos(
          tipo: int.tryParse(mp['tipo']?.toString() ?? '1') ?? 1,
          puntos: int.tryParse(mp['puntos']?.toString() ?? '0') ?? 0,
          concepto: mp['concepto']?.toString() ?? 'Movimiento de puntos',
          fecha: mp['fecha']?.toString() ?? '',
        ));
      }
    }

    final promociones = <PromocionCliente>[];
    if (datos['promociones'] is List) {
      for (final p in (datos['promociones'] as List)) {
        final pm = Map<String, dynamic>.from(p as Map);
        promociones.add(PromocionCliente(
          nombre: pm['nombre']?.toString() ?? 'Promoción',
          descripcion: pm['descripcion']?.toString(),
          gana: _mapearGana(pm['gana']),
          canje: _mapearCanje(pm['canje']),
        ));
      }
    }

    return ResumenPuntos(
      saldo: saldo,
      movimientos: movimientos,
      promociones: promociones,
    );
  }

  List<LineaPromocion> _mapearGana(dynamic lista) {
    final out = <LineaPromocion>[];
    if (lista is List) {
      for (final g in lista) {
        final gm = Map<String, dynamic>.from(g as Map);
        out.add(LineaPromocion(
          nombre: gm['producto_nombre']?.toString() ?? 'Producto',
          puntos: int.tryParse(gm['puntos']?.toString() ?? '0') ?? 0,
        ));
      }
    }
    return out;
  }

  List<LineaPromocion> _mapearCanje(dynamic lista) {
    final out = <LineaPromocion>[];
    if (lista is List) {
      for (final c in lista) {
        final cm = Map<String, dynamic>.from(c as Map);
        final tipo = int.tryParse(cm['tipo']?.toString() ?? '1') ?? 1;
        final nombre = tipo == 2
            ? (cm['membresia_nombre']?.toString() ?? 'Membresía')
            : (cm['producto_nombre']?.toString() ?? 'Producto');
        out.add(LineaPromocion(
          nombre: nombre,
          puntos: int.tryParse(cm['puntos']?.toString() ?? '0') ?? 0,
          tipo: tipo,
        ));
      }
    }
    return out;
  }
}
