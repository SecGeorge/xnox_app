import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/pagos/datos/repositorios/repositorio_pagos_impl.dart';
import 'package:xnox_app/features/pagos/dominio/casos_de_uso/caso_uso_resumen_pagos.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';

class ControladorPagos {
  final CasoUsoResumenPagos _casoUsoResumen;

  ControladorPagos()
      : _casoUsoResumen =
            CasoUsoResumenPagos(RepositorioPagosImpl(HttpService()));

  Future<ResumenPagos> obtenerResumen() {
    return _casoUsoResumen.ejecutar();
  }
}
