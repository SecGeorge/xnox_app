import 'package:flutter/material.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_publicidad_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/membresia_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/qr_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/reporte_ejercicios_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/rutinas_screen.dart';
import 'package:xnox_app/features/tienda/presentacion/screen/comprar_screen.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_logout.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';

/// Contenedor principal de la experiencia del Cliente (socio del gimnasio).
/// Arranca en la pantalla de Publicidad y agrupa las secciones con una
/// barra de navegación inferior.
class ClienteShell extends StatefulWidget {
  const ClienteShell({super.key});

  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> {
  int _selectedIndex = 0;
  final _logout = CasoUsoLogout(RepositorioAuthImpl(HttpService()));

  static const _pantallas = [
    ClientePublicidadScreen(),
    MembresiaScreen(),
    ComprarScreen(),
    RutinasScreen(),
    ReporteEjerciciosScreen(),
    QrScreen(),
  ];

  static const _titulos = [
    'Inicio',
    'Membresía',
    'Comprar',
    'Rutinas',
    'Reporte',
    'Mi QR'
  ];

  Future<void> _cerrarSesion() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que deseas cerrar tu sesión?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColores.moroso),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );

    if (confirmar != true) return;
    await _logout.ejecutar();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: Text(_titulos[_selectedIndex]),
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(index: _selectedIndex, children: _pantallas),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColores.primario,
        unselectedItemColor: AppColores.textoSecundario,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.campaign_outlined),
              activeIcon: Icon(Icons.campaign),
              label: 'Inicio'),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_membership_outlined),
              activeIcon: Icon(Icons.card_membership),
              label: 'Membresía'),
          BottomNavigationBarItem(
              icon: Icon(Icons.storefront_outlined),
              activeIcon: Icon(Icons.storefront),
              label: 'Comprar'),
          BottomNavigationBarItem(
              icon: Icon(Icons.fitness_center_outlined),
              activeIcon: Icon(Icons.fitness_center),
              label: 'Rutinas'),
          BottomNavigationBarItem(
              icon: Icon(Icons.insights_outlined),
              activeIcon: Icon(Icons.insights),
              label: 'Reporte'),
          BottomNavigationBarItem(
              icon: Icon(Icons.qr_code_2_outlined),
              activeIcon: Icon(Icons.qr_code_2),
              label: 'Mi QR'),
        ],
      ),
    );
  }
}
