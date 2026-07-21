import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/empresa/dominio/entidades/empresa.dart';
import 'package:xnox_app/features/empresa/presentacion/screen/seleccion_empresa_screen.dart';
import 'package:xnox_app/features/login/presentacion/screen/sesion_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  // Cookie de sesión persistente en disco: mantiene la sesión (y con ella los
  // datos guardados como la sucursal) al cerrar y reabrir la app.
  await HttpService().init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'XNOX-SOFT',
      navigatorKey: navigatorKey,
      scaffoldMessengerKey: scaffoldMessengerKey,
      debugShowCheckedModeBanner: false,
      theme: construirTema(),
      home: const ArranqueGate(),
    );
  }
}

/// Puerta de arranque: decide si mostrar la selección de empresa (primer
/// arranque, aún no hay empresa activa) o entrar directo al flujo de sesión.
/// HttpService().init() ya aplicó la ruta de la empresa activa antes de runApp.
class ArranqueGate extends StatefulWidget {
  const ArranqueGate({super.key});

  @override
  State<ArranqueGate> createState() => _ArranqueGateState();
}

class _ArranqueGateState extends State<ArranqueGate> {
  final Future<Empresa?> _empresa = EmpresaDao.instancia.activa();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Empresa?>(
      future: _empresa,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            backgroundColor: Colors.white,
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return snapshot.data == null
            ? const SeleccionEmpresaScreen()
            : const SesionGate();
      },
    );
  }
}
