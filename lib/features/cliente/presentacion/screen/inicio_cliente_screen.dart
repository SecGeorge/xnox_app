import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
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
import 'package:xnox_app/features/cliente/presentacion/widget/foto_sesion.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/modal_vencimiento.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';

/// Secciones del cliente a las que se puede saltar desde el inicio.
enum DestinoCliente { rutinas, qr, tienda, membresia, reporte }

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

  const InicioClienteScreen({
    super.key,
    required this.onIrA,
    required this.onAbrirAvisos,
    required this.onAbrirMenu,
    required this.avisosPendientes,
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
  final _novedadesKey = GlobalKey<ClientePublicidadScreenState>();

  String _nombre = '';
  List<AsistenciaCliente> _listaAsistencias = [];
  MembresiaCliente? _contrato;
  int? _puntos;
  int _novedades = 0;

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

  /// El día de rutina que toca hoy: primero las que armó el gimnasio para el
  /// socio, luego las suyas y por último las sugeridas.
  _RutinaDeHoy? _buscarRutinaDeHoy() {
    final hoy = _diasSemana[DateTime.now().weekday - 1];
    final candidatas = [
      ..._rutinas.obtenerAsignadas(),
      ..._rutinas.obtenerMisRutinas(),
      ..._rutinas.obtenerSugeridas(),
    ];
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
              _tarjetaRutinaDeHoy(),
              const SizedBox(height: AppEspaciado.lg + 4),
              _tituloSeccion(Icons.fitness_center_rounded, 'Tu gimnasio'),
              _accesos(),
              const SizedBox(height: AppEspaciado.lg + 4),
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

  Widget _cabecera() {
    final racha = _racha;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _saludo(),
        const SizedBox(height: AppEspaciado.sm + 2),
        _filaRacha(racha),
      ],
    );
  }

  Widget _filaRacha(int racha) {
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: () => Navigator.of(context)
          .push(MaterialPageRoute(builder: (_) => const AsistenciasScreen())),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(racha > 0 ? '🔥' : '💪', style: const TextStyle(fontSize: 17)),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                racha > 1
                    ? '$racha días seguidos entrenando'
                    : racha == 1
                    ? '1 día de racha, ¡sigue así!'
                    : 'Hoy es un buen día para entrenar',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ),
            const SizedBox(width: 2),
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColores.textoSecundario,
            ),
          ],
        ),
      ),
    );
  }

  Widget _saludo() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(text: 'Hola'),
                    if (_nombre.isNotEmpty) ...[
                      const TextSpan(text: ', '),
                      TextSpan(
                        text: _nombre,
                        style: TextStyle(color: AppColores.primario),
                      ),
                    ],
                    const TextSpan(text: ' 👋'),
                  ],
                ),
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
              const SizedBox(height: 4),
              const Text(
                '¡Qué bueno verte de nuevo!',
                style: TextStyle(
                  fontSize: 14.5,
                  color: AppColores.textoSecundario,
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
        const SizedBox(width: AppEspaciado.sm),
        // Avatar con la foto (o la inicial): abre el menú de cuenta (membresía, seguridad,
        // cerrar sesión...).
        AvatarSocio(nombre: _nombre, onTap: widget.onAbrirMenu),
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
        child: SizedBox(width: 46, height: 46, child: Center(child: child)),
      ),
    );
  }

  // --------------------------------------------------------- Rutina de hoy

  Widget _tarjetaRutinaDeHoy() {
    final hoy = _hoy;
    final total = hoy?.dia.totalEjercicios ?? 0;
    final hechos = hoy?.completados ?? 0;
    final terminado = hoy != null && total > 0 && hechos >= total;

    final String titulo;
    final String detalle;
    if (hoy == null) {
      titulo = 'Hoy toca descanso';
      detalle = 'No tienes ejercicios para hoy. Elige o arma una rutina.';
    } else if (terminado) {
      titulo = '¡Gran trabajo hoy!';
      detalle = 'Completaste tu entrenamiento. Mantén la disciplina.';
    } else if (hechos > 0) {
      titulo = '¡Vas muy bien!';
      detalle =
          'Te faltan ${total - hechos} de $total ejercicios de '
          '${FotoSesion.titulo(hoy.rutina, hoy.dia)}.';
    } else {
      titulo = FotoSesion.titulo(hoy.rutina, hoy.dia);
      detalle = '$total ejercicios te esperan hoy. ¡A darle!';
    }

    // Foto según lo que toca hoy (piernas, espalda...) o la de descanso.
    final foto = hoy == null
        ? FotoSesion.descanso
        : FotoSesion.para(hoy.rutina, hoy.dia);
    return FotoTarjeta(
      foto: foto.ruta,
      alineacion: foto.alineacion,
      radio: AppEspaciado.radio + 8,
      degradadoHorizontal: true,
      child: Padding(
        padding: const EdgeInsets.all(AppEspaciado.md + 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _chipFoto(
              terminado ? Icons.check_circle_rounded : Icons.today_rounded,
              hoy == null
                  ? 'RUTINA DE HOY'
                  : 'RUTINA DE HOY · ${hoy.dia.diaSemana.toUpperCase()}',
            ),
            const SizedBox(height: AppEspaciado.md),
            SizedBox(
              width: 240,
              child: Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 230,
              child: Text(
                detalle,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(height: AppEspaciado.md + 4),
            if (hoy != null) ...[
              _progresoEjercicios(hechos, total),
              const SizedBox(height: AppEspaciado.md),
            ],
            _botonFoto(
              terminado
                  ? 'Ver rutina completada'
                  : hoy == null
                  ? 'Ver mis rutinas'
                  : hechos > 0
                  ? 'Continuar rutina'
                  : 'Empezar rutina',
              icono: terminado ? Icons.check_rounded : Icons.play_arrow_rounded,
              onTap: () async {
                if (hoy == null) {
                  widget.onIrA(DestinoCliente.rutinas);
                  return;
                }
                await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => DiaRutinaScreen(
                      rutinaId: hoy.rutina.id,
                      diaId: hoy.dia.id,
                    ),
                  ),
                );
                // Al volver puede haber registrado series: recalcula.
                if (mounted) setState(() => _hoy = _buscarRutinaDeHoy());
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _progresoEjercicios(int hechos, int total) {
    final porcentaje = total == 0 ? 0 : (hechos / total * 100).round();
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$hechos / $total',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const TextSpan(text: ' ejercicios completados'),
                  ],
                ),
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
              const Spacer(),
              Text(
                '$porcentaje%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColores.destacado,
                ),
              ),
            ],
          ),
          const SizedBox(height: 9),
          // Un segmento por ejercicio, como en las apps de entrenamiento.
          Row(
            children: [
              for (var i = 0; i < total; i++) ...[
                if (i > 0) const SizedBox(width: 4),
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 6,
                    decoration: BoxDecoration(
                      color: i < hechos
                          ? AppColores.destacado
                          : Colors.white.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipFoto(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColores.destacado.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 18, color: AppColores.destacado),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: AppColores.destacado,
            ),
          ),
        ],
      ),
    );
  }

  /// Botón principal sobre foto: el relleno de la marca, así cada gimnasio lo
  /// ve con su color (en XNOX-SOFT, blanco con texto azul marino).
  Widget _botonFoto(
    String texto, {
    required IconData icono,
    required VoidCallback onTap,
  }) {
    final radio = BorderRadius.circular(AppEspaciado.radioSm);
    final claro = AppColores.bordeRelleno != null;
    return Material(
      color: claro ? AppColores.relleno : AppColores.destacado,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: SizedBox(
          height: 50,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icono,
                size: 20,
                color: claro ? AppColores.sobreRelleno : _tintaSobreDestacado,
              ),
              const SizedBox(width: 8),
              Text(
                texto,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: claro ? AppColores.sobreRelleno : _tintaSobreDestacado,
                ),
              ),
              const SizedBox(width: 6),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: claro ? AppColores.sobreRelleno : _tintaSobreDestacado,
              ),
            ],
          ),
        ),
      ),
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
        () => widget.onIrA(DestinoCliente.membresia),
      ),
      _Acceso(
        'Tienda',
        'Suplementos y más',
        Icons.shopping_bag_rounded,
        '$_fotos/tienda.jpg',
        () => widget.onIrA(DestinoCliente.tienda),
      ),
      _Acceso(
        'Mi avance',
        'Marcas y medidas de tu cuerpo',
        Icons.insights_rounded,
        '$_fotos/progreso.jpg',
        () => widget.onIrA(DestinoCliente.reporte),
      ),
    ];
    Widget fila(_Acceso a, _Acceso b) => Row(
      children: [
        Expanded(child: _tarjetaAcceso(a)),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(child: _tarjetaAcceso(b)),
      ],
    );
    return Column(
      children: [
        fila(accesos[0], accesos[1]),
        const SizedBox(height: AppEspaciado.sm + 4),
        fila(accesos[2], accesos[3]),
      ],
    );
  }

  Widget _tarjetaAcceso(_Acceso a) {
    return SizedBox(
      height: 150,
      child: FotoTarjeta(
        foto: a.foto,
        radio: AppEspaciado.radio + 2,
        onTap: a.onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColores.destacado,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(a.icono, size: 21, color: _tintaSobreDestacado),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          a.titulo,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
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
  final VoidCallback onTap;

  _Acceso(this.titulo, this.subtitulo, this.icono, this.foto, this.onTap);
}
