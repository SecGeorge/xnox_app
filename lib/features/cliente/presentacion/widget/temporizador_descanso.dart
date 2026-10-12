import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/servicios/servicio_alarma_descanso.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/dialogo_permiso_alarma.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/hoja_numero.dart';

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
/// ([porDefecto]; 60 s si no lo fijó). El socio lo cambia tocando la cifra o
/// el lápiz (incluso con el descanso en marcha) y su elección se recuerda en su teléfono por ejercicio y
/// manda sobre la del gimnasio, hasta que la restablezca. En
/// los últimos 3 segundos suena un tic y al terminar el aviso suena y vibra
/// UNA Y OTRA VEZ hasta que el socio toca "Silenciar". Si no está mirando la
/// app (pantalla apagada, otra app, app cerrada) suena la alarma del sistema
/// ([ServicioAlarmaDescanso]), que también se repite hasta silenciarla.
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

class _TemporizadorDescansoState extends State<TemporizadorDescanso>
    with WidgetsBindingObserver {
  static const _opciones = [30, 45, 60, 90, 120, 180];
  static const _sinDefinir = 60;

  int get _delGimnasio =>
      (widget.porDefecto ?? 0) > 0 ? widget.porDefecto! : _sinDefinir;

  late int _segundos = _delGimnasio;

  /// El socio eligió su propio tiempo (guardado en el teléfono).
  bool _personalizado = false;
  int _restante = 0;
  Timer? _timer;

  /// Hora en que termina el descanso. El restante se calcula contra ella: con
  /// la pantalla apagada Android congela los Timer y contar ticks se desfasa.
  DateTime? _fin;

  /// El aviso de fin está sonando en la app (se repite hasta silenciarlo).
  bool _sonando = false;
  Timer? _bucle;

  bool _enPrimerPlano = true;

  /// Terminó con la app en segundo plano: al volver se mira si la alarma del
  /// sistema sigue sonando para pasarla a la app.
  bool _terminoFuera = false;

  static const _clavePermisoPedido = 'descanso_permiso_exacta_pedido';

  String get _clave => 'descanso_ejercicio_${widget.ejercicioId}';
  bool get _corriendo => _timer != null;

  @override
  void initState() {
    super.initState();
    widget.control?._estado = this;
    WidgetsBinding.instance.addObserver(this);
    _leerPreferencia();
    _Sonidos._preparar();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState estado) {
    if (estado == AppLifecycleState.resumed) {
      _enPrimerPlano = true;
      _alVolver();
    } else if (estado == AppLifecycleState.paused ||
        estado == AppLifecycleState.hidden) {
      _enPrimerPlano = false;
      // Si sonaba en la app y el socio se va sin silenciar, sigue sonando
      // como alarma del sistema.
      if (_sonando) {
        _pararBucle();
        ServicioAlarmaDescanso().programar(1);
        _terminoFuera = true;
      }
    }
  }

  Future<void> _alVolver() async {
    if (_corriendo) {
      _tic();
      // Por si acaba de conceder el permiso de alarmas exactas.
      if (_corriendo) ServicioAlarmaDescanso().programar(_restante);
      return;
    }
    if (!_terminoFuera) return;
    _terminoFuera = false;
    // Solo si aún no la calló desde la notificación.
    if (await ServicioAlarmaDescanso().estaSonando()) {
      await ServicioAlarmaDescanso().cancelar();
      if (mounted) _empezarSonido();
    }
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
    } catch (_) {
      /* sin preferencias: se queda el valor por defecto */
    }
  }

  /// Pide el tiempo con la hoja de número (escribirlo, − / + de 15 s o un
  /// atajo). Si el descanso está corriendo, sigue con el tiempo nuevo
  /// descontando lo que ya pasó.
  Future<void> _cambiarDuracion() async {
    final valor = await pedirNumero(
      context,
      titulo: 'Descanso entre series',
      subtitulo: (widget.porDefecto ?? 0) > 0
          ? 'Tu gimnasio indica ${_texto(_delGimnasio)}'
          : null,
      icono: Icons.timer_outlined,
      unidad: 'segundos',
      inicial: _segundos.toDouble(),
      paso: 15,
      minimo: 5,
      atajos: [
        if ((widget.porDefecto ?? 0) > 0)
          AtajoNumero('Gimnasio', _delGimnasio.toDouble()),
        for (final o in _opciones)
          if (o != _delGimnasio || (widget.porDefecto ?? 0) <= 0)
            AtajoNumero(_texto(o), o.toDouble()),
      ],
    );
    if (valor == null || !mounted) return;
    final nuevo = valor.round().clamp(5, 3600);
    setState(() {
      if (_corriendo) {
        final transcurrido = _segundos - _restante;
        _moverFin((nuevo - transcurrido).clamp(1, nuevo));
      }
      _segundos = nuevo;
      _personalizado = nuevo != _delGimnasio;
    });
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_personalizado) {
        await prefs.setInt(_clave, nuevo);
      } else {
        await prefs.remove(_clave);
      }
    } catch (_) {}
  }

  /// 90 -> "1:30 min", 45 -> "45 s".
  static String _texto(int s) => s < 60
      ? '$s s'
      : (s % 60 == 0
            ? '${s ~/ 60} min'
            : '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')} min');

  /// Vuelve al tiempo que indicó el gimnasio.
  Future<void> _restablecer() async {
    setState(() {
      if (_corriendo) {
        final transcurrido = _segundos - _restante;
        _moverFin((_delGimnasio - transcurrido).clamp(1, _delGimnasio));
      }
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
      ? 'Tu tiempo · el gimnasio indica ${_texto(_delGimnasio)}'
      : (widget.porDefecto ?? 0) > 0
      ? 'Indicado por tu gimnasio'
      : 'Toca el lápiz para cambiarlo';

  void _iniciar() {
    _silenciar();
    _timer?.cancel();
    _terminoFuera = false;
    _fin = DateTime.now().add(Duration(seconds: _segundos));
    setState(() => _restante = _segundos);
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) => _tic());
    _programarAlarma();
  }

  /// Recalcula el restante contra la hora de fin.
  void _tic() {
    final fin = _fin;
    if (!mounted || fin == null || _timer == null) return;
    final ms = fin.difference(DateTime.now()).inMilliseconds;
    final restante = ms <= 0 ? 0 : (ms / 1000).ceil();
    if (restante <= 0) {
      _terminar();
      return;
    }
    if (restante == _restante) return;
    setState(() => _restante = restante);
    // Cuenta regresiva audible: 3, 2, 1.
    if (restante <= 3 && _enPrimerPlano) _Sonidos.tic();
  }

  void _terminar() {
    _timer?.cancel();
    setState(() {
      _timer = null;
      _fin = null;
      _restante = 0;
    });
    if (_enPrimerPlano) {
      // Mirando la app: suena aquí y se quita la del sistema para que no
      // suenen las dos.
      ServicioAlarmaDescanso().cancelar();
      _empezarSonido();
    } else {
      // Suena la alarma del sistema; al volver se decide.
      _terminoFuera = true;
    }
  }

  /// Aviso + vibración cada 2,5 s hasta que el socio toca "Silenciar".
  void _empezarSonido() {
    _pararBucle();
    setState(() => _sonando = true);
    void avisar() {
      _Sonidos.fin();
      HapticFeedback.heavyImpact();
      Future.delayed(
        const Duration(milliseconds: 250),
        HapticFeedback.heavyImpact,
      );
    }

    avisar();
    _bucle = Timer.periodic(const Duration(milliseconds: 2500), (_) {
      if (!mounted) return _pararBucle();
      avisar();
    });
  }

  void _pararBucle() {
    _bucle?.cancel();
    _bucle = null;
  }

  /// Calla el aviso: el de la app y la alarma del sistema.
  void _silenciar() {
    final sonaba = _sonando;
    _pararBucle();
    _terminoFuera = false;
    if (sonaba) {
      setState(() => _sonando = false);
      ServicioAlarmaDescanso().cancelar();
    }
  }

  /// Fija el restante en [segundos] desde ahora y reprograma la alarma.
  void _moverFin(int segundos) {
    _fin = DateTime.now().add(Duration(seconds: segundos));
    _restante = segundos;
    _programarAlarma();
  }

  /// Programa la alarma del sistema. La primera vez que Android no la deja
  /// exacta (Android 14+ sin "Alarmas y recordatorios"), explica y ofrece
  /// activarlo: sin ese permiso puede sonar con minutos de retraso.
  Future<void> _programarAlarma() async {
    final exacta = await ServicioAlarmaDescanso().programar(_restante);
    if (exacta || !mounted) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_clavePermisoPedido) ?? false) return;
      await prefs.setBool(_clavePermisoPedido, true);
    } catch (_) {
      return;
    }
    if (!mounted) return;
    final activar = await pedirPermisoAlarma(context);
    // Al volver de los ajustes, _alVolver reprograma ya como exacta.
    if (activar) await ServicioAlarmaDescanso().pedirPermisoExacta();
  }

  /// Suma o quita tiempo SOLO a este descanso (no cambia el tiempo guardado):
  /// "hoy necesito un poco más" o "ya estoy listo".
  void _ajustar(int delta) {
    if (!_corriendo) return;
    HapticFeedback.selectionClick();
    setState(() => _moverFin((_restante + delta).clamp(1, 3600)));
  }

  void _detener() {
    _timer?.cancel();
    ServicioAlarmaDescanso().cancelar();
    setState(() {
      _timer = null;
      _fin = null;
      _restante = 0;
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Si sale de la pantalla con el descanso corriendo, la alarma del sistema
    // queda programada y avisará igual. Si estaba sonando, se calla.
    if (_sonando) ServicioAlarmaDescanso().cancelar();
    _pararBucle();
    _timer?.cancel();
    if (widget.control?._estado == this) widget.control?._estado = null;
    super.dispose();
  }

  static String _formato(int s) =>
      '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final avance = _corriendo
        ? (_restante / _segundos).clamp(0.0, 1.0).toDouble()
        : 0.0;
    final boton = _BotonPlay(
      corriendo: _corriendo,
      sonando: _sonando,
      tamano: widget.compacto ? 30 : 44,
      onTap: _sonando ? _silenciar : (_corriendo ? _detener : _iniciar),
    );

    if (widget.compacto) {
      return Row(
        children: [
          boton,
          const SizedBox(width: 10),
          const Icon(
            Icons.timer_outlined,
            size: 15,
            color: AppColores.textoSecundario,
          ),
          const SizedBox(width: 4),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _cambiarDuracion,
            child: Row(
              children: [
                Text(
                  'Descanso: ${_segundos}s',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(width: 3),
                Icon(Icons.edit_rounded, size: 13, color: AppColores.primario),
              ],
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
                      _sonando
                          ? '¡A la siguiente serie!'
                          : (_corriendo
                                ? 'Descansando…'
                                : 'Descanso entre series'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    Text(
                      _sonando
                          ? 'Sonará hasta que lo silencies'
                          : (_corriendo ? 'Toca ■ para detener' : _origen),
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColores.textoSecundario,
                      ),
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
              Material(
                color: AppColores.primario.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  onTap: _cambiarDuracion,
                  child: SizedBox(
                    width: 40,
                    height: 40,
                    child: Icon(
                      Icons.edit_rounded,
                      size: 19,
                      color: AppColores.primario,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              boton,
            ],
          ),
          const SizedBox(height: 12),
          _barra(avance),
          if (_sonando) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _silenciar,
                icon: const Icon(Icons.volume_off_rounded),
                label: const Text('¡Descanso terminado! Silenciar'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColores.moroso,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
          if (_corriendo) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _botonAjuste('−15 s', -15)),
                const SizedBox(width: 8),
                Expanded(child: _botonAjuste('+15 s', 15)),
                const SizedBox(width: 8),
                Expanded(child: _botonAjuste('+30 s', 30)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _botonAjuste(String texto, int delta) => OutlinedButton(
    onPressed: () => _ajustar(delta),
    style: OutlinedButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(vertical: 8),
      foregroundColor: AppColores.primario,
      side: BorderSide(color: AppColores.primario.withValues(alpha: 0.4)),
    ),
    child: Text(
      texto,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
    ),
  );

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

  /// El aviso de fin está sonando: el botón pasa a ser "silenciar".
  final bool sonando;
  final double tamano;
  final VoidCallback onTap;

  const _BotonPlay({
    required this.corriendo,
    this.sonando = false,
    required this.tamano,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = sonando ? AppColores.moroso : AppColores.primario;
    return Material(
      color: corriendo || sonando ? color : Colors.transparent,
      shape: CircleBorder(side: BorderSide(color: color, width: 1.6)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: tamano,
          height: tamano,
          child: Icon(
            sonando
                ? Icons.volume_off_rounded
                : (corriendo ? Icons.stop_rounded : Icons.play_arrow_rounded),
            size: tamano * 0.6,
            color: corriendo || sonando ? Colors.white : AppColores.primario,
          ),
        ),
      ),
    );
  }
}
