import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/dashboard/presentacion/controlador/controlador_dashboard.dart';
import 'package:xnox_app/features/dashboard/presentacion/widget/grafico_dona.dart';
import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';
import 'package:xnox_app/features/miembros/presentacion/screen/miembros_screen.dart';
import 'package:xnox_app/features/pagos/presentacion/screen/pagos_screen.dart';
import 'package:xnox_app/features/publicidad/presentacion/screen/publicidad_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final _dashboardController = ControladorDashboard();
  EstadisticasDashboard? _stats;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _dashboardController.obtenerEstadisticas();
      if (!mounted) return;
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarMensaje(context, 'No se pudo cargar el resumen del negocio',
          tipo: TipoMensaje.error);
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Las pantallas con Scaffold propio se muestran directamente.
    switch (_selectedIndex) {
      case 1:
        return _conNav(const MiembrosScreen());
      case 2:
        return _conNav(const PagosScreen());
      case 3:
        return _conNav(const PublicidadScreen());
    }

    return _conNav(
      Scaffold(
        backgroundColor: AppColores.fondo,
        body: _selectedIndex == 4 ? _buildSettingsView() : _buildHomeView(),
      ),
    );
  }

  /// Envuelve cualquier pantalla con la barra de navegación inferior común.
  Widget _conNav(Widget child) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: child,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      backgroundColor: Colors.white,
      selectedItemColor: AppColores.primario,
      unselectedItemColor: AppColores.textoSecundario,
      selectedFontSize: 11,
      unselectedFontSize: 11,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.dashboard_outlined), activeIcon: Icon(Icons.dashboard), label: 'Inicio'),
        BottomNavigationBarItem(icon: Icon(Icons.people_outline), activeIcon: Icon(Icons.people), label: 'Miembros'),
        BottomNavigationBarItem(icon: Icon(Icons.payments_outlined), activeIcon: Icon(Icons.payments), label: 'Pagos'),
        BottomNavigationBarItem(icon: Icon(Icons.campaign_outlined), activeIcon: Icon(Icons.campaign), label: 'Publicidad'),
        BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Ajustes'),
      ],
    );
  }

  // ------------------------------------------------------------------- Inicio
  Widget _buildHomeView() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AppEspaciado.md, AppEspaciado.lg,
              AppEspaciado.md, AppEspaciado.lg),
          children: [
            _buildHeader(),
            const SizedBox(height: AppEspaciado.lg),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildGridEstadisticas(),
              const SizedBox(height: AppEspaciado.md),
              _buildDistribucionMiembros(),
            ],
          ],
        ),
      ),
    );
  }

  /// Formatea un monto como moneda peruana: 8450 -> "S/ 8,450".
  String _soles(double valor) =>
      'S/ ${NumberFormat('#,##0', 'es').format(valor)}';

  Widget _buildHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Resumen General',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColores.textoPrincipal,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Indicadores principales del negocio',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColores.superficie,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColores.borde),
          ),
          child: const Icon(Icons.notifications_none,
              color: AppColores.primario),
        ),
      ],
    );
  }

  Widget _buildGridEstadisticas() {
    final s = _stats;
    final tarjetas = [
      _StatData('Ingresos del Mes', s != null ? _soles(s.ingresosMes) : '--',
          Icons.monetization_on, AppColores.verde),
      _StatData('Miembros Activos', '${s?.miembrosActivos ?? '--'}',
          Icons.people, AppColores.azul),
      _StatData('Por Cobrar', s != null ? _soles(s.montoPorCobrar) : '--',
          Icons.account_balance_wallet, AppColores.moroso),
      _StatData('Por Vencer (7 días)', '${s?.porVencer ?? '--'}',
          Icons.event_busy, AppColores.naranja),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppEspaciado.sm + 4,
      crossAxisSpacing: AppEspaciado.sm + 4,
      childAspectRatio: 1.4,
      children: tarjetas.map(_buildStatCard).toList(),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Icon(data.icono, color: data.color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.valor,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                data.titulo,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Tarjeta con la distribución de miembros por estado (gráfico de dona).
  Widget _buildDistribucionMiembros() {
    final s = _stats;
    if (s == null) return const SizedBox.shrink();

    final segmentos = [
      SegmentoDona('Activos', s.miembrosActivos, AppColores.activo),
      SegmentoDona('Deudores', s.totalDeudores, AppColores.deudor),
      SegmentoDona('Morosos', s.totalMorosos, AppColores.moroso),
      SegmentoDona('Sin membresia', s.totalVencidos, AppColores.vencido),
    ];

    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(
            titulo: 'Estado de Membresías',
            subtitulo: 'Distribución del padrón de miembros',
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              GraficoDona(
                segmentos: segmentos,
                centroValor: '${s.totalMiembros}',
                centroEtiqueta: 'miembros',
              ),
              const SizedBox(width: AppEspaciado.lg),
              Expanded(
                child: Column(
                  children: segmentos
                      .map((seg) => _leyendaItem(seg, s.totalMiembros))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _leyendaItem(SegmentoDona seg, int total) {
    final porcentaje = total == 0 ? 0 : (seg.valor / total * 100).round();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
              color: seg.color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              seg.etiqueta,
              style: const TextStyle(
                fontSize: 13,
                color: AppColores.textoSecundario,
              ),
            ),
          ),
          Text(
            '${seg.valor}',
            style: const TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '($porcentaje%)',
            style: const TextStyle(
              fontSize: 12,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsView() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppEspaciado.md),
        children: [
          const SizedBox(height: AppEspaciado.sm),
          const Text(
            'Ajustes',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.lg),
          _ajusteTile(Icons.person_outline, 'Mi perfil', 'Datos de la cuenta'),
          const SizedBox(height: AppEspaciado.sm + 4),
          _ajusteTile(Icons.business_outlined, 'Datos del negocio', 'Nombre, logo y dirección'),
          const SizedBox(height: AppEspaciado.sm + 4),
          _ajusteTile(Icons.lock_outline, 'Seguridad', 'Contraseña y acceso'),
          const SizedBox(height: AppEspaciado.lg),
          ElevatedButton.icon(
            onPressed: () async {
              await _dashboardController.cerrarSesion();
              if (mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout),
            label: const Text('Cerrar Sesión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColores.moroso,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _ajusteTile(IconData icono, String titulo, String subtitulo) {
    return TarjetaApp(
      onTap: () {},
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: AppEspaciado.sm + 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColores.primario.withValues(alpha: 0.08),
            child: Icon(icono, color: AppColores.primario, size: 22),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColores.textoSecundario),
        ],
      ),
    );
  }
}

class _StatData {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  _StatData(this.titulo, this.valor, this.icono, this.color);
}
