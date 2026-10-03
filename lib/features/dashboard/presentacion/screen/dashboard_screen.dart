import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
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

  /// Envuelve cualquier pantalla con la barra de navegación inferior común.
  Widget _conNav(Widget child) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: child,
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildBottomNav() {
    final indice = _selectedIndex.clamp(0, _secciones.length - 1);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: AppColores.borde)),
      ),
      child: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        backgroundColor: AppColores.superficie,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700),
        selectedItemColor: AppColores.primario,
        unselectedItemColor: AppColores.textoSecundario,
        selectedFontSize: 11,
        unselectedFontSize: 11,
        currentIndex: indice,
        onTap: _onItemTapped,
        items: [
          for (final s in _secciones)
            BottomNavigationBarItem(
              icon: Icon(s.icono),
              activeIcon: Icon(s.iconoActivo),
              label: s.label,
            ),
        ],
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
            AppEspaciado.xl,
          ),
          children: [
            _buildHeader(),
            const SizedBox(height: AppEspaciado.lg),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else ...[
              _buildTarjetaIngresos(),
              const SizedBox(height: AppEspaciado.lg),
              _tituloSeccion('Indicadores'),
              _buildGridEstadisticas(),
              const SizedBox(height: AppEspaciado.lg),
              _tituloSeccion('Estado de membresías'),
              _buildDistribucionMiembros(),
              if (_permisos.tiene(PermisosMovil.marketing)) ...[
                const SizedBox(height: AppEspaciado.lg),
                _tituloSeccion('Marketing y comunicación'),
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

  Widget _buildHeader() {
    final hora = DateTime.now().hour;
    final saludo = hora < 12
        ? 'Buenos días'
        : hora < 19
        ? 'Buenas tardes'
        : 'Buenas noches';
    final nombre = _nombreUsuario.split(' ').first;
    final fecha = DateFormat("EEEE d 'de' MMMM", 'es').format(DateTime.now());
    return Row(
      children: [
        const LogoGimnasio(tamano: 46),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                nombre.isEmpty ? saludo : '$saludo, $nombre',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 2),
              ValueListenableBuilder<MarcaGimnasio>(
                valueListenable: ControladorMarca.instancia.marca,
                builder: (context, marca, _) {
                  final dia = '${fecha[0].toUpperCase()}${fecha.substring(1)}';
                  final gimnasio = marca.nombre ?? '';
                  return Text(
                    gimnasio.isEmpty ? dia : gimnasio,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColores.textoSecundario,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        if (_permisos.tiene(PermisosMovil.recomendaciones))
          _botonCabecera(BuzonRecomendaciones(color: AppColores.primario)),
        const SizedBox(width: 6),
        _botonCabecera(CampanaAvisos(color: AppColores.primario)),
      ],
    );
  }

  /// Envuelve los íconos de la cabecera en un círculo suave.
  Widget _botonCabecera(Widget hijo) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        shape: BoxShape.circle,
        border: Border.all(color: AppColores.borde),
      ),
      child: FittedBox(child: hijo),
    );
  }

  /// Tarjeta principal: lo que más le importa al dueño, los ingresos del mes.
  Widget _buildTarjetaIngresos() {
    final s = _stats;
    final mes = DateFormat('MMMM yyyy', 'es').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 6),
        boxShadow: [
          BoxShadow(
            color: AppColores.relleno.withValues(alpha: 0.25),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'INGRESOS DEL MES',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w700,
                  color: AppColores.sobreRellenoSuave,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppColores.sobreRelleno.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${mes[0].toUpperCase()}${mes.substring(1)}',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColores.sobreRelleno,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm + 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              s != null ? _soles(s.ingresosMes) : '--',
              style: TextStyle(
                fontSize: 36,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: AppColores.sobreRelleno,
              ),
            ),
          ),
          const SizedBox(height: AppEspaciado.md + 2),
          Container(
            height: 1,
            color: AppColores.sobreRelleno.withValues(alpha: 0.14),
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              Expanded(
                child: _datoIngresos(
                  Icons.people_alt_outlined,
                  '${s?.totalMiembros ?? '--'}',
                  'miembros',
                ),
              ),
              Expanded(
                child: _datoIngresos(
                  Icons.account_balance_wallet_outlined,
                  s != null ? _soles(s.montoPorCobrar) : '--',
                  'por cobrar',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _datoIngresos(IconData icono, String valor, String etiqueta) {
    return Row(
      children: [
        Icon(icono, size: 18, color: AppColores.sobreRellenoSuave),
        const SizedBox(width: 8),
        Flexible(
          child: RichText(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            text: TextSpan(
              children: [
                TextSpan(
                  text: valor,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.sobreRelleno,
                  ),
                ),
                TextSpan(
                  text: ' $etiqueta',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColores.sobreRellenoSuave,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridEstadisticas() {
    final s = _stats;
    final tarjetas = [
      _StatData(
        'Miembros activos',
        '${s?.miembrosActivos ?? '--'}',
        Icons.how_to_reg_outlined,
        AppColores.activo,
      ),
      _StatData(
        'Nuevos este mes',
        '${s?.nuevosRegistros ?? '--'}',
        Icons.person_add_alt_1_outlined,
        AppColores.azul,
      ),
      _StatData(
        'Morosos',
        '${s?.totalMorosos ?? '--'}',
        Icons.error_outline,
        AppColores.moroso,
      ),
      _StatData(
        'Vencen en 7 días',
        '${s?.porVencer ?? '--'}',
        Icons.event_outlined,
        AppColores.naranja,
      ),
    ];

    // Dos filas en vez de un GridView con proporción fija: con una altura
    // calculada a partir del ancho, el texto se desbordaba (8px) según la
    // métrica de fuente del dispositivo. Con IntrinsicHeight cada fila mide lo
    // que necesita su tarjeta más alta, y ambas quedan iguales.
    return Column(
      children: [
        _filaEstadisticas(tarjetas[0], tarjetas[1]),
        const SizedBox(height: _espacioTarjetas),
        _filaEstadisticas(tarjetas[2], tarjetas[3]),
      ],
    );
  }

  static const double _espacioTarjetas = AppEspaciado.sm + 4;

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
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  data.valor,
                  style: TextStyle(
                    fontSize: 24,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  data.titulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.25,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icono, color: data.color, size: 17),
          ),
        ],
      ),
    );
  }

  /// Título de sección del inicio: pequeño, en mayúsculas y espaciado.
  Widget _tituloSeccion(String texto) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: AppEspaciado.sm + 4),
      child: Text(
        texto.toUpperCase(),
        style: const TextStyle(
          fontSize: 11.5,
          letterSpacing: 1.4,
          fontWeight: FontWeight.w700,
          color: AppColores.textoSecundario,
        ),
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

    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md + 2),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
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

  /// Accesos al módulo de Marketing y Comunicación (WhatsApp).
  Widget _buildMarketing() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _marketingTile(
              Icons.send_rounded,
              'Campañas',
              'Recordar pagos y recuperar clientes',
              AppColores.acento,
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const CampanasScreen())),
            ),
          ),
          const SizedBox(width: _espacioTarjetas),
          Expanded(
            child: _marketingTile(
              Icons.text_snippet_outlined,
              'Plantillas',
              'Mensajes de WhatsApp listos',
              AppColores.morado,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const PlantillasScreen()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _marketingTile(
    IconData icono,
    String titulo,
    String subtitulo,
    Color color, {
    VoidCallback? onTap,
  }) {
    final radio = BorderRadius.circular(AppEspaciado.radio);
    return Material(
      color: AppColores.superficie,
      borderRadius: radio,
      child: InkWell(
        onTap: onTap,
        borderRadius: radio,
        child: Ink(
          padding: const EdgeInsets.all(AppEspaciado.md),
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(color: AppColores.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    ),
                    child: Icon(icono, color: color, size: 20),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.arrow_outward_rounded,
                    size: 18,
                    color: AppColores.textoSecundario,
                  ),
                ],
              ),
              const SizedBox(height: AppEspaciado.md),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitulo,
                style: const TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsView() {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(AppEspaciado.md),
        children: [
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ajustes',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              CampanaAvisos(color: AppColores.primario),
            ],
          ),
          const SizedBox(height: AppEspaciado.lg),
          _ajusteTile(
            Icons.person_outline,
            'Mi perfil',
            'Datos de la cuenta',
            onTap: () => Navigator.of(context)
                .push(MaterialPageRoute(builder: (_) => const PerfilScreen())),
          ),
          if (_permisos.tiene(PermisosMovil.ajustesNegocio)) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            _ajusteTile(
              Icons.business_outlined,
              'Datos del negocio',
              'Nombre, logo y dirección',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DatosNegocioScreen()),
              ),
            ),
          ],
          if (_permisos.tiene(PermisosMovil.ajustesNegocio)) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            _ajusteTile(
              Icons.palette_outlined,
              'Colores de la app',
              'Plantillas con el estilo de tu gimnasio',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ColoresAppScreen()),
              ),
            ),
          ],
          if (_permisos.tiene(PermisosMovil.ajustesYape)) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            _ajusteTile(
              Icons.qr_code_2,
              'Pago por Yape',
              'Número y QR para que tus clientes paguen',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ConfigYapeScreen()),
              ),
            ),
          ],
          if (_permisos.tiene(PermisosMovil.lectorPagos)) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            _ajusteTile(
              Icons.qr_code_scanner,
              'Lector de pagos',
              'Registrar Yape/Plin automáticamente',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LectorPagosScreen()),
              ),
            ),
          ],
          // El buzón también vive en el encabezado de Inicio, pero un rol sin
          // `mobile_inicio` nunca ve esa pantalla: aquí siempre lo encuentra.
          if (_permisos.tiene(PermisosMovil.recomendaciones)) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            _ajusteTile(
              Icons.rate_review_outlined,
              'Recomendaciones recibidas',
              'Sugerencias de tus socios sobre el gimnasio y la app',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const RecomendacionesScreen(),
                ),
              ),
            ),
          ],
          // Sin permiso: cualquier perfil de la app puede dejar la suya.
          const SizedBox(height: AppEspaciado.sm + 4),
          _ajusteTile(
            Icons.lightbulb_outline,
            'Dejar una recomendación',
            'Envía tu sugerencia al administrador',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const EnviarRecomendacionScreen(),
              ),
            ),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          _ajusteTile(
            Icons.lock_outline,
            'Seguridad',
            'Contraseña y acceso',
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SeguridadScreen())),
          ),
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

  Widget _ajusteTile(
    IconData icono,
    String titulo,
    String subtitulo, {
    VoidCallback? onTap,
  }) {
    return TarjetaApp(
      onTap: onTap ?? () {},
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.md,
        vertical: AppEspaciado.sm + 4,
      ),
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
                  style: TextStyle(
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

/// Sección navegable de la barra inferior del admin. `builder` produce el
/// contenido (una pantalla con Scaffold propio, o el body ya envuelto).
class _SeccionAdmin {
  final IconData icono;
  final IconData iconoActivo;
  final String label;
  final Widget Function() builder;

  const _SeccionAdmin(this.icono, this.iconoActivo, this.label, this.builder);
}
