import 'package:flutter/material.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';

class ControladorLogin {
  final CasoUsoLogin _casoUsoLogin;

  ControladorLogin() : _casoUsoLogin = CasoUsoLogin(RepositorioAuthImpl(HttpService()));

  Future<RespuestaLogin> login(String usuario, String password) async {
    if (usuario.isEmpty || password.isEmpty) {
      return RespuestaLogin(success: false, message: 'Por favor, complete todos los campos');
    }
    return await _casoUsoLogin.ejecutar(usuario, password);
  }
}
