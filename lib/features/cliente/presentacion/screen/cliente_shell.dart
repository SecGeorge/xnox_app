import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/logo_gimnasio.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/inicio_cliente_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/membresia_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/qr_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/reporte_ejercicios_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/rutinas_screen.dart';
import 'package:xnox_app/features/ajustes/presentacion/screen/seguridad_screen.dart';
import 'package:xnox_app/features/tienda/presentacion/screen/comprar_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_foto_perfil.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/avatar_socio.dart';
import 'package:xnox_app/features/login/datos/repositorios/repositorio_auth_impl.dart';
import 'package:xnox_app/features/login/dominio/casos_de_uso/caso_uso_logout.dart';
import 'package:xnox_app/features/login/presentacion/screen/login_screen.dart';
import 'package:xnox_app/features/notificaciones/presentacion/controlador/controlador_notificaciones.dart';
import 'package:xnox_app/features/notificaciones/presentacion/screen/notificaciones_screen.dart';
import 'package:xnox_app/features/recomendaciones/presentacion/screen/enviar_recomendacion_screen.dart';

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
/// Arranca en el inicio y agrupa las secciones con una barra inferior con el
/// QR al centro. Membresía y Mi avance van en el menú "Más" (también se llega
/// desde los accesos del inicio) para no recargar la barra.
class ClienteShell extends StatefulWidget {
  const ClienteShell({super.key});

  @override
  State<ClienteShell> createState() => _ClienteShellState();
}

class _ClienteShellState extends State<ClienteShell> {
  int _selectedIndex = 0;
  final _logout = CasoUsoLogout(RepositorioAuthImpl(HttpService()));

  final _notificaciones = ControladorNotificaciones();

  /// Avisos sin leer del socio. La campana es la red de seguridad para cuando
  /// el push no llega (teléfono apagado, sin red, permiso denegado): el aviso
  /// sigue estando aquí. El backend solo devuelve los de los últimos 7 días.
  int _avisosPendientes = 0;

  @override
  void initState() {
    super.initState();
    _cargarAvisos();
    ControladorFotoPerfil.instancia.cargar();
  }

  Future<void> _cargarAvisos() async {
    try {
      final lista = await _notificaciones.obtener();
      if (!mounted) return;
      setState(() => _avisosPendientes = lista.length);
    } catch (_) {
      // Silencioso: que falle el contador no debe estorbar al resto de la app.
    }
  }

  /// Abre la lista de avisos y refresca el contador al volver, porque el socio
  /// pudo descartar alguno deslizándolo.
  Future<void> _abrirAvisos() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const NotificacionesScreen()));
    await _cargarAvisos();
  }

  /// Campanita con el número de avisos sin leer. Mismo tratamiento visual que
  /// la del dashboard del administrador.
  Widget _campanaAvisos() {
    return IconButton(
      onPressed: _abrirAvisos,
      tooltip: 'Avisos',
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(
            _avisosPendientes > 0
                ? Icons.notifications
                : Icons.notifications_none,
          ),
          if (_avisosPendientes > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: AppColores.moroso,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _avisosPendientes > 9 ? '9+' : '$_avisosPendientes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Índices de las secciones en el IndexedStack.
  static const _iInicio = 0;
  static const _iRutinas = 1;
  static const _iQr = 2;
  static const _iTienda = 3;
  static const _iMembresia = 4;
  static const _iReporte = 5;

  static const List<_SeccionNav> _secciones = [
    _SeccionNav(
      icono: Icons.home_outlined,
      iconoActivo: Icons.home_rounded,
      label: 'Inicio',
      // Se arma en build() (necesita el contador de avisos al día).
      pantalla: SizedBox.shrink(),
    ),
    _SeccionNav(
      icono: Icons.fitness_center_outlined,
      iconoActivo: Icons.fitness_center,
      label: 'Rutinas',
      pantalla: RutinasScreen(),
    ),
    _SeccionNav(
      icono: Icons.qr_code_2_outlined,
      iconoActivo: Icons.qr_code_2,
      label: 'Mi QR',
      pantalla: QrScreen(),
    ),
    _SeccionNav(
      icono: Icons.storefront_outlined,
      iconoActivo: Icons.storefront,
      label: 'Tienda',
      pantalla: ComprarScreen(),
    ),
    _SeccionNav(
      icono: Icons.card_membership_outlined,
      iconoActivo: Icons.card_membership,
      label: 'Membresía',
      pantalla: MembresiaScreen(),
    ),
    _SeccionNav(
      icono: Icons.insights_outlined,
      iconoActivo: Icons.insights,
      label: 'Mi avance',
      pantalla: ReporteEjerciciosScreen(),
    ),
  ];

  /// Secciones que se abren desde el menú "Más" (no van en la barra).
  static const _secundarias = [_iMembresia, _iReporte];

  bool get _enSeccionSecundaria => _secundarias.contains(_selectedIndex);

  /// Salto desde el inicio a otra sección.
  void _irA(DestinoCliente destino) {
    final indice = switch (destino) {
      DestinoCliente.rutinas => _iRutinas,
      DestinoCliente.qr => _iQr,
      DestinoCliente.tienda => _iTienda,
      DestinoCliente.membresia => _iMembresia,
      DestinoCliente.reporte => _iReporte,
    };
    setState(() => _selectedIndex = indice);
  }

  /// Abre el formulario de recomendaciones. Está en el AppBar, visible desde
  /// cualquier sección: si se escondiera en el menú "Más" casi nadie lo
  /// encontraría, y la idea es que el socio opine sin buscar.
  Future<void> _abrirRecomendacion() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const EnviarRecomendacionScreen()),
    );
  }

  /// Abre la pantalla de Seguridad para que el socio cambie su contraseña.
  /// Reutiliza la misma pantalla del administrador: opera sobre el usuario
  /// logueado, así que no requiere lógica extra en el backend.
  Future<void> _abrirSeguridad() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SeguridadScreen()));
  }

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

  /// Menú "Más": perfil del socio, accesos en tarjetas y cerrar sesión.
  Future<void> _abrirMenuMas() async {
    final prefs = await SharedPreferences.getInstance();
    final nombreCompleto = (prefs.getString('nombreCliente') ?? '').trim();
    final usuario = (prefs.getString('usuarioNombre') ?? '').trim();
    if (!mounted) return;
    final nombre = nombreCompleto
        .split(' ')
        .where((p) => p.isNotEmpty)
        .take(2)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');

    await mostrarHojaModerna<void>(
      context,
      builder: (ctx) {
        void ir(VoidCallback accion) {
          Navigator.pop(ctx);
          accion();
        }

        return HojaModerna(
          cabecera: AvatarSocio(tamano: 56, nombre: nombre, editable: true),
          titulo: nombre.isEmpty ? 'Mi cuenta' : nombre,
          subtitulo: usuario.isEmpty ? 'Socio' : 'Socio · $usuario',
          accion: IconButton(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(
              Icons.close_rounded,
              color: AppColores.textoSecundario,
            ),
          ),
          pie: SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              onPressed: () => ir(_cerrarSesion),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Accesos principales en tarjetas.
              Row(
                children: [
                  Expanded(
                    child: _tarjetaMas(
                      Icons.card_membership_rounded,
                      'Membresía',
                      'Plan y vencimiento',
                      activo: _selectedIndex == _iMembresia,
                      onTap: () => ir(
                        () => setState(() => _selectedIndex = _iMembresia),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppEspaciado.sm + 2),
                  Expanded(
                    child: _tarjetaMas(
                      Icons.insights_rounded,
                      'Mi avance',
                      'Pesos y marcas',
                      activo: _selectedIndex == _iReporte,
                      onTap: () =>
                          ir(() => setState(() => _selectedIndex = _iReporte)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppEspaciado.lg),
              const Text(
                'CUENTA Y AYUDA',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(height: AppEspaciado.sm),
              Container(
                decoration: BoxDecoration(
                  color: AppColores.fondo,
                  borderRadius: BorderRadius.circular(AppEspaciado.radio),
                ),
                child: Column(
                  children: [
                    _filaMas(
                      Icons.notifications_rounded,
                      'Avisos',
                      _avisosPendientes > 0
                          ? '$_avisosPendientes sin leer'
                          : 'Mensajes del gimnasio',
                      () => ir(_abrirAvisos),
                      contador: _avisosPendientes,
                    ),
                    Divider(height: 1, indent: 64, color: AppColores.borde),
                    _filaMas(
                      Icons.rate_review_rounded,
                      'Recomendaciones',
                      'Sugerencias para el gimnasio o la app',
                      () => ir(_abrirRecomendacion),
                    ),
                    Divider(height: 1, indent: 64, color: AppColores.borde),
                    _filaMas(
                      Icons.lock_rounded,
                      'Seguridad',
                      'Cambiar contraseña',
                      () => ir(_abrirSeguridad),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
            ],
          ),
        );
      },
    );
  }

  Widget _tarjetaMas(
    IconData icono,
    String titulo,
    String detalle, {
    required bool activo,
    required VoidCallback onTap,
  }) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: activo ? AppColores.degradadoRelleno : null,
            color: activo ? null : AppColores.fondo,
            border: activo
                ? AppColores.bordeCabecera
                : Border.all(color: AppColores.borde),
            borderRadius: radio,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: activo
                      ? AppColores.sobreRelleno.withValues(alpha: 0.15)
                      : AppColores.primario.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icono,
                  color: activo ? AppColores.sobreRelleno : AppColores.primario,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                titulo,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: activo
                      ? AppColores.sobreRelleno
                      : AppColores.textoPrincipal,
                ),
              ),
              Text(
                detalle,
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
      ),
    );
  }

  Widget _filaMas(
    IconData icono,
    String titulo,
    String detalle,
    VoidCallback onTap, {
    int contador = 0,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppEspaciado.radio),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColores.superficie,
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                border: Border.all(color: AppColores.borde),
              ),
              child: Icon(icono, size: 20, color: AppColores.primario),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  Text(
                    detalle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            if (contador > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(right: 4),
                decoration: BoxDecoration(
                  color: AppColores.moroso,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  contador > 9 ? '9+' : '$contador',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColores.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Inicio y Rutinas traen su propia cabecera.
    // Inicio, Rutinas y Tienda traen su propia cabecera.
    final enInicio =
        _selectedIndex == _iInicio ||
        _selectedIndex == _iRutinas ||
        _selectedIndex == _iTienda;
    return Scaffold(
      backgroundColor: AppColores.fondo,
      extendBody: true,
      // El inicio trae su propio saludo con la campana y el avatar.
      appBar: enInicio
          ? null
          : AppBar(
              titleSpacing: 12,
              title: Row(
                children: [
                  const LogoGimnasio(tamano: 34),
                  const SizedBox(width: AppEspaciado.sm + 2),
                  Expanded(child: Text(_secciones[_selectedIndex].label)),
                ],
              ),
              actions: [
                IconButton(
                  onPressed: _abrirRecomendacion,
                  icon: const Icon(Icons.rate_review_outlined),
                  tooltip: 'Dejar una recomendación',
                ),
                _campanaAvisos(),
              ],
            ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _secciones.length; i++)
            // Las secciones con la barra flotante encima necesitan aire abajo;
            // el inicio ya lo reserva en su propia lista.
            i == _iRutinas || i == _iTienda
                ? _secciones[i].pantalla
                : i == _iInicio
                ? InicioClienteScreen(
                    onIrA: _irA,
                    onAbrirAvisos: _abrirAvisos,
                    onAbrirMenu: _abrirMenuMas,
                    avisosPendientes: _avisosPendientes,
                  )
                : Padding(
                    padding: const EdgeInsets.only(bottom: 76),
                    child: _secciones[i].pantalla,
                  ),
        ],
      ),
      bottomNavigationBar: _barraInferior(),
    );
  }

  /// Barra inferior con el QR de ingreso en el centro, resaltado: es lo que
  /// el socio abre en la puerta del gimnasio.
  Widget _barraInferior() {
    Widget item(int indice) {
      final s = _secciones[indice];
      final activo = _selectedIndex == indice;
      return Expanded(
        child: InkResponse(
          onTap: () => setState(() => _selectedIndex = indice),
          radius: 32,
          child: _itemBarra(activo ? s.iconoActivo : s.icono, s.label, activo),
        ),
      );
    }

    final masActivo = _enSeccionSecundaria;
    final qrActivo = _selectedIndex == _iQr;
    return SafeArea(
      top: false,
      child: SizedBox(
        height: 76,
        child: Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Container(
              height: 66,
              decoration: BoxDecoration(
                color: AppColores.superficie,
                border: Border(top: BorderSide(color: AppColores.borde)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  item(_iInicio),
                  item(_iRutinas),
                  const Expanded(child: SizedBox()),
                  item(_iTienda),
                  Expanded(
                    child: InkResponse(
                      onTap: _abrirMenuMas,
                      radius: 32,
                      child: _itemBarra(
                        masActivo
                            ? _secciones[_selectedIndex].iconoActivo
                            : Icons.menu_rounded,
                        masActivo ? _secciones[_selectedIndex].label : 'Más',
                        masActivo,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: -14,
              child: GestureDetector(
                onTap: () => setState(() => _selectedIndex = _iQr),
                child: Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    gradient: AppColores.degradadoRelleno,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColores.bordeRelleno ?? AppColores.superficie,
                      width: AppColores.bordeRelleno != null ? 2 : 5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColores.primario.withValues(alpha: 0.35),
                        blurRadius: qrActivo ? 20 : 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.qr_code_2_rounded,
                    size: 32,
                    color: AppColores.sobreRelleno,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _itemBarra(IconData icono, String texto, bool activo) {
    final color = activo ? AppColores.primario : AppColores.textoSecundario;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icono, color: color, size: 25),
        const SizedBox(height: 3),
        Text(
          texto,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: activo ? FontWeight.w700 : FontWeight.w500,
            color: color,
          ),
        ),
      ],
    );
  }
}
