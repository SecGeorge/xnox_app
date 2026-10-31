import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/fondo_xnet.dart';
import 'package:xnox_app/core/widgets/tarjeta_giratoria.dart';
import 'package:xnox_app/features/clases/datos/repositorio_clases.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';
import 'package:xnox_app/features/clases/presentacion/screen/clases_screen.dart';
import 'package:xnox_app/features/entrenamiento_funcional/presentacion/screen/ejecutar_rutina_screen.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/asistencia_cliente.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_asistencias.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_membresia.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/asistencias_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_publicidad_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/dia_rutina_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/avatar_socio.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/banners_inicio.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/cabecera_inicio.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/foto_sesion.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/modal_vencimiento.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/tienda/presentacion/controlador/controlador_tienda.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';

/// Secciones del cliente a las que se puede saltar desde el inicio.
enum DestinoCliente { rutinas, qr, tienda, membresia, reporte, nutricion, clases }

/// Inicio del socio: saludo con su racha, la rutina que le toca hoy, accesos
/// a las secciones del gimnasio, su progreso y las novedades.
///
/// Las fotos son fijas (assets), pero todo lo que pinta encima sale de la
/// paleta del gimnasio: cada gimnasio la ve con sus colores.
class InicioClienteScreen extends StatefulWidget {
  final void Function(DestinoCliente destino) onIrA;
  final VoidCallback onAbrirAvisos;
  final VoidCallback onAbrirMenu;
  final int avisosPendientes;

  /// Si es la sección a la vista. El inicio sigue montado detrás de las otras
  /// pestañas, y ahí las tarjetas y los banners no deben animarse.
  final bool activa;

  const InicioClienteScreen({
    super.key,
    required this.onIrA,
    required this.onAbrirAvisos,
    required this.onAbrirMenu,
    required this.avisosPendientes,
    required this.activa,
  });

  @override
  State<InicioClienteScreen> createState() => _InicioClienteScreenState();
}

class _InicioClienteScreenState extends State<InicioClienteScreen> {
  static const _fotos = 'assets/imagenes/inicio';

  final _rutinas = ControladorRutinas();
  final _asistencias = ControladorAsistencias();
  final _membresia = ControladorMembresia();
  final _promociones = ControladorPromociones();
  final _clases = RepositorioClases();
  final _tienda = ControladorTienda();
  final _novedadesKey = GlobalKey<ClientePublicidadScreenState>();

  String _nombre = '';
  List<AsistenciaCliente> _listaAsistencias = [];
  MembresiaCliente? _contrato;
  int? _puntos;
  int _novedades = 0;
  List<SesionClase> _clasesBanner = const [];
  List<ProductoTienda> _productosBanner = const [];

  /// El modal de novedades ya se cerró (o no había): recién entonces puede
  /// salir el aviso de vencimiento.
  bool _novedadesListas = false;
  _RutinaDeHoy? _hoy;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      // Solo el primer nombre, y con mayúscula inicial: el backend suele
      // guardarlo todo en mayúsculas ("JACK" -> "Jack").
      final primero = (prefs.getString('nombreCliente') ?? '')
          .trim()
          .split(' ')
          .first;
      setState(
        () => _nombre = primero.isEmpty
            ? ''
            : primero[0].toUpperCase() + primero.substring(1).toLowerCase(),
      );
    }
    // Cada bloque se carga por su lado: si uno falla (sin red), el resto del
    // inicio se ve igual.
    await Future.wait([
      _cargarRutinaDeHoy(),
      _cargarAsistencias(),
      _cargarMembresia(),
      _cargarPuntos(),
      _cargarClases(),
      _cargarProductos(),
    ]);
  }

  Future<void> _recargar() async {
    await Future.wait([
      _cargar(),
      _novedadesKey.currentState?.recargar() ?? Future.value(),
    ]);
  }

  Future<void> _cargarRutinaDeHoy() async {
    try {
      await _rutinas.asegurarCargado();
      if (mounted) setState(() => _hoy = _buscarRutinaDeHoy());
      // Las sugeridas del gimnasio pueden haber cambiado: sincroniza y vuelve
      // a buscar (sin red, se queda con lo del SQLite).
      await _rutinas.sincronizar();
    } catch (_) {
      /* sin red */
    }
    if (mounted) setState(() => _hoy = _buscarRutinaDeHoy());
  }

  Future<void> _cargarAsistencias() async {
    final lista = await _asistencias.obtenerAsistencias();
    if (mounted) setState(() => _listaAsistencias = lista);
  }

  /// Se completa cuando terminó la primera carga de la membresía (con o sin
  /// red), para encadenar los avisos del arranque sin que se encimen.
  final _membresiaCargada = Completer<void>();

  Future<void> _cargarMembresia() async {
    try {
      final m = await _membresia.obtenerMembresia();
      if (mounted) setState(() => _contrato = m);
    } catch (_) {
      /* sin red */
    } finally {
      if (!_membresiaCargada.isCompleted) _membresiaCargada.complete();
    }
  }

  /// Avisos del arranque, uno detrás de otro: novedades (ya cerradas al
  /// llegar aquí) → vencimiento de la membresía → foto de perfil si falta.
  Future<void> _avisosDeArranque() async {
    await _membresiaCargada.future;
    await _intentarAvisoVencimiento();
    if (mounted) await pedirFotoSiFalta(context);
  }

  bool _vencimientoAvisado = false;

  /// Avisa al socio al que le quedan 7 días o menos, después de las novedades.
  Future<void> _intentarAvisoVencimiento() async {
    final m = _contrato;
    if (!_novedadesListas || m == null || _vencimientoAvisado) return;
    if (!debeAvisarVencimiento(m) || !mounted) return;
    _vencimientoAvisado = true;
    await mostrarAvisoVencimiento(
      context,
      membresia: m,
      novedades: _novedadesKey.currentState?.novedades ?? const [],
      onRenovar: () => widget.onIrA(DestinoCliente.membresia),
      onVerNovedades: () => _novedadesKey.currentState?.mostrarNovedades(),
    );
  }

  Future<void> _cargarPuntos() async {
    try {
      final r = await _promociones.obtenerResumen();
      if (mounted) setState(() => _puntos = r.saldo);
    } catch (_) {
      /* sin red */
    }
  }

  Future<void> _cargarClases() async {
    try {
      final sesiones = await _clases.agenda(dias: 7);
      if (mounted) {
        setState(
          () => _clasesBanner = clasesParaBanner(sesiones, DateTime.now()),
        );
      }
    } catch (_) {
      /* sin red, o el gimnasio no tiene clases: no sale el banner */
    }
  }

  Future<void> _cargarProductos() async {
    try {
      final catalogo = await _tienda.obtenerCatalogo();
      if (mounted) {
        setState(
          () => _productosBanner = productosParaBanner(catalogo.productos),
        );
      }
    } catch (_) {
      /* sin red, o la sucursal no tiene almacén: no sale el banner */
    }
  }

  /// Al volver puede haber reservado o cancelado: el banner muestra sus cupos.
  Future<void> _abrirClases() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const ClasesScreen()),
    );
    if (mounted) await _cargarClases();
  }

  // ------------------------------------------------------------- Cálculos

  static const _diasSemana = [
    'lunes',
    'martes',
    'miercoles',
    'jueves',
    'viernes',
    'sabado',
    'domingo',
  ];

  static String _normalizar(String t) => t
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  /// El día de rutina que toca hoy: de la rutina elegida o, si no eligió,
  /// primero las que armó el gimnasio para el socio, luego las suyas y por
  /// último las sugeridas.
  _RutinaDeHoy? _buscarRutinaDeHoy() {
    final hoy = _diasSemana[DateTime.now().weekday - 1];
    final candidatas = _rutinas.obtenerParaEntrenar();
    for (final r in candidatas) {
      for (final d in r.dias) {
        if (_normalizar(d.diaSemana) == hoy && d.ejercicios.isNotEmpty) {
          return _RutinaDeHoy(r, d);
        }
      }
    }
    return null;
  }

  /// Días seguidos con asistencia, contando hasta hoy (o hasta ayer si hoy
  /// aún no vino: la racha no se rompe hasta que pasa el día).
  int get _racha {
    final dias = _listaAsistencias.map((a) => a.claveDia).toSet();
    var dia = DateTime.now();
    String clave(DateTime d) =>
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    if (!dias.contains(clave(dia))) {
      dia = dia.subtract(const Duration(days: 1));
    }
    var racha = 0;
    while (dias.contains(clave(dia))) {
      racha++;
      dia = dia.subtract(const Duration(days: 1));
    }
    return racha;
  }

  int get _entrenamientosMes {
    final hoy = DateTime.now();
    return _listaAsistencias
        .where((a) => a.fecha.year == hoy.year && a.fecha.month == hoy.month)
        .map((a) => a.claveDia)
        .toSet()
        .length;
  }

  // ---------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _recargar,
        // SingleChildScrollView y no ListView: la lista perezosa no construía
        // las novedades (están al final) hasta bajar, y el modal de novedades
        // no salía al abrir la app.
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(
            AppEspaciado.md,
            AppEspaciado.md,
            AppEspaciado.md,
            110,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _cabecera(),
              const SizedBox(height: AppEspaciado.lg),
              // Llega después que el resto: que abra sin empujar de golpe.
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                alignment: Alignment.topCenter,
                child: _clasesBanner.isEmpty
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.only(
                          bottom: AppEspaciado.lg,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _tituloSeccion(
                              Icons.groups_rounded,
                              'Próximas clases',
                              accion: 'Ver todas',
                              onAccion: _abrirClases,
                            ),
                            BannersClases(
                              sesiones: _clasesBanner,
                              activo: widget.activa,
                              onTap: _abrirClases,
                            ),
                          ],
                        ),
                      ),
              ),
              _tarjetaRutinaDeHoy(),
              const SizedBox(height: AppEspaciado.lg + 4),
              _tituloSeccion(Icons.fitness_center_rounded, 'Tu gimnasio'),
              _accesos(),
              const SizedBox(height: AppEspaciado.lg + 4),
              if (_productosBanner.isNotEmpty) ...[
                _tituloSeccion(
                  Icons.shopping_bag_rounded,
                  'Productos del gimnasio',
                  accion: 'Ver tienda',
                  onAccion: () => widget.onIrA(DestinoCliente.tienda),
                ),
                BannersProductos(
                  productos: _productosBanner,
                  activo: widget.activa,
                  onTap: () => widget.onIrA(DestinoCliente.tienda),
                ),
                const SizedBox(height: AppEspaciado.lg + 4),
              ],
              _tituloSeccion(
                Icons.bar_chart_rounded,
                'Tu progreso',
                accion: 'Ver más',
                onAccion: () => widget.onIrA(DestinoCliente.reporte),
              ),
              _progreso(),
              const SizedBox(height: AppEspaciado.lg),
              _bannerMotivacion(),
              const SizedBox(height: AppEspaciado.lg + 4),
              ClientePublicidadScreen(
                key: _novedadesKey,
                incrustada: true,
                onNovedades: (n) {
                  if (mounted && n != _novedades) {
                    setState(() => _novedades = n);
                  }
                },
                onListo: () {
                  _novedadesListas = true;
                  _avisosDeArranque();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Entra deslizándose una sola vez: al recargar datos no se repite.
  Widget _cabecera() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (_, valor, hijo) => Opacity(
        opacity: valor,
        child: Transform.translate(
          offset: Offset(0, (1 - valor) * 14),
          child: hijo,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _saludo(),
          const SizedBox(height: AppEspaciado.md - 2),
          FranjaMensajes(
            mensajes: _mensajesCabecera,
            activa: widget.activa,
          ),
        ],
      ),
    );
  }

  void _abrirAsistencias() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AsistenciasScreen()));
  }

  /// Lo que dice la franja, según los datos que ya llegaron. La membresía
  /// que está por vencer va primero; la que no, al final.
  List<MensajeCabecera> get _mensajesCabecera {
    final racha = _racha;
    final entrenos = _entrenamientosMes;
    final puntos = _puntos ?? 0;
    final dias = _contrato?.diasRestantes;
    final reservada = _clasesBanner.where((s) => s.reservada).firstOrNull;

    void irAMembresia() => widget.onIrA(DestinoCliente.membresia);
    final porVencer = dias != null && dias <= 7;
    return [
      if (porVencer)
        MensajeCabecera(
          '⏳',
          dias < 0
              ? 'Tu membresía venció, renuévala'
              : dias == 0
              ? 'Tu membresía vence hoy'
              : dias == 1
              ? 'Te queda 1 día de membresía'
              : 'Te quedan $dias días de membresía',
          irAMembresia,
        ),
      MensajeCabecera(
        racha > 0 ? '🔥' : '💪',
        racha > 1
            ? '$racha días seguidos entrenando'
            : racha == 1
            ? '1 día de racha, ¡sigue así!'
            : 'Hoy es un buen día para entrenar',
        _abrirAsistencias,
      ),
      if (reservada != null)
        MensajeCabecera(
          '🎟️',
          'Tienes tu cupo en ${reservada.nombre}',
          _abrirClases,
        ),
      if (entrenos > 0)
        MensajeCabecera(
          '🏋️',
          entrenos == 1 ? '1 entreno este mes' : '$entrenos entrenos este mes',
          _abrirAsistencias,
        ),
      if (puntos > 0)
        MensajeCabecera(
          '⭐',
          puntos == 1 ? '1 punto para canjear' : '$puntos puntos para canjear',
          () => widget.onIrA(DestinoCliente.tienda),
        ),
      if (dias != null && !porVencer)
        MensajeCabecera('🎫', 'Membresía activa: $dias días', irAMembresia),
    ];
  }

  Widget _saludo() {
    return Row(
      children: [
        // Avatar con la foto (o la inicial): abre el menú de cuenta (membresía, seguridad,
        // cerrar sesión...).
        AvatarSocio(tamano: 54, nombre: _nombre, onTap: widget.onAbrirMenu),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                saludoPorHora(DateTime.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: AppColores.textoSecundario,
                ),
              ),
              Text(
                _nombre.isEmpty ? '¡Bienvenido!' : _nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ],
          ),
        ),
        if (_novedades > 0) ...[
          const SizedBox(width: AppEspaciado.sm),
          _botonRedondo(
            onTap: () => _novedadesKey.currentState?.mostrarNovedades(),
            child: Badge(
              label: Text('$_novedades'),
              backgroundColor: AppColores.naranja,
              child: Icon(Icons.campaign_rounded, color: AppColores.primario),
            ),
          ),
        ],
        const SizedBox(width: AppEspaciado.sm),
        _botonRedondo(
          onTap: widget.onAbrirAvisos,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(
                widget.avisosPendientes > 0
                    ? Icons.notifications_rounded
                    : Icons.notifications_none_rounded,
                color: AppColores.primario,
              ),
              if (widget.avisosPendientes > 0)
                Positioned(
                  right: -3,
                  top: -3,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppColores.moroso,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColores.superficie,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _botonRedondo({required Widget child, required VoidCallback onTap}) {
    return Material(
      color: AppColores.superficie,
      shape: CircleBorder(side: BorderSide(color: AppColores.borde)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 42, height: 42, child: Center(child: child)),
      ),
    );
  }

  // --------------------------------------------------------- Rutina de hoy

  /// Rectángulo con lo que toca hoy: toda la tarjeta abre la rutina.
  Widget _tarjetaRutinaDeHoy() {
    final hoy = _hoy;
    final total = hoy?.dia.totalEjercicios ?? 0;
    final hechos = hoy?.completados ?? 0;
    final terminado = hoy != null && total > 0 && hechos >= total;

    final String titulo;
    final String detalle;
    if (hoy == null) {
      titulo = 'Hoy toca descanso';
      detalle = 'Elige o arma una rutina';
    } else if (terminado) {
      titulo = '¡Gran trabajo hoy!';
      detalle = 'Completaste tu entrenamiento';
    } else {
      titulo = FotoSesion.titulo(hoy.rutina, hoy.dia);
      detalle = hechos > 0
          ? 'Te faltan ${total - hechos} de $total ejercicios'
          : '$total ejercicios te esperan hoy';
    }

    // Foto según lo que toca hoy (piernas, espalda...) o la de descanso.
    final foto = hoy == null
        ? FotoSesion.descanso
        : FotoSesion.para(hoy.rutina, hoy.dia);
    return FotoTarjeta(
      foto: foto.ruta,
      alineacion: foto.alineacion,
      radio: AppEspaciado.radio + 2,
      degradadoHorizontal: true,
      onTap: _abrirRutinaDeHoy,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md,
          vertical: AppEspaciado.md - 2,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hoy == null
                        ? 'RUTINA DE HOY'
                        : 'RUTINA DE HOY · ${hoy.dia.diaSemana.toUpperCase()}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    titulo.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tituloXnet.copyWith(fontSize: 20),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                  if (hoy != null) ...[
                    const SizedBox(height: AppEspaciado.sm + 2),
                    _progresoEjercicios(hechos, total),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppEspaciado.md),
            _circuloFoto(
              terminado
                  ? Icons.check_rounded
                  : hoy == null
                  ? Icons.chevron_right_rounded
                  : Icons.play_arrow_rounded,
              tamano: 52,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _abrirRutinaDeHoy() async {
    final hoy = _hoy;
    if (hoy == null) {
      widget.onIrA(DestinoCliente.rutinas);
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(
        // Circuitos, HIIT, EMOM...: la sesión va con temporizador.
        builder: (_) => hoy.rutina.dias.any(
              (d) => d.diaSemana == hoy.dia.diaSemana && d.esFuncional,
            )
            ? EjecutarRutinaScreen(
                plan: hoy.rutina.plan,
                dia: hoy.dia.diaSemana,
              )
            : DiaRutinaScreen(rutinaId: hoy.rutina.id, diaId: hoy.dia.id),
      ),
    );
    // Al volver puede haber registrado series: recalcula.
    if (mounted) setState(() => _hoy = _buscarRutinaDeHoy());
  }

  /// Un segmento por ejercicio, como en las apps de entrenamiento.
  Widget _progresoEjercicios(int hechos, int total) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 3),
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              decoration: BoxDecoration(
                color: i < hechos
                    ? _rellenoFoto
                    : Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
        ],
      ],
    );
  }

  /// Texto sobre [AppColores.destacado]: oscuro si el destacado es claro.
  Color get _tintaSobreDestacado =>
      AppColores.destacado.computeLuminance() > 0.45
      ? const Color(0xFF0E1A12)
      : Colors.white;

  // -------------------------------------------------------------- Accesos

  Widget _tituloSeccion(
    IconData icono,
    String titulo, {
    String? accion,
    VoidCallback? onAccion,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: Row(
        children: [
          Icon(icono, color: AppColores.primario, size: 24),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          if (accion != null)
            InkWell(
              onTap: onAccion,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  children: [
                    Text(
                      accion,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColores.primario,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColores.primario,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _accesos() {
    final contrato = _contrato;
    final accesos = [
      _Acceso(
        'Rutinas',
        'Entrena con tu plan personalizado',
        Icons.fitness_center_rounded,
        '$_fotos/rutinas.jpg',
        'Ver rutinas',
        () => widget.onIrA(DestinoCliente.rutinas),
      ),
      _Acceso(
        'Membresía',
        contrato == null
            ? 'Tu plan y vencimiento'
            : contrato.diasRestantes >= 0
            ? '${contrato.plan} · ${contrato.diasRestantes} días'
            : 'Vencida · renueva tu plan',
        Icons.card_membership_rounded,
        '$_fotos/membresia.jpg',
        'Ver mi plan',
        () => widget.onIrA(DestinoCliente.membresia),
      ),
      _Acceso(
        'Tienda',
        'Suplementos y más',
        Icons.shopping_bag_rounded,
        '$_fotos/tienda.jpg',
        'Ir a la tienda',
        () => widget.onIrA(DestinoCliente.tienda),
      ),
      _Acceso(
        'Mi avance',
        'Marcas y medidas de tu cuerpo',
        Icons.insights_rounded,
        '$_fotos/progreso.jpg',
        'Ver mi avance',
        () => widget.onIrA(DestinoCliente.reporte),
      ),
      _Acceso(
        'Nutrición',
        'Lo que comes, tus metas y tu plan',
        Icons.restaurant_rounded,
        'assets/imagenes/nutricion/plato.jpg',
        'Ver mi plan',
        () => widget.onIrA(DestinoCliente.nutricion),
      ),
      _Acceso(
        'Reservas',
        'Clases, masajes y nutricionista',
        Icons.event_available_rounded,
        '$_fotos/motivacion.jpg',
        'Reservar',
        () => widget.onIrA(DestinoCliente.clases),
      ),
    ];
    return CuadriculaGiratoria(
      alto: 150,
      separacion: AppEspaciado.sm + 4,
      activa: widget.activa,
      tarjetas: [
        for (final a in accesos)
          CarasTarjeta(frente: _frenteAcceso(a), reverso: _reversoAcceso(a)),
      ],
    );
  }

  /// Relleno de la marca para los elementos sobre foto (en XNET, blanco).
  Color get _rellenoFoto => AppColores.bordeRelleno != null
      ? AppColores.relleno
      : AppColores.destacado;

  Color get _tintaRellenoFoto => AppColores.bordeRelleno != null
      ? AppColores.sobreRelleno
      : _tintaSobreDestacado;

  Widget _circuloFoto(IconData icono, {double tamano = 42}) {
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: _rellenoFoto,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
          ),
        ],
      ),
      child: Icon(icono, size: tamano / 2, color: _tintaRellenoFoto),
    );
  }

  Widget _frenteAcceso(_Acceso a) {
    return FotoTarjeta(
      foto: a.foto,
      radio: AppEspaciado.radio + 2,
      onTap: a.onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _circuloFoto(a.icono),
            const Spacer(),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        a.titulo.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tituloXnet.copyWith(fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        a.subtitulo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.5,
                          height: 1.25,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Reverso al estilo XNET: fondo negro y lo que se puede hacer ahí.
  Widget _reversoAcceso(_Acceso a) {
    return FondoXnet(
      radio: AppEspaciado.radio + 2,
      onTap: a.onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _circuloFoto(a.icono),
            const Spacer(),
            Text(
              a.titulo.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tituloXnet.copyWith(fontSize: 18),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Flexible(
                  child: Text(
                    a.accion,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 18,
                  color: Colors.white.withValues(alpha: 0.8),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------- Progreso

  Widget _progreso() {
    final contrato = _contrato;
    final dias = contrato?.diasRestantes;
    // Cuánto queda del plan actual, para el anillo de la membresía.
    double restante = 0;
    if (contrato != null) {
      final totalPlan = contrato.fechaVencimiento
          .difference(contrato.fechaInicio)
          .inDays
          .clamp(1, 100000);
      restante = ((dias ?? 0) / totalPlan).clamp(0.0, 1.0);
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppEspaciado.md + 2,
        horizontal: AppEspaciado.sm,
      ),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
        border: Border.all(color: AppColores.borde),
        boxShadow: AppSombras.tarjeta,
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Expanded(
              child: _datoProgreso(
                emoji: '🔥',
                titulo: 'Entrenos',
                valor: '$_entrenamientosMes',
                pie: 'este mes',
              ),
            ),
            _separador(),
            Expanded(
              child: _datoProgreso(
                emoji: '⭐',
                titulo: 'Puntos',
                valor: _puntos == null ? '--' : '$_puntos',
                pie: 'para canjear',
              ),
            ),
            _separador(),
            Expanded(
              child: Column(
                children: [
                  const Text(
                    'Membresía',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: 50,
                    height: 50,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CircularProgressIndicator(
                          value: restante,
                          strokeWidth: 5,
                          strokeCap: StrokeCap.round,
                          color: (dias ?? 0) <= 5
                              ? AppColores.naranja
                              : AppColores.primario,
                          backgroundColor: AppColores.primario.withValues(
                            alpha: 0.10,
                          ),
                        ),
                        Center(
                          child: Text(
                            dias == null ? '--' : '${dias < 0 ? 0 : dias}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: AppColores.textoPrincipal,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'días restantes',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _separador() => Container(
    width: 1,
    margin: const EdgeInsets.symmetric(vertical: 4),
    color: AppColores.borde,
  );

  Widget _datoProgreso({
    required String emoji,
    required String titulo,
    required String valor,
    required String pie,
  }) {
    return Column(
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColores.textoSecundario,
          ),
        ),
        const SizedBox(height: 8),
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(height: 2),
        Text(
          valor,
          style: TextStyle(
            fontSize: 24,
            height: 1.1,
            fontWeight: FontWeight.w800,
            color: AppColores.textoPrincipal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          pie,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _bannerMotivacion() {
    return SizedBox(
      height: 132,
      child: FotoTarjeta(
        foto: '$_fotos/motivacion.jpg',
        alineacion: const Alignment(0.3, -0.2),
        radio: AppEspaciado.radio + 2,
        degradadoHorizontal: true,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppEspaciado.md + 4,
            vertical: AppEspaciado.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'DISCIPLINA\nHOY, '),
                    TextSpan(
                      text: 'RESULTADOS',
                      style: TextStyle(color: AppColores.destacado),
                    ),
                    const TextSpan(text: '\nMAÑANA'),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 21,
                  height: 1.12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.4,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 10),
              Container(
                width: 34,
                height: 3,
                decoration: BoxDecoration(
                  color: AppColores.destacado,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Rutina y día que le tocan hoy al socio.
class _RutinaDeHoy {
  final Rutina rutina;
  final DiaRutina dia;

  _RutinaDeHoy(this.rutina, this.dia);

  /// Ejercicios del día con alguna serie registrada hoy.
  int get completados =>
      dia.ejercicios.where((e) => e.marcas.any((m) => m.esHoy)).length;
}

class _Acceso {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String foto;

  /// Lo que dice el reverso de la tarjeta.
  final String accion;
  final VoidCallback onTap;

  _Acceso(
    this.titulo,
    this.subtitulo,
    this.icono,
    this.foto,
    this.accion,
    this.onTap,
  );
}
