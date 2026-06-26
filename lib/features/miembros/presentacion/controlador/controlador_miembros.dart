import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/miembros/datos/repositorios/repositorio_miembros_impl.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/dominio/repositorios/repositorio_miembros.dart';

class ControladorMiembros {
  final RepositorioMiembros _repositorio;

  ControladorMiembros._(this._repositorio);

  factory ControladorMiembros() =>
      ControladorMiembros._(RepositorioMiembrosImpl(HttpService()));

  Future<List<Miembro>> buscarMiembros() => _repositorio.buscar();
}
