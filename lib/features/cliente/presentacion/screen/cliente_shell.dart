import 'package:flutter/material.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/asistencias_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_publicidad_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/membresia_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/qr_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/reporte_ejercicios_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/rutinas_screen.dart';
import 'package:xnox_app/features/tienda/presentacion/screen/comprar_screen.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_logout.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';

/// Definición de una sección navegable del cliente.
class _SeccionNav {
  final IconData icono;
  final IconData iconoActivo;
  final String label;
  final Widget pantalla;

  const _SeccionNav({
    required this.icono,
    required this.iconoActivo,
    required this.label,
    required this.pantalla,
  });
}

/// Contenedor principal de la experiencia del Cliente (socio del gimnasio).
/// Arranca en la pantalla de Publicidad y agrupa las secciones con una barra
/// de navegación inferior. Las secciones principales van en la barra y el
/// resto se agrupan en un menú "Más" para no recargarla.
class ClienteShell extends StatefulWidget {
  const ClienteShell({super.key});

  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> {
  int _selectedIndex = 0;
  final _logout = CasoUsoLogout(RepositorioAuthImpl(HttpService()));

  // Secciones visibles directamente en la barra inferior.
  static const _principales = <_SeccionNav>[
    _SeccionNav(
        icono: Icons.campaign_outlined,
        iconoActivo: Icons.campaign,
        label: 'Inicio',
        pantalla: ClientePublicidadScreen()),
    _SeccionNav(
        icono: Icons.card_membership_outlined,
        iconoActivo: Icons.card_membership,
        label: 'Membresía',
        pantalla: MembresiaScreen()),
    _SeccionNav(
        icono: Icons.storefront_outlined,
        iconoActivo: Icons.storefront,
        label: 'Comprar',
        pantalla: ComprarScreen()),
    _SeccionNav(
        icono: Icons.fitness_center_outlined,
        iconoActivo: Icons.fitness_center,
        label: 'Rutinas',
        pantalla: RutinasScreen()),
  ];

  // Secciones secundarias agrupadas dentro del menú "Más".
  static const _secundarias = <_SeccionNav>[
    _SeccionNav(
        icono: Icons.calendar_month_outlined,
        iconoActivo: Icons.calendar_month,
        label: 'Asistencias',
        pantalla: AsistenciasScreen()),
    _SeccionNav(
        icono: Icons.qr_code_2_outlined,
        iconoActivo: Icons.qr_code_2,
        label: 'Mi QR',
        pantalla: QrScreen()),
    _SeccionNav(
        icono: Icons.insights_outlined,
        iconoActivo: Icons.insights,
        label: 'Reporte',
        pantalla: ReporteEjerciciosScreen()),
  ];

  static const List<_SeccionNav> _secciones = [..._principales, ..._secundarias];

  bool get _enSeccionSecundaria => _selectedIndex >= _principales.length;

  Future<void> _cerrarSesion() async {
    final confirmar = await confirmarDialog(
      context,
      titulo: 'Cerrar sesión',
      mensaje: '¿Seguro que deseas cerrar tu sesión?',
      icono: Icons.logout,
      textoConfirmar: 'Cerrar sesión',
      peligro: true,
    );

    if (!confirmar) return;
    await _logout.ejecutar();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _onTapNav(int index) {
    // El último ítem de la barra es siempre "Más".
    if (index == _principales.length) {
      _abrirMenuMas();
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  Future<void> _abrirMenuMas() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColores.borde,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                  AppEspaciado.lg, AppEspaciado.md, AppEspaciado.lg, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Más opciones',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal)),
              ),
            ),
            for (var i = 0; i < _secundarias.length; i++)
              _opcionMas(ctx, _principales.length + i, _secundarias[i]),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
  }

  Widget _opcionMas(BuildContext ctx, int indiceSeccion, _SeccionNav s) {
    final activo = _selectedIndex == indiceSeccion;
    return ListTile(
      leading: Icon(activo ? s.iconoActivo : s.icono,
          color: activo ? AppColores.primario : AppColores.textoSecundario),
      title: Text(
        s.label,
        style: TextStyle(
          fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
          color: activo ? AppColores.primario : AppColores.textoPrincipal,
        ),
      ),
      trailing: activo
          ? const Icon(Icons.check, size: 18, color: AppColores.primario)
          : null,
      onTap: () {
        Navigator.pop(ctx);
        setState(() => _selectedIndex = indiceSeccion);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final masActivo = _enSeccionSecundaria;
    // currentIndex de la barra: una sección principal, o el ítem "Más".
    final currentIndex = masActivo ? _principales.length : _selectedIndex;

    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: Text(_secciones[_selectedIndex].label),
        actions: [
          IconButton(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: _secciones.map((s) => s.pantalla).toList(),
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColores.primario,
        unselectedItemColor: AppColores.textoSecundario,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: currentIndex,
        onTap: _onTapNav,
        items: [
          for (final s in _principales)
            BottomNavigationBarItem(
              icon: Icon(s.icono),
              activeIcon: Icon(s.iconoActivo),
              label: s.label,
            ),
          BottomNavigationBarItem(
            icon: Icon(masActivo
                ? _secciones[_selectedIndex].iconoActivo
                : Icons.more_horiz),
            activeIcon: Icon(masActivo
                ? _secciones[_selectedIndex].iconoActivo
                : Icons.more_horiz),
            label: masActivo ? _secciones[_selectedIndex].label : 'Más',
          ),
        ],
      ),
    );
  }
}
