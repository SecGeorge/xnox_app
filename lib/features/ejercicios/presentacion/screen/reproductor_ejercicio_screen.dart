import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Reproduce el video de ejecución de un ejercicio (el que el gimnasio sube
/// desde el mantenedor del web, o el propio cliente al crear el suyo).
///
/// El video se ve en streaming desde el servidor de la empresa: no se descarga
/// ni se guarda en el teléfono.
class ReproductorEjercicioScreen extends StatefulWidget {
  final String url;
  final String titulo;

  const ReproductorEjercicioScreen({
    super.key,
    required this.url,
    required this.titulo,
  });

  @override
  State<ReproductorEjercicioScreen> createState() =>
      _ReproductorEjercicioScreenState();
}

class _ReproductorEjercicioScreenState
    extends State<ReproductorEjercicioScreen> {
  VideoPlayerController? _controlador;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _preparar();
  }

  Future<void> _preparar() async {
    final controlador =
        VideoPlayerController.networkUrl(Uri.parse(widget.url));
    try {
      await controlador.initialize();
      // Los clips son de pocos segundos: en bucle se puede repasar la técnica
      // sin tener que darle play una y otra vez.
      await controlador.setLooping(true);
      await controlador.play();
      if (!mounted) {
        await controlador.dispose();
        return;
      }
      setState(() {
        _controlador = controlador;
        _cargando = false;
      });
    } catch (_) {
      await controlador.dispose();
      if (!mounted) return;
      setState(() {
        _cargando = false;
        _error = 'No se pudo reproducir el video. Revisa tu conexión.';
      });
    }
  }

  @override
  void dispose() {
    _controlador?.dispose();
    super.dispose();
  }

  void _alternarPausa() {
    final c = _controlador;
    if (c == null) return;
    setState(() => c.value.isPlaying ? c.pause() : c.play());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.titulo,
          style: const TextStyle(fontSize: 16),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(child: _contenido()),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(
          child: CircularProgressIndicator(color: Colors.white));
    }

    final error = _error;
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.videocam_off_outlined,
                  size: 56, color: Colors.white38),
              const SizedBox(height: AppEspaciado.md),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 15),
              ),
              const SizedBox(height: AppEspaciado.lg),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _cargando = true;
                    _error = null;
                  });
                  _preparar();
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white),
                icon: const Icon(Icons.refresh),
                label: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }

    final c = _controlador!;
    // El video ocupa el alto que sobre y el AspectRatio se encoge para caber:
    // con un clip vertical (lo normal si se graba con el celular) la altura
    // calculada por ancho se pasaba de la pantalla y desbordaba.
    return Column(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _alternarPausa,
            behavior: HitTestBehavior.opaque,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: c.value.aspectRatio,
                    child: VideoPlayer(c),
                  ),
                ),
                // Fuera del AspectRatio para que el icono conserve su tamaño
                // sea cual sea la escala a la que quedó el video.
                if (!c.value.isPlaying)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: const BoxDecoration(
                      color: Colors.black45,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.play_arrow,
                        size: 44, color: Colors.white),
                  ),
              ],
            ),
          ),
        ),
        VideoProgressIndicator(
          c,
          allowScrubbing: true,
          colors: const VideoProgressColors(playedColor: AppColores.acento),
          padding: const EdgeInsets.symmetric(
              horizontal: AppEspaciado.md, vertical: AppEspaciado.sm),
        ),
        const Padding(
          padding: EdgeInsets.only(
              top: AppEspaciado.xs, bottom: AppEspaciado.md),
          child: Text(
            'Toca el video para pausar · se repite en bucle',
            style: TextStyle(color: Colors.white38, fontSize: 12),
          ),
        ),
      ],
    );
  }
}
