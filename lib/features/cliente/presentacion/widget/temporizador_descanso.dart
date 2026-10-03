import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Controla el temporizador desde fuera (p. ej. arrancarlo al registrar una
/// serie).
class ControlDescanso {
  _TemporizadorDescansoState? _estado;

  void iniciar() => _estado?._iniciar();
}

/// Sonidos del descanso. Un reproductor por sonido para toda la app.
///
/// Van en modo de baja latencia (SoundPool en Android): el reproductor normal
/// tocaba el primer aviso y en los siguientes daba la pista por terminada sin
/// sonar, un fallo conocido con sonidos tan cortos. Salen por el canal de
/// ALARMA: suenan aunque el teléfono esté en silencio o con la música baja, y
/// solo bajan un momento la música del socio en vez de cortarla.
class _Sonidos {
  _Sonidos._();

  static final _tic = AudioPlayer(playerId: 'descanso_tic');
  static final _fin = AudioPlayer(playerId: 'descanso_fin');
  static Future<void>? _preparando;

  static final _contexto = AudioContext(
    android: AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      usageType: AndroidUsageType.alarm,
      audioFocus: AndroidAudioFocus.gainTransientMayDuck,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: {AVAudioSessionOptions.duckOthers},
    ),
  );

  static Future<void> _preparar() => _preparando ??= () async {
        try {
          for (final p in [_tic, _fin]) {
            await p.setAudioContext(_contexto);
            await p.setPlayerMode(PlayerMode.lowLatency);
            await p.setReleaseMode(ReleaseMode.stop);
          }
          await _tic.setSource(AssetSource('sonidos/tic.wav'));
          await _fin.setSource(AssetSource('sonidos/descanso_fin.wav'));
        } catch (e) {
          debugPrint('[DESCANSO] no se pudo preparar el sonido: $e');
        }
      }();

  static Future<void> _sonar(AudioPlayer p, String archivo) async {
    try {
      await _preparar();
      // play() vuelve a indicar la fuente en cada aviso: en baja latencia la
      // carga queda en caché, y así cada aviso arranca desde cero seguro.
      await p.play(AssetSource(archivo), mode: PlayerMode.lowLatency);
    } catch (e) {
      debugPrint('[DESCANSO] no sonó el aviso: $e'); // queda la vibración
    }
  }

  static Future<void> tic() => _sonar(_tic, 'sonidos/tic.wav');
  static Future<void> fin() => _sonar(_fin, 'sonidos/descanso_fin.wav');
}

/// Cuenta regresiva del descanso entre series de un ejercicio.
///
/// Arranca con el descanso que el gimnasio fijó en el web para ese ejercicio
/// ([porDefecto]; 60 s si no lo fijó). El socio lo cambia tocando la cifra
/// (30 s → 3 min) y su elección se recuerda en su teléfono por ejercicio y
/// manda sobre la del gimnasio, hasta que la restablezca. En
/// los últimos 3 segundos suena un tic y al terminar suena un aviso y vibra,
/// para saber que toca la siguiente serie sin mirar el teléfono.
class TemporizadorDescanso extends StatefulWidget {
  final int ejercicioId;
  final ControlDescanso? control;

  /// Descanso que fijó el gimnasio (segundos), o null.
  final int? porDefecto;

  /// Versión de una línea (para las filas de la lista de ejercicios).
  final bool compacto;

  const TemporizadorDescanso({
    super.key,
    required this.ejercicioId,
    this.control,
    this.porDefecto,
    this.compacto = false,
  });

  @override
  State<TemporizadorDescanso> createState() => _TemporizadorDescansoState();
}

class _TemporizadorDescansoState extends State<TemporizadorDescanso> {
  static const _opciones = [30, 45, 60, 75, 90, 120, 180];
  static const _sinDefinir = 60;

  int get _delGimnasio =>
      (widget.porDefecto ?? 0) > 0 ? widget.porDefecto! : _sinDefinir;

  late int _segundos = _delGimnasio;

  /// El socio eligió su propio tiempo (guardado en el teléfono).
  bool _personalizado = false;
  int _restante = 0;
  Timer? _timer;

  String get _clave => 'descanso_ejercicio_${widget.ejercicioId}';
  bool get _corriendo => _timer != null;

  @override
  void initState() {
    super.initState();
    widget.control?._estado = this;
    _leerPreferencia();
    _Sonidos._preparar();
  }

  @override
  void didUpdateWidget(TemporizadorDescanso anterior) {
    super.didUpdateWidget(anterior);
    widget.control?._estado = this;
  }

  Future<void> _leerPreferencia() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final guardado = prefs.getInt(_clave);
      if (guardado != null && mounted) {
        setState(() {
          _segundos = guardado;
          _personalizado = guardado != _delGimnasio;
        });
      }
    } catch (_) {/* sin preferencias: se queda el valor por defecto */}
  }

  Future<void> _cambiarDuracion() async {
    if (_corriendo) return;
    // Siguiente opción de la lista (el valor del gimnasio puede no estar en
    // ella, p. ej. 100 s: se salta al siguiente mayor).
    final siguiente = _opciones.firstWhere((o) => o > _segundos,
        orElse: () => _opciones.first);
    setState(() {
      _segundos = siguiente;
      _personalizado = siguiente != _delGimnasio;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_clave, siguiente);
    } catch (_) {}
  }

  /// Vuelve al tiempo que indicó el gimnasio.
  Future<void> _restablecer() async {
    if (_corriendo) return;
    setState(() {
      _segundos = _delGimnasio;
      _personalizado = false;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_clave);
    } catch (_) {}
  }

  /// Texto de dónde sale el tiempo actual.
  String get _origen => _personalizado
      ? 'Tu tiempo · el gimnasio indica ${_delGimnasio}s'
      : (widget.porDefecto ?? 0) > 0
          ? 'Indicado por tu gimnasio · toca para cambiar'
          : 'Toca el tiempo para cambiarlo';

  void _iniciar() {
    _timer?.cancel();
    setState(() => _restante = _segundos);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      if (_restante <= 1) {
        t.cancel();
        setState(() {
          _timer = null;
          _restante = 0;
        });
        _Sonidos.fin();
        HapticFeedback.heavyImpact();
        Future.delayed(const Duration(milliseconds: 250),
            HapticFeedback.heavyImpact);
        return;
      }
      setState(() => _restante--);
      // Cuenta regresiva audible: 3, 2, 1.
      if (_restante <= 3) _Sonidos.tic();
    });
  }

  void _detener() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _restante = 0;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (widget.control?._estado == this) widget.control?._estado = null;
    super.dispose();
  }

  static String _formato(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final avance = _corriendo ? _restante / _segundos : 0.0;
    final boton = _BotonPlay(
      corriendo: _corriendo,
      tamano: widget.compacto ? 30 : 44,
      onTap: _corriendo ? _detener : _iniciar,
    );

    if (widget.compacto) {
      return Row(
        children: [
          boton,
          const SizedBox(width: 10),
          const Icon(Icons.timer_outlined,
              size: 15, color: AppColores.textoSecundario),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _cambiarDuracion,
            child: Text(
              'Descanso: ${_segundos}s',
              style: const TextStyle(
                  fontSize: 12, color: AppColores.textoSecundario),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: _barra(avance)),
          const SizedBox(width: 10),
          SizedBox(
            width: 42,
            child: Text(
              _corriendo ? _formato(_restante) : '${_segundos}s',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: _corriendo
                    ? AppColores.primario
                    : AppColores.textoSecundario,
              ),
            ),
          ),
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(
          color: _corriendo
              ? AppColores.primario.withValues(alpha: 0.4)
              : AppColores.borde,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: _cambiarDuracion,
                child: Text(
                  _formato(_corriendo ? _restante : _segundos),
                  style: TextStyle(
                    fontSize: 30,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _corriendo ? 'Descansando…' : 'Descanso entre series',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    Text(
                      _corriendo ? 'Toca para detener' : _origen,
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColores.textoSecundario),
                    ),
                    if (_personalizado && !_corriendo)
                      GestureDetector(
                        onTap: _restablecer,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            'Usar el del gimnasio',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: AppColores.primario,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              boton,
            ],
          ),
          const SizedBox(height: 12),
          _barra(avance),
        ],
      ),
    );
  }

  Widget _barra(double avance) => ClipRRect(
        borderRadius: BorderRadius.circular(3),
        child: LinearProgressIndicator(
          value: avance,
          minHeight: 5,
          color: AppColores.primario,
          backgroundColor: AppColores.primario.withValues(alpha: 0.10),
        ),
      );
}

class _BotonPlay extends StatelessWidget {
  final bool corriendo;
  final double tamano;
  final VoidCallback onTap;

  const _BotonPlay({
    required this.corriendo,
    required this.tamano,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: corriendo ? AppColores.primario : Colors.transparent,
      shape: CircleBorder(
        side: BorderSide(color: AppColores.primario, width: 1.6),
      ),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Icon(
            corriendo ? Icons.stop_rounded : Icons.play_arrow_rounded,
            size: tamano * 0.6,
            color: corriendo ? Colors.white : AppColores.primario,
          ),
        ),
      ),
    );
  }
}
