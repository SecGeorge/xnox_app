import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_publicidad_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/membresia_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/qr_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/reporte_ejercicios_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/rutinas_screen.dart';

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

  static const _pantallas = [
    ClientePublicidadScreen(),
    MembresiaScreen(),
    RutinasScreen(),
    ReporteEjerciciosScreen(),
    QrScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: IndexedStack(index: _selectedIndex, children: _pantallas),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColores.primario,
        unselectedItemColor: AppColores.textoSecundario,
        selectedFontSize: 12,
        unselectedFontSize: 12,
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
