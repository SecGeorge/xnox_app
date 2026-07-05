import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';

/// Resumen de puntos de fidelidad del cliente: saldo, historial de
/// movimientos y la configuración global vigente de la sucursal:
///   * [gana]  = productos que otorgan puntos al comprarse.
///   * [canje] = catálogo de items que se pueden reclamar con puntos.
class ResumenPuntos {
  final int saldo;
  final List<MovimientoPuntos> movimientos;
  final List<LineaGana> gana;
  final List<LineaCanje> canje;

  const ResumenPuntos({
    required this.saldo,
    required this.movimientos,
    required this.gana,
    required this.canje,
  });

  static const ResumenPuntos vacio =
      ResumenPuntos(saldo: 0, movimientos: [], gana: [], canje: []);
}

class MovimientoPuntos {
  final int tipo; // 1 = ganó, 2 = canjeó
  final int puntos; // positivo al ganar, negativo al canjear
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

/// Un producto que otorga puntos al comprarse.
class LineaGana {
  final int productoId;
  final String nombre;
  final int puntos;

  const LineaGana({
    required this.productoId,
    required this.nombre,
    required this.puntos,
  });
}

/// Un item del catálogo de canje (lo que se puede reclamar con puntos).
class LineaCanje {
  final int id;
  final String nombre;
  final int puntos;
  final int tipo; // 1 = producto, 2 = membresía

  const LineaCanje({
    required this.id,
    required this.nombre,
    required this.puntos,
    required this.tipo,
  });

  bool get esMembresia => tipo == 2;
}

/// Resultado de intentar un canje.
class ResultadoCanje {
  final bool exito;
  final String mensaje;
  final int? saldo; // saldo resultante si el backend lo devolvió

  const ResultadoCanje({
    required this.exito,
    required this.mensaje,
    this.saldo,
  });
}

class ControladorPromociones {
  final HttpService _httpService = HttpService();

  /// Lee miembro y sucursal de la sesión guardada en SharedPreferences.
  Future<(int, int)> _sesion() async {
    final prefs = await SharedPreferences.getInstance();
    final miembroId = int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
    return (miembroId, sucursalId);
  }

  Future<ResumenPuntos> obtenerResumen() async {
    final (miembroId, sucursalId) = await _sesion();
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

    return ResumenPuntos(
      saldo: saldo,
      movimientos: movimientos,
      gana: _mapearGana(datos['gana']),
      canje: _mapearCanje(datos['canje']),
    );
  }

  /// Ejecuta un canje del item [canjeId]; descuenta los puntos del miembro.
  Future<ResultadoCanje> canjear(int canjeId) async {
    final (miembroId, sucursalId) = await _sesion();
    if (miembroId == 0) {
      return const ResultadoCanje(
          exito: false, mensaje: 'Debes iniciar sesión para canjear');
    }

    final resp = await _httpService.registrar(
      {
        'metodo': 'canjear',
        'miembro_id': miembroId,
        'sucursal_id': sucursalId,
        'canje_id': canjeId,
      },
      'promociones.php',
    );

    if (resp is! Map) {
      return const ResultadoCanje(exito: false, mensaje: 'No se pudo canjear');
    }

    final exito = resp['success'] == true;
    String mensaje;
    int? saldo;

    if (resp['datos'] is List && (resp['datos'] as List).isNotEmpty) {
      final row = Map<String, dynamic>.from((resp['datos'] as List).first as Map);
      mensaje = row['voit_message']?.toString() ??
          resp['mensaje']?.toString() ??
          (exito ? 'Canje realizado' : 'No se pudo canjear');
      saldo = int.tryParse(row['saldo']?.toString() ?? '');
    } else {
      mensaje = resp['mensaje']?.toString() ??
          (exito ? 'Canje realizado' : 'No se pudo canjear');
    }

    return ResultadoCanje(exito: exito, mensaje: mensaje, saldo: saldo);
  }

  List<LineaGana> _mapearGana(dynamic lista) {
    final out = <LineaGana>[];
    if (lista is List) {
      for (final g in lista) {
        final gm = Map<String, dynamic>.from(g as Map);
        out.add(LineaGana(
          productoId: int.tryParse(gm['producto_id']?.toString() ?? '0') ?? 0,
          nombre: gm['producto_nombre']?.toString() ?? 'Producto',
          puntos: int.tryParse(gm['puntos']?.toString() ?? '0') ?? 0,
        ));
      }
    }
    return out;
  }

  List<LineaCanje> _mapearCanje(dynamic lista) {
    final out = <LineaCanje>[];
    if (lista is List) {
      for (final c in lista) {
        final cm = Map<String, dynamic>.from(c as Map);
        final tipo = int.tryParse(cm['tipo']?.toString() ?? '1') ?? 1;
        final nombre = tipo == 2
            ? (cm['membresia_nombre']?.toString() ?? 'Membresía')
            : (cm['producto_nombre']?.toString() ?? 'Producto');
        out.add(LineaCanje(
          id: int.tryParse(cm['id']?.toString() ?? '0') ?? 0,
          nombre: nombre,
          puntos: int.tryParse(cm['puntos']?.toString() ?? '0') ?? 0,
          tipo: tipo,
        ));
      }
    }
    return out;
  }
}
