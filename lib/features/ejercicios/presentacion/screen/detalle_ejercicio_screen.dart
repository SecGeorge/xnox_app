import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/ejercicios/datos/repositorio_ejercicios.dart';
import 'package:xnox_app/features/ejercicios/presentacion/screen/reproductor_ejercicio_screen.dart';

/// Cómo se hace un ejercicio: la galería COMPLETA del catálogo a pantalla
/// grande (con zoom) más el video de ejecución, si el gimnasio lo subió.
///
/// La rutina solo guarda la portada del ejercicio, porque el listado del
/// backend devuelve una sola imagen. Las demás fotos se piden aquí por
/// `catalogoId`; mientras llegan —o si no hay conexión— se muestra la portada
/// que ya tenemos, para que la pantalla nunca quede vacía.
class DetalleEjercicioScreen extends StatefulWidget {
  final String nombre;

  /// Id en el catálogo del gimnasio. Null si el ejercicio se escribió a mano:
  /// en ese caso no hay galería que pedir.
  final int? catalogoId;

  /// Portada que ya venía en la rutina, como respaldo inmediato.
  final String? imagenUrl;

  final String? videoUrl;

  const DetalleEjercicioScreen({
    super.key,
    required this.nombre,
    this.catalogoId,
    this.imagenUrl,
    this.videoUrl,
  });

  @override
  State<DetalleEjercicioScreen> createState() => _DetalleEjercicioScreenState();
}

class _DetalleEjercicioScreenState extends State<DetalleEjercicioScreen> {
  final _repositorio = RepositorioEjercicios();
  final _paginas = PageController();

  late List<String> _imagenes = [
    if (widget.imagenUrl != null) widget.imagenUrl!,
  ];
  late String? _videoUrl = widget.videoUrl;

  String? _descripcion;
  String? _grupoMuscular;
  bool _cargando = false;
  int _actual = 0;

  bool get _tieneVideo => (_videoUrl ?? '').isNotEmpty;

  @override
  void initState() {
    super.initState();
    if (widget.catalogoId != null) _cargarGaleria();
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _cargarGaleria() async {
    setState(() => _cargando = true);
    final ejercicio = await _repositorio.obtener(widget.catalogoId!);
    if (!mounted) return;
    setState(() {
      _cargando = false;
      if (ejercicio == null) return;
      // Sin fotos en el catálogo nos quedamos con la portada de la rutina.
      if (ejercicio.imagenes.isNotEmpty) {
        _imagenes = ejercicio.imagenes;
        _actual = 0;
      }
      _descripcion = ejercicio.descripcion;
      _grupoMuscular = ejercicio.grupoMuscular;
      // `obtener` no trae el video; solo lo pisamos si de verdad vino uno.
      if (ejercicio.tieneVideo) _videoUrl = ejercicio.videoUrl;
    });
    if (_paginas.hasClients) _paginas.jumpToPage(0);
  }

  void _verVideo() {
    if (!_tieneVideo) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ReproductorEjercicioScreen(
          url: _videoUrl!,
          titulo: widget.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: Text(
          widget.nombre,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: AppEspaciado.lg),
        children: [
          _galeria(),
          if (_imagenes.length > 1) _tiras(),
          Padding(
            padding: const EdgeInsets.fromLTRB(AppEspaciado.md, AppEspaciado.md,
                AppEspaciado.md, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_tieneVideo) ...[
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _verVideo,
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Ver video de ejecución'),
                    ),
                  ),
                  const SizedBox(height: AppEspaciado.md),
                ],
                if (_grupoMuscular != null) ...[
                  _etiqueta(_grupoMuscular!),
                  const SizedBox(height: AppEspaciado.sm),
                ],
                if (_descripcion != null)
                  Text(
                    _descripcion!,
                    style: const TextStyle(
                        fontSize: 14,
                        height: 1.4,
                        color: AppColores.textoSecundario),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Marco grande: la foto entera (sin recortar) sobre fondo oscuro y con
  /// pellizco para acercar el detalle de la técnica.
  Widget _galeria() {
    final alto = MediaQuery.of(context).size.height * 0.48;

    if (_imagenes.isEmpty) {
      return Container(
        height: alto,
        color: Colors.black,
        alignment: Alignment.center,
        child: _cargando
            ? const CircularProgressIndicator(color: Colors.white)
            : const Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      size: 48, color: Colors.white38),
                  SizedBox(height: AppEspaciado.sm),
                  Text('Este ejercicio no tiene fotos',
                      style: TextStyle(color: Colors.white54, fontSize: 13)),
                ],
              ),
      );
    }

    return SizedBox(
      height: alto,
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              color: Colors.black,
              child: PageView.builder(
                controller: _paginas,
                itemCount: _imagenes.length,
                onPageChanged: (i) => setState(() => _actual = i),
                itemBuilder: (_, i) => InteractiveViewer(
                  minScale: 1,
                  maxScale: 4,
                  child: Image.network(
                    _imagenes[i],
                    fit: BoxFit.contain,
                    loadingBuilder: (_, hijo, progreso) => progreso == null
                        ? hijo
                        : const Center(
                            child: CircularProgressIndicator(
                                color: Colors.white)),
                    errorBuilder: (_, _, _) => const Center(
                      child: Icon(Icons.broken_image_outlined,
                          size: 48, color: Colors.white38),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_imagenes.length > 1)
            Positioned(
              top: AppEspaciado.sm,
              right: AppEspaciado.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text('${_actual + 1} / ${_imagenes.length}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600)),
              ),
            ),
          // Siguen llegando fotos del catálogo mientras se ve la portada.
          if (_cargando)
            const Positioned(
              top: AppEspaciado.sm,
              left: AppEspaciado.sm,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white70),
              ),
            ),
        ],
      ),
    );
  }

  /// Miniaturas para saltar entre fotos sin tener que deslizar una por una.
  Widget _tiras() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
            horizontal: AppEspaciado.md, vertical: AppEspaciado.sm),
        itemCount: _imagenes.length,
        separatorBuilder: (_, _) => const SizedBox(width: AppEspaciado.sm),
        itemBuilder: (_, i) {
          final activa = i == _actual;
          return GestureDetector(
            onTap: () => _paginas.animateToPage(
              i,
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
            ),
            child: Container(
              width: 58,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                border: Border.all(
                  color: activa ? AppColores.primario : AppColores.borde,
                  width: activa ? 2 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: Image.network(
                _imagenes[i],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(Icons.fitness_center,
                    size: 18, color: AppColores.textoSecundario),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColores.primario.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(texto,
          style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppColores.primario)),
    );
  }
}
