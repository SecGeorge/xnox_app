import 'package:flutter/material.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_shell.dart';
import 'package:xnox_app/features/dashboard/presentacion/screen/dashboard_screen.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';
import 'package:xnox_app/features/login/presentacion/controlador/controlador_login.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';

/// Pantalla inicial que decide a dónde entrar: si hay una sesión guardada se
/// va directo al área correspondiente; si no, muestra el login.
class SesionGate extends StatefulWidget {
  const SesionGate({super.key});

  @override
  State<SesionGate> createState() => _SesionGateState();
}

class _SesionGateState extends State<SesionGate> {
  final _controlador = ControladorLogin();
  late final Future<TipoUsuario?> _sesion = _controlador.sesionActiva();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<TipoUsuario?>(
      future: _sesion,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        switch (snapshot.data) {
          case TipoUsuario.cliente:
            return const ClienteShell();
          case TipoUsuario.administrador:
            return const DashboardScreen();
          case null:
            return const LoginScreen();
        }
      },
    );
  }
}
