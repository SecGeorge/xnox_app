import 'package:flutter_tts/flutter_tts.dart';

/// Voz (texto a voz del teléfono) para los avisos del entrenamiento: "Tiempo
/// de recuperación" al entrar a descanso y la cuenta "tres, dos, uno" antes
/// de que empiece lo siguiente. Un solo motor para toda la app.
///
/// Usa el motor de texto a voz del sistema (voces neuronales en Android e
/// iOS modernos), así que no hace falta grabar ni empaquetar audio: lee
/// cualquier frase en español sin conexión.
class VozEntrenamiento {
  VozEntrenamiento._();
  static final instancia = VozEntrenamiento._();

  final _tts = FlutterTts();
  Future<void>? _preparando;

  Future<void> _preparar() => _preparando ??= () async {
    try {
      await _tts.setLanguage('es-ES');
      await _tts.setSpeechRate(0.52);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(false);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.duckOthers,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
      );
    } catch (_) {
      /* sin motor de voz: quedan el sonido y la vibración */
    }
  }();

  /// Interrumpe lo que esté diciendo y dice [texto].
  Future<void> decir(String texto) async {
    try {
      await _preparar();
      await _tts.stop();
      await _tts.speak(texto);
    } catch (_) {
      /* sin voz: queda el resto de avisos */
    }
  }

  /// 3 -> "tres", 2 -> "dos", lo demás -> "uno" (para la cuenta regresiva).
  static String numeroTexto(int n) => switch (n) {
    3 => 'tres',
    2 => 'dos',
    _ => 'uno',
  };
}
