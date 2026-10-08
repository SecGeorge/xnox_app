import 'package:flutter/material.dart';
import 'package:xnox_app/core/widgets/dialogo_cerrar_sesion.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/features/asistencia/presentacion/screen/asistencia_admin_screen.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/core/widgets/logo_gimnasio.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ajustes/presentacion/screen/config_yape_screen.dart';
import 'package:xnox_app/features/ajustes/presentacion/screen/colores_app_screen.dart';
import 'package:xnox_app/features/ajustes/presentacion/screen/datos_negocio_screen.dart';
import 'package:xnox_app/features/ajustes/presentacion/screen/perfil_screen.dart';
import 'package:xnox_app/features/ajustes/presentacion/screen/seguridad_screen.dart';
import 'package:xnox_app/features/dashboard/presentacion/controlador/controlador_dashboard.dart';
import 'package:xnox_app/features/dashboard/presentacion/widget/grafico_dona.dart';
import 'package:xnox_app/features/dashboard/dominio/entidades/estadisticas_dashboard.dart';
import 'package:xnox_app/features/lector_pagos/presentacion/screen/lector_pagos_screen.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';
import 'package:xnox_app/features/marketing/presentacion/screen/campanas_screen.dart';
import 'package:xnox_app/features/marketing/presentacion/screen/plantillas_screen.dart';
import 'package:xnox_app/features/miembros/presentacion/screen/miembros_screen.dart';
import 'package:xnox_app/features/pagos/presentacion/screen/pagos_screen.dart';
import 'package:xnox_app/features/publicidad/presentacion/screen/publicidad_screen.dart';
import 'package:xnox_app/features/recomendaciones/presentacion/screen/enviar_recomendacion_screen.dart';
import 'package:xnox_app/features/recomendaciones/presentacion/screen/recomendaciones_screen.dart';
import 'package:xnox_app/features/recomendaciones/presentacion/widget/buzon_recomendaciones.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/rutinas_admin_screen.dart';
import 'package:xnox_app/features/ventas/presentacion/screen/ventas_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _dashboardController = ControladorDashboard();
  EstadisticasDashboard? _stats;
  bool _isLoading = true;

  // Permisos del usuario y las secciones del menú que le corresponden. La barra
  // inferior se arma con `_secciones`, no con una lista fija, para que cada rol
  // vea solo lo que su permiso `mobile_*` habilita (el Administrador ve todo).
  Permisos _permisos = Permisos.desde('', 0);
  List<_SeccionAdmin> _secciones = const [];
  bool _permisosCargados = false;

  /// Nombre de quien inició sesión, para saludarlo en el inicio.
  String _nombreUsuario = '';

  @override
  void initState() {
    super.initState();
    _cargarPermisos();
    _cargarDatos();
  }

  Future<void> _cargarPermisos() async {
    final permisos = await Permisos.cargar();
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nombreUsuario = (prefs.getString('nombreCliente') ?? '').trim();
      _permisos = permisos;
      _secciones = _construirSecciones(permisos);
      _permisosCargados = true;
    });
  }

  /// Secciones visibles en la barra inferior según los permisos del rol.
  /// "Ajustes" siempre está (perfil y seguridad son de la propia cuenta).
  List<_SeccionAdmin> _construirSecciones(Permisos p) {
    return [
      if (p.tiene(PermisosMovil.inicio))
        _SeccionAdmin(
          Icons.dashboard_outlined,
          Icons.dashboard,
          'Inicio',
          () => Scaffold(
            backgroundColor: AppColores.fondo,
            body: _buildHomeView(),
          ),
        ),
      if (p.tiene(PermisosMovil.miembros))
        _SeccionAdmin(
          Icons.people_outline,
          Icons.people,
          'Miembros',
          () => const MiembrosScreen(),
        ),
      if (p.tiene(PermisosMovil.asistencia))
        _SeccionAdmin(
          Icons.how_to_reg_outlined,
          Icons.how_to_reg,
          'Asistencia',
          () => const AsistenciaAdminScreen(),
        ),
      if (p.tiene(PermisosMovil.pagos))
        _SeccionAdmin(
          Icons.payments_outlined,
          Icons.payments,
          'Pagos',
          () => const PagosScreen(),
        ),
      // Un solo acceso "Ventas" para el punto de venta y los pedidos de la app:
      // dentro se muestra lo que cada permiso habilite.
      if (p.tieneAlguno([
        PermisosMovil.ventas,
        PermisosMovil.pedidos,
        PermisosMovil.ventasHistorial,
      ]))
        _SeccionAdmin(
          Icons.point_of_sale_outlined,
          Icons.point_of_sale,
          'Ventas',
          () => const VentasScreen(),
        ),
      if (p.tiene(PermisosMovil.publicidad))
        _SeccionAdmin(
          Icons.campaign_outlined,
          Icons.campaign,
          'Publicidad',
          () => const PublicidadScreen(),
        ),
      if (p.tiene(PermisosMovil.rutinas))
        _SeccionAdmin(
          Icons.fitness_center_outlined,
          Icons.fitness_center,
          'Rutinas',
          () => const RutinasAdminScreen(),
        ),
      _SeccionAdmin(
        Icons.settings_outlined,
        Icons.settings,
        'Ajustes',
        () => Scaffold(
          backgroundColor: AppColores.fondo,
          body: _buildSettingsView(),
        ),
      ),
    ];
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
      mostrarMensaje(
        context,
        'No se pudo cargar el resumen del negocio',
        tipo: TipoMensaje.error,
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    // Mientras se cargan los permisos, evitamos parpadeos armando una barra
    // incorrecta: mostramos un loader breve.
    if (!_permisosCargados) {
      return Scaffold(
        backgroundColor: AppColores.fondo,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // Salvaguarda: si el índice quedó fuera de rango (p. ej. tras recargar
    // permisos con menos secciones), lo acotamos.
    final indice = _selectedIndex.clamp(0, _secciones.length - 1);
    return _conNav(_secciones[indice].builder());
  }

  /// Envuelve cualquier pantalla con el menú lateral y su botón flotante.
  Widget _conNav(Widget child) {
    final indice = _selectedIndex.clamp(0, _secciones.length - 1);
    final seccion = _secciones[indice];
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColores.fondo,
      drawer: _buildMenu(),
      body: child,
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
      // Botón del menú: dice en qué sección está y abre las demás.
      floatingActionButton: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () => _scaffoldKey.currentState?.openDrawer(),
            borderRadius: BorderRadius.circular(28),
            child: Ink(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 18),
              decoration: BoxDecoration(
                gradient: AppColores.degradadoRelleno,
                border: AppColores.bordeCabecera,
                borderRadius: BorderRadius.circular(28),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.menu_rounded, color: AppColores.sobreRelleno),
                  const SizedBox(width: 8),
                  Text(
                    seccion.label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColores.sobreRelleno,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Pide confirmación: el botón queda cerca del menú y un toque de más
  /// no debe sacar al usuario de la app.
  Future<void> _cerrarSesion() async {
    final ok = await confirmarCerrarSesion(context, nombre: _nombreUsuario);
    if (!ok || !mounted) return;
    await _dashboardController.cerrarSesion();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  /// Menú lateral izquierdo con todas las secciones del rol.
  Widget _buildMenu() {
    final indice = _selectedIndex.clamp(0, _secciones.length - 1);
    const detalles = {
      'Inicio': 'Resumen del negocio',
      'Miembros': 'Socios y su estado',
      'Asistencia': 'Registrar entradas',
      'Pagos': 'Cobranza de membresías',
      'Ventas': 'Punto de venta y pedidos',
      'Publicidad': 'Novedades y promociones',
      'Rutinas': 'Rutinas semanales',
      'Ajustes': 'Cuenta, negocio y cobros',
    };
    return Drawer(
      width: 304,
      backgroundColor: AppColores.fondo,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(28)),
      ),
      child: Column(
        children: [
          // Cabecera con foto, logo y nombre del gimnasio.
          SizedBox(
            height: 190,
            width: double.infinity,
            child: FotoTarjeta(
              foto: FotosApp.membresia,
              alineacion: const Alignment(0.3, -0.3),
              radio: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: ValueListenableBuilder<MarcaGimnasio>(
                    valueListenable: ControladorMarca.instancia.marca,
                    builder: (_, marca, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const LogoGimnasio(tamano: 52),
                        const Spacer(),
                        Text(
                          (marca.nombre ?? '').isEmpty
                              ? 'Mi gimnasio'
                              : marca.nombre!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _nombreUsuario.isEmpty
                              ? 'Panel del gimnasio'
                              : _nombreUsuario,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColores.destacado,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 14, 12, 12),
              children: [
                for (var i = 0; i < _secciones.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: _itemMenu(
                      _secciones[i],
                      detalles[_secciones[i].label],
                      activo: i == indice,
                      onTap: () {
                        Navigator.of(context).pop();
                        _onItemTapped(i);
                      },
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _cerrarSesion,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Cerrar sesión'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColores.moroso,
                    side: BorderSide(
                      color: AppColores.moroso.withValues(alpha: 0.4),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppEspaciado.radio),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemMenu(
    _SeccionAdmin s,
    String? detalle, {
    required bool activo,
    required VoidCallback onTap,
  }) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Material(
      color: activo ? null : AppColores.superficie,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: activo ? AppColores.degradadoRelleno : null,
            borderRadius: radio,
            border: activo
                ? AppColores.bordeCabecera
                : Border.all(color: AppColores.borde),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: activo
                      ? Colors.white.withValues(alpha: 0.16)
                      : AppColores.primario.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                ),
                child: Icon(
                  activo ? s.iconoActivo : s.icono,
                  color: activo ? AppColores.sobreRelleno : AppColores.primario,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.label,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: activo
                            ? AppColores.sobreRelleno
                            : AppColores.textoPrincipal,
                      ),
                    ),
                    if (detalle != null)
                      Text(
                        detalle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: activo
                              ? AppColores.sobreRellenoSuave
                              : AppColores.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- Inicio
  Widget _buildHomeView() {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _cargarDatos,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppEspaciado.md,
            AppEspaciado.md,
            AppEspaciado.md,
            100,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: AppEspaciado.md + 4),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildTarjetaIngresos(),
              ..._buildAtencion(),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.grid_view_rounded,
                titulo: 'Accesos rápidos',
              ),
              _buildAccesos(),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.insights_rounded,
                titulo: 'Indicadores',
              ),
              _buildGridEstadisticas(),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.donut_large_rounded,
                titulo: 'Estado de membresías',
              ),
              _buildDistribucionMiembros(),
              if (_permisos.tiene(PermisosMovil.marketing)) ...[
                const SizedBox(height: AppEspaciado.lg),
                const TituloSeccion(
                  icono: Icons.campaign_rounded,
                  titulo: 'Marketing',
                ),
                _buildMarketing(),
              ],
            ],
          ],
        ),
      ),
    );
  }

  /// Formatea un monto como moneda peruana: 8450 -> "S/ 8,450".
  String _soles(double valor) =>
      'S/ ${NumberFormat('#,##0', 'es').format(valor)}';

  /// Va a una pestaña de la barra inferior por su nombre (si el rol la tiene).
  void _irA(String label) {
    final i = _secciones.indexWhere((s) => s.label == label);
    if (i >= 0) setState(() => _selectedIndex = i);
  }

  bool _tieneSeccion(String label) => _secciones.any((s) => s.label == label);

  Widget _buildHeader() {
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? 'Buenos días'
        : hora < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    final nombre = _nombreUsuario.split(' ').first;
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());
    final dia = '${fecha[0].toUpperCase()}${fecha.substring(1)}';
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre.isEmpty
                    ? saludo
                    : 'Hola, ${nombre[0].toUpperCase()}${nombre.substring(1).toLowerCase()}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nombre.isEmpty ? dia : '$saludo · $dia',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        if (_permisos.tiene(PermisosMovil.recomendaciones)) ...[
          const BuzonRecomendaciones(redonda: true),
          const SizedBox(width: 8),
        ],
        const CampanaAvisos(redonda: true),
        const SizedBox(width: 8),
        const LogoGimnasio(tamano: 46),
      ],
    );
  }

  /// Portada: lo que más le importa al dueño, los ingresos del mes.
  Widget _buildTarjetaIngresos() {
    final s = _stats;
    final mes = DateFormat('MMMM', 'es').format(DateTime.now());
    return ValueListenableBuilder<MarcaGimnasio>(
      valueListenable: ControladorMarca.instancia.marca,
      builder: (context, marca, _) => PortadaFoto(
        foto: FotosApp.membresia,
        alineacion: const Alignment(0.3, -0.3),
        altura: 200,
        etiqueta: 'Ingresos de $mes',
        titulo: s != null ? _soles(s.ingresosMes) : '--',
        texto: (marca.nombre ?? '').isEmpty ? null : marca.nombre,
        onTap: _tieneSeccion('Pagos') ? () => _irA('Pagos') : null,
        pie: Row(
          children: [
            DatoPortada(
              icono: Icons.people_alt_rounded,
              valor: '${s?.totalMiembros ?? '--'}',
              pie: 'miembros',
            ),
            const SizedBox(width: 18),
            DatoPortada(
              icono: Icons.account_balance_wallet_rounded,
              valor: s != null ? _soles(s.montoPorCobrar) : '--',
              pie: 'por cobrar',
            ),
          ],
        ),
      ),
    );
  }

  /// Avisos que piden acción hoy: membresías por vencer y morosos.
  List<Widget> _buildAtencion() {
    final s = _stats;
    if (s == null || (s.porVencer == 0 && s.totalMorosos == 0)) return [];
    final irMiembros = _tieneSeccion('Miembros')
        ? () => _irA('Miembros')
        : null;
    return [
      const SizedBox(height: AppEspaciado.lg),
      const TituloSeccion(
        icono: Icons.notification_important_rounded,
        titulo: 'Atención hoy',
      ),
      IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (s.porVencer > 0)
              Expanded(
                child: _aviso(
                  Icons.schedule_rounded,
                  AppColores.naranja,
                  '${s.porVencer}',
                  'por vencer',
                  irMiembros,
                ),
              ),
            if (s.porVencer > 0 && s.totalMorosos > 0)
              const SizedBox(width: AppEspaciado.sm + 2),
            if (s.totalMorosos > 0)
              Expanded(
                child: _aviso(
                  Icons.error_outline_rounded,
                  AppColores.moroso,
                  '${s.totalMorosos}',
                  s.totalMorosos == 1 ? 'moroso' : 'morosos',
                  irMiembros,
                ),
              ),
          ],
        ),
      ),
    ];
  }

  Widget _aviso(
    IconData icono,
    Color color,
    String valor,
    String texto,
    VoidCallback? onTap,
  ) {
    return TarjetaPlana(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      color: color.withValues(alpha: 0.07),
      colorBorde: color.withValues(alpha: 0.35),
      child: Row(
        children: [
          IconoSuave(icono, color: color, circular: true, tamano: 40),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 20,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          if (onTap != null)
            Icon(Icons.chevron_right_rounded, color: color, size: 20),
        ],
      ),
    );
  }

  /// Accesos con foto a las pestañas que el rol tiene.
  Widget _buildAccesos() {
    final s = _stats;
    final accesos = [
      if (_tieneSeccion('Miembros'))
        (
          'Miembros',
          s == null ? 'Socios' : '${s.miembrosActivos} activos',
          Icons.people_alt_rounded,
          FotosApp.hombros,
        ),
      if (_tieneSeccion('Pagos'))
        ('Pagos', 'Cobranza', Icons.payments_rounded, FotosApp.piernas),
      if (_tieneSeccion('Ventas'))
        (
          'Ventas',
          'Tienda y pedidos',
          Icons.point_of_sale_rounded,
          FotosApp.tienda,
        ),
      if (_tieneSeccion('Rutinas'))
        (
          'Rutinas',
          'Planes semanales',
          Icons.fitness_center_rounded,
          FotosApp.rutinas,
        ),
      if (_tieneSeccion('Publicidad'))
        ('Publicidad', 'Novedades', Icons.campaign_rounded, FotosApp.progreso),
    ];
    if (accesos.isEmpty) return const SizedBox.shrink();
    final filas = <Widget>[];
    for (var i = 0; i < accesos.length; i += 2) {
      final arriba = EdgeInsets.only(top: i == 0 ? 0 : AppEspaciado.sm + 2);
      // Si queda uno suelto, va a lo ancho.
      if (i + 1 >= accesos.length) {
        filas.add(Padding(padding: arriba, child: _tileFoto(accesos[i])));
        break;
      }
      filas.add(
        Padding(
          padding: arriba,
          child: Row(
            children: [
              Expanded(child: _tileFoto(accesos[i])),
              const SizedBox(width: AppEspaciado.sm + 2),
              Expanded(child: _tileFoto(accesos[i + 1])),
            ],
          ),
        ),
      );
    }
    return Column(children: filas);
  }

  Widget _tileFoto((String, String, IconData, String) a) {
    final (titulo, subtitulo, icono, foto) = a;
    return SizedBox(
      height: 132,
      child: FotoTarjeta(
        foto: foto,
        radio: AppEspaciado.radio + 4,
        onTap: () => _irA(titulo),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: AppColores.degradadoRelleno,
                  border: AppColores.bordeCabecera,
                  shape: BoxShape.circle,
                ),
                child: Icon(icono, size: 19, color: AppColores.sobreRelleno),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          subtitulo,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Cifras que no salen en el gráfico de membresías: altas del mes,
  /// vencimientos cercanos, deuda y lo que deja cada socio.
  Widget _buildGridEstadisticas() {
    final s = _stats;
    final promedio = s == null || s.miembrosActivos == 0
        ? 0.0
        : s.ingresosMes / s.miembrosActivos;
    final tarjetas = [
      _StatData(
        'Nuevos este mes',
        '${s?.nuevosRegistros ?? '--'}',
        Icons.person_add_alt_1_rounded,
        AppColores.azul,
        s == null ? '' : 'de ${s.totalMiembros} miembros',
      ),
      _StatData(
        'Por vencer',
        '${s?.porVencer ?? '--'}',
        Icons.schedule_rounded,
        AppColores.naranja,
        'en los próximos 7 días',
      ),
      _StatData(
        'Por cobrar',
        s != null ? _soles(s.montoPorCobrar) : '--',
        Icons.account_balance_wallet_rounded,
        AppColores.moroso,
        s == null ? '' : '${s.totalDeudores + s.totalMorosos} con deuda',
      ),
      _StatData(
        'Por socio activo',
        s != null
            ? 'S/ ${NumberFormat('#,##0.00', 'es').format(promedio)}'
            : '--',
        Icons.trending_up_rounded,
        AppColores.activo,
        'ingreso promedio del mes',
      ),
    ];

    // Dos filas con IntrinsicHeight: cada fila mide lo de su tarjeta más alta
    // (con un GridView de proporción fija el texto se desbordaba).
    return Column(
      children: [
        _filaEstadisticas(tarjetas[0], tarjetas[1]),
        const SizedBox(height: _espacioTarjetas),
        _filaEstadisticas(tarjetas[2], tarjetas[3]),
      ],
    );
  }

  static const double _espacioTarjetas = AppEspaciado.sm + 2;

  Widget _filaEstadisticas(_StatData izquierda, _StatData derecha) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildStatCard(izquierda)),
          const SizedBox(width: _espacioTarjetas),
          Expanded(child: _buildStatCard(derecha)),
        ],
      ),
    );
  }

  Widget _buildStatCard(_StatData data) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
        border: Border.all(color: data.color.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: data.color.withValues(alpha: 0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Círculo decorativo del color del indicador.
          Positioned(
            right: -26,
            top: -26,
            child: Container(
              width: 86,
              height: 86,
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: data.color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: data.color.withValues(alpha: 0.35),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(data.icono, color: Colors.white, size: 20),
                ),
                const SizedBox(height: 14),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    data.valor,
                    style: TextStyle(
                      fontSize: 24,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  data.titulo,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                if (data.pie.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    data.pie,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.25,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
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
      SegmentoDona('Sin membresía', s.totalVencidos, AppColores.vencido),
    ];

    return TarjetaPlana(
      padding: const EdgeInsets.all(AppEspaciado.md + 2),
      child: Row(
        children: [
          GraficoDona(
            segmentos: segmentos,
            centroValor: '${s.totalMiembros}',
            centroEtiqueta: 'miembros',
            tamano: 116,
            grosor: 13,
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
    );
  }

  Widget _leyendaItem(SegmentoDona seg, int total) {
    final fraccion = total == 0 ? 0.0 : seg.valor / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: seg.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  seg.etiqueta,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ),
              Text(
                '${seg.valor}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: fraccion,
              minHeight: 4,
              color: seg.color,
              backgroundColor: seg.color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }

  /// Accesos al módulo de Marketing y Comunicación (WhatsApp), con foto.
  Widget _buildMarketing() {
    return Column(
      children: [
        SizedBox(
          height: 120,
          child: FotoTarjeta(
            foto: FotosApp.motivacion,
            alineacion: const Alignment(0.5, -0.3),
            radio: AppEspaciado.radio + 4,
            degradadoHorizontal: true,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CampanasScreen())),
            child: Padding(
              padding: const EdgeInsets.all(AppEspaciado.md),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'WHATSAPP',
                          style: TextStyle(
                            fontSize: 11,
                            letterSpacing: 1.3,
                            fontWeight: FontWeight.w800,
                            color: AppColores.destacado,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Envío de mensajes',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Recordar pagos y recuperar clientes',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.82),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: AppColores.degradadoRelleno,
                      border: AppColores.bordeCabecera,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.send_rounded,
                      color: AppColores.sobreRelleno,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppEspaciado.sm + 2),
        TarjetaPlana(
          onTap: () => Navigator.of(
            context,
          ).push(MaterialPageRoute(builder: (_) => const PlantillasScreen())),
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const IconoSuave(Icons.text_snippet_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Plantillas',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const Text(
                      'Mensajes de WhatsApp listos para usar',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColores.textoSecundario,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsView() {
    void ir(Widget pantalla) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
    final negocio = _permisos.tiene(PermisosMovil.ajustesNegocio);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md,
          AppEspaciado.md,
          AppEspaciado.md,
          AppEspaciado.xl,
        ),
        children: [
          const CabeceraApp(
            titulo: 'Ajustes',
            subtitulo: 'Tu cuenta y la configuración del gimnasio',
            atras: false,
            acciones: [CampanaAvisos(redonda: true)],
          ),
          const SizedBox(height: AppEspaciado.md + 4),
          // Tarjeta del gimnasio con su logo.
          ValueListenableBuilder<MarcaGimnasio>(
            valueListenable: ControladorMarca.instancia.marca,
            builder: (_, marca, _) => PortadaFoto(
              foto: FotosApp.membresia,
              alineacion: const Alignment(0.3, -0.3),
              altura: 140,
              etiqueta: _nombreUsuario.isEmpty
                  ? 'Tu gimnasio'
                  : 'Hola, ${_nombreUsuario.split(' ').first}',
              titulo: (marca.nombre ?? '').isEmpty
                  ? 'Mi gimnasio'
                  : marca.nombre!,
              texto: 'Personaliza datos, colores y cobros.',
            ),
          ),
          const SizedBox(height: AppEspaciado.lg),
          _grupoAjustes('Mi cuenta', [
            _ajusteFila(
              Icons.person_rounded,
              'Mi perfil',
              'Datos de la cuenta',
              () => ir(const PerfilScreen()),
            ),
            _ajusteFila(
              Icons.lock_rounded,
              'Seguridad',
              'Contraseña y acceso',
              () => ir(const SeguridadScreen()),
            ),
          ]),
          if (negocio ||
              _permisos.tiene(PermisosMovil.ajustesYape) ||
              _permisos.tiene(PermisosMovil.lectorPagos))
            _grupoAjustes('Negocio', [
              if (negocio)
                _ajusteFila(
                  Icons.storefront_rounded,
                  'Datos del negocio',
                  'Nombre, logo y dirección',
                  () => ir(const DatosNegocioScreen()),
                ),
              if (negocio)
                _ajusteFila(
                  Icons.palette_rounded,
                  'Colores de la app',
                  'Plantillas con el estilo de tu gimnasio',
                  () => ir(const ColoresAppScreen()),
                ),
              if (_permisos.tiene(PermisosMovil.ajustesYape))
                _ajusteFila(
                  Icons.qr_code_2_rounded,
                  'Pago por Yape',
                  'Número y QR para que tus clientes paguen',
                  () => ir(const ConfigYapeScreen()),
                ),
              if (_permisos.tiene(PermisosMovil.lectorPagos))
                _ajusteFila(
                  Icons.qr_code_scanner_rounded,
                  'Lector de pagos',
                  'Registrar Yape/Plin automáticamente',
                  () => ir(const LectorPagosScreen()),
                ),
            ]),
          // El buzón también vive en el encabezado de Inicio, pero un rol sin
          // `mobile_inicio` nunca ve esa pantalla: aquí siempre lo encuentra.
          _grupoAjustes('Comunidad', [
            if (_permisos.tiene(PermisosMovil.recomendaciones))
              _ajusteFila(
                Icons.rate_review_rounded,
                'Recomendaciones recibidas',
                'Sugerencias de tus socios',
                () => ir(const RecomendacionesScreen()),
              ),
            // Sin permiso: cualquier perfil de la app puede dejar la suya.
            _ajusteFila(
              Icons.lightbulb_rounded,
              'Dejar una recomendación',
              'Envía tu sugerencia al administrador',
              () => ir(const EnviarRecomendacionScreen()),
            ),
          ]),
          const SizedBox(height: AppEspaciado.sm),
          SizedBox(
            height: 50,
            child: OutlinedButton.icon(
              onPressed: _cerrarSesion,
              icon: const Icon(Icons.logout_rounded),
              label: const Text('Cerrar sesión'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColores.moroso,
                side: BorderSide(
                  color: AppColores.moroso.withValues(alpha: 0.4),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppEspaciado.radio),
                ),
                textStyle: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _grupoAjustes(String titulo, List<Widget> filas) {
    if (filas.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: AppEspaciado.sm),
            child: Text(
              titulo.toUpperCase(),
              style: const TextStyle(
                fontSize: 11.5,
                letterSpacing: 1.3,
                fontWeight: FontWeight.w700,
                color: AppColores.textoSecundario,
              ),
            ),
          ),
          GrupoFilas(filas: filas),
        ],
      ),
    );
  }

  Widget _ajusteFila(
    IconData icono,
    String titulo,
    String subtitulo,
    VoidCallback onTap,
  ) {
    return FilaApp(
      onTap: onTap,
      inicio: IconoSuave(icono),
      titulo: titulo,
      subtitulo: subtitulo,
      fin: const Icon(
        Icons.chevron_right_rounded,
        color: AppColores.textoSecundario,
      ),
    );
  }
}

class _StatData {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  final String pie;
  _StatData(this.titulo, this.valor, this.icono, this.color, [this.pie = '']);
}

class _SeccionAdmin {
  final IconData icono;
  final IconData iconoActivo;
  final String label;
  final Widget Function() builder;

  const _SeccionAdmin(this.icono, this.iconoActivo, this.label, this.builder);
}
