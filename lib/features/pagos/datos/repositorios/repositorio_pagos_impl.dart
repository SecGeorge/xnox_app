import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';
import 'package:xnox_app/features/pagos/dominio/repositorios/repositorio_pagos.dart';

class RepositorioPagosImpl implements RepositorioPagos {
  final HttpService _httpService;

  RepositorioPagosImpl(this._httpService);

  @override
  Future<ResumenPagos> obtenerResumen() async {
    final prefs = await SharedPreferences.getInstance();
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;

    // Mismo endpoint que consume el dashboard web (InicioComponent.vue).
    final resp = await _httpService.obtenerConDatos(
      {'metodo': 'obtener', 'sucursal_id': sucursalId},
      'inicio.php',
    );

    if (resp is! Map) {
      throw Exception('Respuesta inválida del servidor de pagos');
    }
    if (resp['error'] != null) {
      throw Exception(resp['error'].toString());
    }

    return ResumenPagos.fromJson(Map<String, dynamic>.from(resp));
  }
}
