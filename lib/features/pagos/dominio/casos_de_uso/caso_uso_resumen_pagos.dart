import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';
import 'package:xnox_app/features/pagos/dominio/repositorios/repositorio_pagos.dart';

class CasoUsoResumenPagos {
  final RepositorioPagos repositorio;

  CasoUsoResumenPagos(this.repositorio);

  Future<ResumenPagos> ejecutar() {
    return repositorio.obtenerResumen();
  }
}
