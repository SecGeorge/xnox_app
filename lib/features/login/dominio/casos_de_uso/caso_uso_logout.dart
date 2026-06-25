import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class CasoUsoLogout {
  final RepositorioAuth repositorio;

  CasoUsoLogout(this.repositorio);

  Future<void> ejecutar() async {
    await repositorio.logout();
  }
}
