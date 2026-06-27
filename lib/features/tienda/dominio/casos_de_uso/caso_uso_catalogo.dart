import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/dominio/repositorios/repositorio_tienda.dart';

class CasoUsoCatalogo {
  final RepositorioTienda repositorio;

  CasoUsoCatalogo(this.repositorio);

  Future<CatalogoTienda> ejecutar() => repositorio.obtenerCatalogo();
}
