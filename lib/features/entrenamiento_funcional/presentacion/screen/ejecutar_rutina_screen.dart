import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/servicios/voz_entrenamiento.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/dialogo_salir_entrenamiento.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/core/widgets/imagen_red.dart';

/// Alertas configurables del temporizador (se recuerdan en el teléfono).
class _Alertas {
  bool sonido = true;
  bool cuentaRegresiva = true;
  bool vibracion = true;
  bool destello = true;

  static const _clave = 'rutina_funcional.alertas';

  Future<void> cargar() async {
    final p = await SharedPreferences.getInstance();
    final v = p.getStringList(_clave);
    if (v == null || v.length != 4) return;
    sonido = v[0] == '1';
    cuentaRegresiva = v[1] == '1';
    vibracion = v[2] == '1';
    destello = v[3] == '1';
  }

  Future<void> guardar() async {
    final p = await SharedPreferences.getInstance();
    await p.setStringList(_clave, [
      for (final b in [sonido, cuentaRegresiva, vibracion, destello])
        b ? '1' : '0',
    ]);
  }
}

/// Sonidos del temporizador: los mismos del descanso entre series. Salen por
/// el canal de alarma para que se oigan con la música del socio de fondo.
class _Sonidos {
  _Sonidos._();

  static final _fin = AudioPlayer(playerId: 'funcional_fin');
  static Future<void>? _preparando;

  static Future<void> _preparar() => _preparando ??= () async {
    try {
      final contexto = AudioContext(
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.alarm,
          audioFocus: AndroidAudioFocus.gainTransientMayDuck,
        ),
        iOS: AudioContextIOS(
          category: AVAudioSessionCategory.playback,
          options: const {AVAudioSessionOptions.duckOthers},
        ),
      );
      await _fin.setAudioContext(contexto);
      await _fin.setPlayerMode(PlayerMode.lowLatency);
      await _fin.setReleaseMode(ReleaseMode.stop);
    } catch (e) {
      debugPrint('[FUNCIONAL] no se pudo preparar el sonido: $e');
    }
  }();

  static Future<void> _sonar(AudioPlayer p, String archivo) async {
    try {
      await _preparar();
      await p.play(AssetSource(archivo), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('[FUNCIONAL] no sonó el aviso: $e');
    }
  }

  static Future<void> cambio() => _sonar(_fin, 'sonidos/descanso_fin.wav');
}

enum _Estado { listo, corriendo, pausado, terminado }

enum _Resultado { hecho, saltado }

/// Modo de ejecución de la sesión de un día: cuenta regresiva de cada trabajo
/// y descanso, transición automática entre bloques, rondas, alertas y resumen
/// al final.
///
/// Recorre los pasos que arma [MotorRutina], así que sirve igual para
/// circuitos, HIIT, EMOM, AMRAP, estaciones y musculación, y para un día que
/// combine varios. Sin [dia] pregunta qué día entrenar (si hay más de uno).
class EjecutarRutinaScreen extends StatefulWidget {
  final PlanRutina plan;
  final String? dia;

  const EjecutarRutinaScreen({super.key, required this.plan, this.dia});

  @override
  State<EjecutarRutinaScreen> createState() => _EjecutarRutinaScreenState();
}

class _EjecutarRutinaScreenState extends State<EjecutarRutinaScreen> {
  final _alertas = _Alertas();
  List<PasoRutina> _pasos = [];
  bool _elegirDia = false;
  int _indice = 0;
  _Estado _estado = _Estado.listo;
  final List<_Resultado?> _resultados = [];
  final Map<int, int> _rondasAmrap = {};

  // Reloj sin deriva: se suma el tiempo real entre ticks.
  Timer? _timer;
  final _cronometro = Stopwatch();
  int _ultimoMs = 0;
  double _transcurridoPaso = 0;
  double _tiempoActivo = 0;
  DateTime? _inicio;
  Duration _tiempoTotal = Duration.zero;
  int? _ultimoSegundoAvisado;
  bool _destello = false;

  SesionDia? _sesion;

  /// Metodología del bloque en curso (la sesión puede combinar varias).
  Metodologia get _m => _paso?.metodologia ?? widget.plan.metodologia;
  PasoRutina? get _paso =>
      _indice < _pasos.length ? _pasos[_indice] : null;

  @override
  void initState() {
    super.initState();
    _alertas.cargar().then((_) {
      if (mounted) setState(() {});
    });
    final sesiones = widget.plan.sesiones;
    final elegida = sesiones.where((s) => s.dia == widget.dia).firstOrNull;
    if (elegida != null || sesiones.length == 1) {
      _elegirSesion(elegida ?? sesiones.first);
    } else if (sesiones.length > 1) {
      _elegirDia = true;
    }
  }

  void _elegirSesion(SesionDia s) {
    _sesion = s;
    _pasos = MotorRutina.expandirDia(s.bloques);
    _elegirDia = false;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  // ------------------------------------------------------------- Reloj
  void _iniciar() {
    _inicio = DateTime.now();
    setState(() => _estado = _Estado.corriendo);
    _anunciar();
    _arrancar();
  }

  void _pausar() {
    _timer?.cancel();
    _cronometro.stop();
    setState(() => _estado = _Estado.pausado);
  }

  void _continuar() {
    setState(() => _estado = _Estado.corriendo);
    _arrancar();
  }

  void _arrancar() {
    _timer?.cancel();
    _cronometro
      ..reset()
      ..start();
    _ultimoMs = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 100), (_) => _tick());
  }

  void _tick() {
    final ms = _cronometro.elapsedMilliseconds;
    final delta = (ms - _ultimoMs) / 1000;
    _ultimoMs = ms;
    final p = _paso;
    if (p == null) return;
    setState(() {
      _transcurridoPaso += delta;
      _tiempoActivo += delta;
      if (_inicio != null) _tiempoTotal = DateTime.now().difference(_inicio!);
    });
    if (p.duracion == null) return;
    final quedan = (p.duracion! - _transcurridoPaso).ceil();
    if (quedan != _ultimoSegundoAvisado && quedan > 0 && quedan <= 3) {
      _ultimoSegundoAvisado = quedan;
      if (_alertas.sonido && _alertas.cuentaRegresiva) {
        final siguiente = _indice + 1 < _pasos.length ? _pasos[_indice + 1] : null;
        final numero = VozEntrenamiento.numeroTexto(quedan);
        VozEntrenamiento.instancia.decir(
          quedan == 1 && siguiente != null
              ? '$numero, ${siguiente.esDescanso ? 'descanso' : 'empecemos'}'
              : numero,
        );
      }
      if (_alertas.vibracion) HapticFeedback.selectionClick();
    }
    if (_transcurridoPaso >= p.duracion!) _avanzar(_Resultado.hecho);
  }

  // ------------------------------------------------------ Navegación
  void _avanzar(_Resultado r) {
    // Si la cuenta regresiva llegó a "uno" ya avisó "...uno,
    // empecemos/descanso"; si se saltó antes de los últimos 3 segundos (o no
    // tenía reloj), no sonó y hay que avisar el cambio igual.
    final yaContado = _ultimoSegundoAvisado == 1;
    if (_resultados.length > _indice) {
      _resultados[_indice] = r;
    } else {
      _resultados.add(r);
    }
    if (_indice >= _pasos.length - 1) {
      _terminar();
      return;
    }
    setState(() {
      _indice++;
      _transcurridoPaso = 0;
      _ultimoSegundoAvisado = null;
    });
    _anunciar(conVoz: !yaContado);
  }

  void _anterior() {
    if (_indice == 0) return;
    setState(() {
      _indice--;
      if (_resultados.length > _indice) _resultados.removeRange(_indice, _resultados.length);
      _transcurridoPaso = 0;
      _ultimoSegundoAvisado = null;
    });
    _anunciar();
  }

  void _sumarRondaAmrap() {
    final b = _paso!.bloque;
    setState(() => _rondasAmrap[b] = (_rondasAmrap[b] ?? 0) + 1);
    if (_alertas.vibracion) HapticFeedback.lightImpact();
  }

  void _terminar() {
    _timer?.cancel();
    _cronometro.stop();
    if (_inicio != null) _tiempoTotal = DateTime.now().difference(_inicio!);
    setState(() => _estado = _Estado.terminado);
    if (_alertas.sonido) _Sonidos.cambio();
    if (_alertas.vibracion) HapticFeedback.heavyImpact();
  }

  void _reiniciar() {
    _timer?.cancel();
    setState(() {
      _indice = 0;
      _estado = _Estado.listo;
      _transcurridoPaso = 0;
      _tiempoActivo = 0;
      _tiempoTotal = Duration.zero;
      _inicio = null;
      _resultados.clear();
      _rondasAmrap.clear();
    });
  }

  void _anunciar({bool conVoz = true}) {
    final p = _paso;
    if (p == null) return;
    if (_alertas.destello) {
      setState(() => _destello = true);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _destello = false);
      });
    }
    if (_alertas.sonido) {
      _Sonidos.cambio();
      // Si venía de una cuenta regresiva ("...uno, descanso/empecemos") no se
      // repite: solo avisa cuando el cambio fue manual (Saltar, Anterior, un
      // paso sin reloj) y no hubo cuenta.
      if (conVoz && p.esDescanso) {
        VozEntrenamiento.instancia.decir('Tiempo de recuperación');
      }
    }
    if (_alertas.vibracion) {
      p.esDescanso ? HapticFeedback.mediumImpact() : HapticFeedback.heavyImpact();
    }
  }

  Future<bool> _confirmarSalida() async {
    if (_estado == _Estado.listo || _estado == _Estado.terminado) return true;
    return confirmarSalirEntrenamiento(context);
  }

  // ------------------------------------------------------------ Resumen
  ({int ejercicios, int saltados, int rondas}) get _resumen {
    var ejercicios = 0;
    var saltados = 0;
    var rondas = 0;
    for (var i = 0; i < _resultados.length; i++) {
      final p = _pasos[i];
      final r = _resultados[i];
      if (r == _Resultado.saltado) saltados++;
      final esTrabajo = p.fase == FasePaso.trabajo || p.fase == FasePaso.emom;
      if (!esTrabajo) continue;
      if (r == _Resultado.hecho) ejercicios++;
      switch (p.metodologia.forma) {
        case FormaMetodologia.series:
          if (r == _Resultado.hecho && p.serie == p.series) rondas++;
        case FormaMetodologia.circuito:
        case FormaMetodologia.mixto:
          if (r != null && p.indice == p.total - 1) rondas++;
        case FormaMetodologia.emom:
          if (r == _Resultado.hecho) rondas++;
        case FormaMetodologia.amrap:
          break;
      }
    }
    // AMRAP: las rondas que el socio fue marcando.
    rondas += _rondasAmrap.values.fold(0, (s, n) => s + n);
    return (ejercicios: ejercicios, saltados: saltados, rondas: rondas);
  }

  bool get _completo =>
      _resultados.length == _pasos.length &&
      !_resultados.contains(_Resultado.saltado);

  double get _progresoTotal {
    final total = MotorRutina.sumar(_pasos);
    if (total == 0) return 0;
    if (_estado == _Estado.terminado) return 1;
    final hecho = MotorRutina.sumar(_pasos.sublist(0, _indice));
    final actual = _paso == null
        ? 0
        : math.min(_transcurridoPaso, _paso!.segundos.toDouble());
    return ((hecho + actual) / total).clamp(0, 1).toDouble();
  }

  /// Acento de la fase actual: azul para descanso, navy para trabajo (y
  /// mientras no ha arrancado o ya terminó). Tiñe apenas el fondo y colorea
  /// el anillo, los chips y la etiqueta para que se note el cambio de fase
  /// sin salirse de la paleta azul marino y blanco de la app.
  Color get _acento =>
      (_paso?.esDescanso ?? false) ? AppColores.azul : AppColores.primario;

  // ---------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final p = _paso;
    final acento = _acento;
    final fondoFase = Color.alphaBlend(
      acento.withValues(alpha: 0.05),
      AppColores.fondo,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _confirmarSalida() && context.mounted) Navigator.pop(context);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        color: _destello
            ? Color.alphaBlend(acento.withValues(alpha: 0.14), AppColores.fondo)
            : fondoFase,
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: DefaultTextStyle(
              style: TextStyle(color: AppColores.textoPrincipal),
              child: Column(
                children: [
                  _barra(p),
                  LinearProgressIndicator(
                    value: _progresoTotal,
                    minHeight: 4,
                    color: AppColores.primario,
                    backgroundColor: AppColores.borde,
                  ),
                  Expanded(child: _cuerpo(p)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barra(PasoRutina? p) => Container(
    padding: const EdgeInsets.fromLTRB(4, 4, 8, 4),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColores.borde)),
    ),
    child: Row(
      children: [
        IconButton(
          icon: Icon(Icons.close_rounded, color: AppColores.textoPrincipal),
          onPressed: () async {
            if (await _confirmarSalida() && mounted) Navigator.pop(context);
          },
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.plan.nombre,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  color: AppColores.textoPrincipal,
                ),
              ),
              Text(
                [
                  if (_sesion != null) _sesion!.etiqueta,
                  if (p != null) '${_m.texto} · ${p.bloqueNombre}',
                ].join(' · '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        Icon(Icons.schedule_rounded, size: 16, color: AppColores.primario),
        const SizedBox(width: 4),
        Text(
          formatoReloj(_tiempoActivo),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColores.textoPrincipal,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        IconButton(
          tooltip: 'Alertas',
          icon: Icon(
            Icons.notifications_active_outlined,
            color: AppColores.primario,
          ),
          onPressed: _abrirAlertas,
        ),
      ],
    ),
  );

  Future<void> _abrirAlertas() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => StatefulBuilder(
        builder: (c, set) {
          Widget sw(String t, bool v, void Function(bool) f) => SwitchListTile(
            title: Text(
              t,
              style: TextStyle(color: AppColores.textoPrincipal),
            ),
            activeThumbColor: AppColores.primario,
            value: v,
            onChanged: (x) {
              set(() => f(x));
              setState(() {});
              _alertas.guardar();
            },
          );
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  title: Text(
                    'Alertas',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
                sw('Sonido al cambiar', _alertas.sonido, (x) => _alertas.sonido = x),
                sw(
                  'Voz: cuenta 3-2-1',
                  _alertas.cuentaRegresiva,
                  (x) => _alertas.cuentaRegresiva = x,
                ),
                sw('Vibración', _alertas.vibracion, (x) => _alertas.vibracion = x),
                sw('Destello en pantalla', _alertas.destello, (x) => _alertas.destello = x),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _cuerpo(PasoRutina? p) {
    if (_elegirDia) return _selectorDia();
    if (_pasos.isEmpty) {
      return const Center(child: Text('Esta rutina no tiene ejercicios.'));
    }
    if (_estado == _Estado.terminado) return _vistaResumen();
    if (p == null) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, c) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: c.maxHeight - 36),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  _indicadores(p),
                  const SizedBox(height: 14),
                  Text(
                    _etiquetaFase(p),
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1,
                      color: _acento,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _anillo(p, math.min(c.maxWidth * 0.62, 280)),
                  const SizedBox(height: 20),
                  _ejercicio(p),
                ],
              ),
              const SizedBox(height: 20),
              _controles(p),
            ],
          ),
        ),
      ),
    );
  }

  String _etiquetaFase(PasoRutina p) {
    if (_estado == _Estado.listo) return 'PREPÁRATE';
    return switch (p.fase) {
      FasePaso.trabajo => '¡TRABAJO!',
      FasePaso.emom => '¡ARRANCA EL MINUTO!',
      FasePaso.amrap => '¡TODAS LAS RONDAS QUE PUEDAS!',
      FasePaso.descanso => p.serie != null ? 'DESCANSO ENTRE SERIES' : 'DESCANSO',
      FasePaso.descansoRonda => 'DESCANSO ENTRE RONDAS',
      FasePaso.descansoBloque => 'DESCANSO ENTRE BLOQUES',
    };
  }

  Widget _indicadores(PasoRutina p) {
    final acento = _acento;
    Widget chip(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: acento.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        t,
        style: TextStyle(fontWeight: FontWeight.w700, color: acento),
      ),
    );
    final ronda = _m.etiquetaRondas == 'Vueltas' ? 'Vuelta' : 'Ronda';
    final chips = <Widget>[
      if (p.rondas != null && p.fase != FasePaso.amrap && !_m.esSeries)
        chip('$ronda ${p.ronda} / ${p.rondas}'),
      if (p.fase == FasePaso.emom) chip('Minuto ${p.minuto} / ${p.minutos}'),
      if (p.serie != null) chip('Serie ${p.serie} / ${p.series}'),
      if (p.total > 0 && p.fase != FasePaso.amrap && p.fase != FasePaso.descansoBloque)
        chip('${_m.etiquetaEjercicio} ${p.indice + 1} / ${p.total}'),
    ];
    return Column(
      children: [
        Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: chips),
        if (p.total > 1 && p.fase != FasePaso.amrap && p.fase != FasePaso.descansoBloque) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < p.total; i++)
                Container(
                  width: i == p.indice && !p.esDescanso ? 14 : 10,
                  height: i == p.indice && !p.esDescanso ? 14 : 10,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < p.indice || (i == p.indice && p.esDescanso)
                        ? acento.withValues(alpha: 0.55)
                        : i == p.indice
                        ? acento
                        : AppColores.borde,
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _anillo(PasoRutina p, double tam) {
    final acento = _acento;
    final restante = p.duracion == null
        ? null
        : math.max(0, p.duracion! - _transcurridoPaso);
    final avance = p.duracion == null
        ? (_estado == _Estado.listo ? 0.0 : 1.0)
        : math.min(1.0, _transcurridoPaso / p.duracion!);
    return SizedBox(
      width: tam,
      height: tam,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: 1 - avance,
              strokeWidth: 12,
              strokeCap: StrokeCap.round,
              color: acento,
              backgroundColor: acento.withValues(alpha: 0.12),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                restante == null
                    ? formatoReloj(_transcurridoPaso)
                    : formatoReloj(restante.ceil()),
                style: TextStyle(
                  fontSize: tam * 0.26,
                  fontWeight: FontWeight.w900,
                  height: 1,
                  color: AppColores.textoPrincipal,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              if (p.duracion == null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'a tu ritmo',
                    style: const TextStyle(color: AppColores.textoSecundario),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _imagen(String? url, double tam, {IconData? icono}) => ClipRRect(
    borderRadius: BorderRadius.circular(tam * 0.12),
    child: Container(
      width: tam,
      height: tam,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        border: Border.all(color: AppColores.borde),
      ),
      child: (url ?? '').isEmpty
          ? Icon(
              icono ?? _m.icono,
              size: tam * 0.45,
              color: AppColores.primario.withValues(alpha: 0.5),
            )
          : imagenRed(
              url!,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Icon(
                icono ?? _m.icono,
                size: tam * 0.45,
                color: AppColores.primario.withValues(alpha: 0.5),
              ),
            ),
    ),
  );

  Widget _ejercicio(PasoRutina p) {
    if (p.fase == FasePaso.amrap) {
      return Column(
        children: [
          Text(
            '${_rondasAmrap[p.bloque] ?? 0}',
            style: TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.w900,
              height: 1,
              color: AppColores.textoPrincipal,
            ),
          ),
          const Text(
            'rondas completas',
            style: TextStyle(color: AppColores.textoSecundario),
          ),
          const SizedBox(height: 14),
          for (final e in p.ejercicios)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  _imagen(e.imagenUrl, 42),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 72,
                    child: Text(
                      e.medida(),
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AppColores.primario,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      e.nombre,
                      style: TextStyle(
                        fontSize: 17,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }
    if (p.esDescanso) {
      final sig = p.siguiente;
      return Column(
        children: [
          Text(
            'Descansa',
            style: TextStyle(
              fontSize: 30,
              fontWeight: FontWeight.w900,
              color: AppColores.textoPrincipal,
            ),
          ),
          if (sig != null) ...[
            const SizedBox(height: 18),
            const Text('Sigue', style: TextStyle(color: AppColores.textoSecundario)),
            const SizedBox(height: 8),
            _imagen(sig.imagenUrl, 84),
            const SizedBox(height: 8),
            Text(
              sig.nombre,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColores.textoPrincipal,
              ),
            ),
            if (sig.medida().isNotEmpty)
              Text(
                sig.medida(),
                style: const TextStyle(color: AppColores.textoSecundario),
              ),
          ],
        ],
      );
    }
    final e = p.ejercicio!;
    final despues = p.siguiente ?? _siguienteTrabajo;
    final medida = e.medida(conTiempo: _m.forma != FormaMetodologia.circuito);
    return Column(
      children: [
        _imagen(e.imagenUrl, 150),
        const SizedBox(height: 14),
        Text(
          e.nombre,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w900,
            height: 1.15,
            color: AppColores.textoPrincipal,
          ),
        ),
        if (medida.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              medida,
              style: TextStyle(fontSize: 18, color: AppColores.primario),
            ),
          ),
        if ((e.observaciones ?? '').isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              e.observaciones!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColores.textoSecundario),
            ),
          ),
        if (despues != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              'Después: ${despues.nombre}',
              style: const TextStyle(color: AppColores.textoSecundario),
            ),
          ),
      ],
    );
  }

  PlanEjercicio? get _siguienteTrabajo {
    for (var i = _indice + 1; i < _pasos.length; i++) {
      if (!_pasos[i].esDescanso && _pasos[i].ejercicio != null) {
        return _pasos[i].ejercicio;
      }
    }
    return null;
  }

  Widget _controles(PasoRutina p) {
    final principal = ElevatedButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 16),
      textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
    );
    if (_estado == _Estado.listo) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: principal,
          onPressed: _iniciar,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Iniciar'),
        ),
      );
    }
    Widget redondo(IconData i, String t, VoidCallback? f, {Color? color}) {
      final tinta = color ?? _acento;
      return Column(
        children: [
          IconButton.outlined(
            onPressed: f,
            iconSize: 26,
            style: IconButton.styleFrom(
              foregroundColor: tinta,
              side: BorderSide(color: tinta.withValues(alpha: f == null ? 0.3 : 0.6)),
              disabledForegroundColor: AppColores.textoSecundario.withValues(alpha: 0.4),
            ),
            icon: Icon(i),
          ),
          Text(
            t,
            style: TextStyle(
              fontSize: 11,
              color: f == null ? AppColores.textoSecundario : AppColores.textoPrincipal,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        if (p.fase == FasePaso.amrap || p.duracion == null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: principal,
                onPressed: p.fase == FasePaso.amrap
                    ? _sumarRondaAmrap
                    : () => _avanzar(_Resultado.hecho),
                icon: Icon(
                  p.fase == FasePaso.amrap ? Icons.add_rounded : Icons.check_rounded,
                ),
                label: Text(
                  p.fase == FasePaso.amrap
                      ? 'Ronda completada'
                      : p.serie != null
                      ? 'Serie hecha'
                      : 'Hecho',
                ),
              ),
            ),
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            redondo(Icons.skip_previous_rounded, 'Anterior', _indice == 0 ? null : _anterior),
            redondo(
              _estado == _Estado.corriendo ? Icons.pause_rounded : Icons.play_arrow_rounded,
              _estado == _Estado.corriendo ? 'Pausar' : 'Continuar',
              _estado == _Estado.corriendo ? _pausar : _continuar,
            ),
            redondo(
              Icons.skip_next_rounded,
              'Saltar',
              () => _avanzar(_Resultado.saltado),
              color: AppColores.naranja,
            ),
            redondo(
              Icons.stop_rounded,
              'Finalizar',
              _terminar,
              color: AppColores.moroso,
            ),
          ],
        ),
      ],
    );
  }

  Widget _selectorDia() {
    final sesiones = widget.plan.sesiones;
    final hoy = diasSemana[DateTime.now().weekday - 1];
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Text(
              '¿Qué día vas a entrenar?',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColores.textoPrincipal,
              ),
            ),
            const SizedBox(height: 20),
            for (final s in sesiones)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Material(
                  color: s.dia == hoy
                      ? AppColores.primario.withValues(alpha: 0.10)
                      : AppColores.superficie,
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => setState(() => _elegirSesion(s)),
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: s.dia == hoy
                              ? AppColores.primario.withValues(alpha: 0.4)
                              : AppColores.borde,
                        ),
                      ),
                      child: ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        title: Text(
                          s.dia == hoy ? '${s.etiqueta} · hoy' : s.etiqueta,
                          style: TextStyle(
                            color: AppColores.textoPrincipal,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        subtitle: Text(
                          '${s.bloques.map((b) => b.metodologia.texto).join(' + ')} · ~${formatoDuracion(s.duracion)}',
                          style: const TextStyle(color: AppColores.textoSecundario),
                        ),
                        trailing: Icon(
                          Icons.play_arrow_rounded,
                          color: AppColores.primario,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _vistaResumen() {
    final r = _resumen;
    final formas = {for (final p in _pasos) p.metodologia.forma};
    final unica = formas.length == 1 ? formas.first : null;
    final etiquetaRondas = switch (unica) {
      FormaMetodologia.emom => 'minutos completados',
      FormaMetodologia.series => 'ejercicios terminados',
      null => 'rondas y ejercicios terminados',
      _ => '${_pasos.first.metodologia.etiquetaRondas.toLowerCase()} realizadas',
    };
    Widget dato(String v, String t) => Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v,
            style: TextStyle(
              fontSize: 26,
              height: 1.1,
              fontWeight: FontWeight.w900,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            t,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 13, color: AppColores.textoSecundario),
          ),
        ],
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Icon(Icons.emoji_events_outlined, size: 72, color: AppColores.primario),
          const SizedBox(height: 8),
          Text(
            _completo ? '¡Rutina completada!' : 'Entrenamiento finalizado',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: 24),
          LayoutBuilder(
            builder: (context, c) {
              final anchoCelda = (c.maxWidth - 12) / 2;
              Widget celda(Widget hijo) => SizedBox(width: anchoCelda, child: hijo);
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  celda(dato(formatoReloj(_tiempoActivo), 'duración real')),
                  celda(dato(formatoReloj(_tiempoTotal.inSeconds), 'con pausas')),
                  celda(
                    dato(
                      '${r.ejercicios}',
                      unica == FormaMetodologia.series
                          ? 'series hechas'
                          : 'ejercicios / series hechos',
                    ),
                  ),
                  celda(dato('${r.rondas}', etiquetaRondas)),
                  if (r.saltados > 0) celda(dato('${r.saltados}', 'saltados')),
                  celda(dato(formatoReloj(MotorRutina.sumar(_pasos)), 'estimado')),
                ],
              );
            },
          ),
          const SizedBox(height: 28),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColores.primario,
                    side: BorderSide(color: AppColores.primario),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _reiniciar,
                  icon: const Icon(Icons.restart_alt_rounded),
                  label: const Text('Repetir'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Listo'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
