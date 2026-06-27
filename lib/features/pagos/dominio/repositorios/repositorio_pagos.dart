import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';

abstract class RepositorioPagos {
  Future<ResumenPagos> obtenerResumen();
}
