import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ejercicios/datos/repositorio_ejercicios.dart';
import 'package:xnox_app/features/ejercicios/dominio/entidades/ejercicio_catalogo.dart';

/// Lo que devuelve la hoja al agregar un ejercicio a un día de la rutina.
class EjercicioElegido {
  final String nombre;
  final int series;
  final int repeticiones;
  final String? observaciones;

  /// Vienen del catálogo cuando el ejercicio se eligió de las sugerencias o se
  /// acaba de crear. Sin conexión quedan en null y el ejercicio es solo texto.
  final int? catalogoId;
  final String? imagenUrl;
  final String? videoUrl;

  const EjercicioElegido({
    required this.nombre,
    required this.series,
    required this.repeticiones,
    this.observaciones,
    this.catalogoId,
    this.imagenUrl,
    this.videoUrl,
  });
}

/// Hoja para agregar un ejercicio con autocompletado.
///
/// Al escribir busca en el catálogo del gimnasio (más los ejercicios que el
/// propio cliente creó). Si el nombre no existe, ofrece crearlo con fotos, y
/// si no hay conexión igual deja guardarlo como texto: nunca bloquea la rutina.
Future<EjercicioElegido?> mostrarHojaAgregarEjercicio(BuildContext context) {
  return showModalBottomSheet<EjercicioElegido>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => const _HojaAgregarEjercicio(),
  );
}

class _HojaAgregarEjercicio extends StatefulWidget {
  const _HojaAgregarEjercicio();

  @override
  State<_HojaAgregarEjercicio> createState() => _HojaAgregarEjercicioState();
}

class _HojaAgregarEjercicioState extends State<_HojaAgregarEjercicio> {
  final _repositorio = RepositorioEjercicios();

  final _nombreCtrl = TextEditingController();
  final _seriesCtrl = TextEditingController(text: '4');
  final _repsCtrl = TextEditingController(text: '10');
  final _obsCtrl = TextEditingController();

  Timer? _debounce;
  bool _buscando = false;
  bool _guardando = false;
  String? _error;

  List<EjercicioCatalogo> _sugerencias = [];

  /// Ejercicio del catálogo ya elegido. Se suelta al volver a escribir.
  EjercicioCatalogo? _elegido;

  /// Fotos para el ejercicio nuevo (solo cuando no existe en el catálogo).
  final List<File> _fotos = [];
  bool _pidiendoFotos = false;

  /// Video de ejecución del ejercicio nuevo (opcional, uno solo).
  /// Estos topes deben coincidir con EjerciciosDominio (MAX_VIDEO_*).
  static const int _maxSegundosVideo = 30;
  static const int _maxMbVideo = 25;
  File? _video;
  String? _errorVideo;
  bool _eligiendoVideo = false;

  bool get _nombreEsNuevo {
    final texto = _nombreCtrl.text.trim();
    if (texto.isEmpty) return false;
    if (_elegido != null && _elegido!.nombre.toLowerCase() == texto.toLowerCase()) {
      return false;
    }
    return !_sugerencias.any((s) => s.nombre.toLowerCase() == texto.toLowerCase());
  }

  @override
  void initState() {
    super.initState();
    // Sugerencias iniciales: lo más usado del gimnasio, sin escribir nada.
    _buscar('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _nombreCtrl.dispose();
    _seriesCtrl.dispose();
    _repsCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  void _alEscribir(String texto) {
    // Si venía de una sugerencia y se edita el texto, deja de estar elegido.
    if (_elegido != null && _elegido!.nombre != texto) {
      _elegido = null;
    }
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => _buscar(texto));
    setState(() {});
  }

  Future<void> _buscar(String termino) async {
    setState(() => _buscando = true);
    final resultados = await _repositorio.buscar(termino.trim());
    if (!mounted) return;
    setState(() {
      _sugerencias = resultados;
      _buscando = false;
    });
  }

  void _elegirSugerencia(EjercicioCatalogo ejercicio) {
    setState(() {
      _elegido = ejercicio;
      _nombreCtrl.text = ejercicio.nombre;
      _fotos.clear();
      _video = null;
      _errorVideo = null;
      _pidiendoFotos = false;
      _error = null;
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _agregarFotos() async {
    final picker = ImagePicker();
    final imagenes = await picker.pickMultiImage(
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 75,
    );
    if (imagenes.isEmpty) return;
    setState(() => _fotos.addAll(imagenes.map((x) => File(x.path))));
  }

  /// Elige el video de ejecución y lo valida ANTES de subirlo: peso por el
  /// propio archivo y duración abriéndolo con el reproductor. Así el cliente se
  /// entera al instante en vez de esperar a que suban 25 MB para nada.
  ///
  /// `maxDuration` del selector solo recorta al grabar con la cámara; un video
  /// elegido de la galería llega entero, por eso hay que medirlo aquí.
  Future<void> _elegirVideo(ImageSource origen) async {
    setState(() {
      _eligiendoVideo = true;
      _errorVideo = null;
    });
    try {
      final elegido = await ImagePicker().pickVideo(
        source: origen,
        maxDuration: const Duration(seconds: _maxSegundosVideo),
      );
      if (elegido == null) return;

      final archivo = File(elegido.path);
      final bytes = await archivo.length();
      if (bytes > _maxMbVideo * 1024 * 1024) {
        final mb = (bytes / 1048576).toStringAsFixed(1);
        _rechazarVideo('El video pesa $mb MB y el máximo son $_maxMbVideo MB');
        return;
      }

      final duracion = await _duracionVideo(archivo);
      if (duracion != null && duracion.inSeconds > _maxSegundosVideo + 1) {
        _rechazarVideo(
            'El video dura ${duracion.inSeconds} s y el máximo son $_maxSegundosVideo s');
        return;
      }

      if (!mounted) return;
      setState(() => _video = archivo);
    } finally {
      if (mounted) setState(() => _eligiendoVideo = false);
    }
  }

  /// Duración real del archivo, o null si no se pudo leer (formato raro): en
  /// ese caso no se bloquea, el backend vuelve a validarlo.
  Future<Duration?> _duracionVideo(File archivo) async {
    final controlador = VideoPlayerController.file(archivo);
    try {
      await controlador.initialize();
      return controlador.value.duration;
    } catch (_) {
      return null;
    } finally {
      await controlador.dispose();
    }
  }

  void _rechazarVideo(String mensaje) {
    if (!mounted) return;
    setState(() {
      _video = null;
      _errorVideo = mensaje;
    });
  }

  /// Menú para grabar el video en el momento o tomarlo de la galería.
  Future<void> _menuVideo() async {
    final origen = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.videocam_outlined,
                  color: AppColores.primario),
              title: const Text('Grabar video'),
              subtitle: const Text('Máximo $_maxSegundosVideo segundos'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.video_library_outlined,
                  color: AppColores.primario),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (origen == null) return;
    await _elegirVideo(origen);
  }

  String? _validar() {
    if (_nombreCtrl.text.trim().isEmpty) return 'Ingresa el nombre del ejercicio';
    final series = int.tryParse(_seriesCtrl.text.trim());
    if (series == null || series <= 0) return 'Las series deben ser un número mayor a 0';
    final reps = int.tryParse(_repsCtrl.text.trim());
    if (reps == null || reps <= 0) return 'Las repeticiones deben ser un número mayor a 0';
    return null;
  }

  Future<void> _guardar() async {
    final error = _validar();
    if (error != null) {
      setState(() => _error = error);
      return;
    }

    final nombre = _nombreCtrl.text.trim();

    // Ejercicio nuevo: primero se ofrece ponerle fotos (un paso, no un diálogo
    // encima de otro). El segundo toque ya guarda, con o sin fotos.
    if (_nombreEsNuevo && !_pidiendoFotos) {
      setState(() {
        _pidiendoFotos = true;
        _error = null;
      });
      return;
    }

    setState(() {
      _guardando = true;
      _error = null;
    });

    var catalogoId = _elegido?.id;
    var imagenUrl = _elegido?.imagenUrl;
    var videoUrl = _elegido?.videoUrl;

    if (_elegido == null) {
      // Se crea en el catálogo (privado del cliente). Si falla —sin conexión,
      // por ejemplo— el ejercicio igual se agrega como texto.
      final creado = await _repositorio.crear(
        nombre: nombre,
        imagenesBase64: await _fotosEnBase64(),
      );
      catalogoId = creado?.id;
      imagenUrl = creado?.imagenUrl;

      // El video va aparte y después: necesita el id del ejercicio y viaja por
      // multipart. Si falla, el ejercicio ya quedó creado y solo se avisa.
      final video = _video;
      if (creado != null && video != null) {
        final error = await _repositorio.subirVideo(creado.id, video);
        if (!mounted) return;
        if (error != null) {
          mostrarMensaje(context, error, tipo: TipoMensaje.advertencia);
        } else {
          // El backend devuelve el ejercicio actualizado, pero basta con
          // recargarlo para quedarnos con la URL definitiva del video.
          final actualizado = await _repositorio.buscar(nombre);
          videoUrl = actualizado
              .where((e) => e.id == creado.id)
              .map((e) => e.videoUrl)
              .firstOrNull;
        }
      }
    }

    if (!mounted) return;
    Navigator.of(context).pop(EjercicioElegido(
      nombre: nombre,
      series: int.tryParse(_seriesCtrl.text.trim()) ?? 0,
      repeticiones: int.tryParse(_repsCtrl.text.trim()) ?? 0,
      observaciones: _obsCtrl.text.trim().isEmpty ? null : _obsCtrl.text.trim(),
      catalogoId: catalogoId,
      imagenUrl: imagenUrl,
      videoUrl: videoUrl,
    ));
  }

  Future<List<String>> _fotosEnBase64() async {
    final lista = <String>[];
    for (final foto in _fotos) {
      final bytes = await foto.readAsBytes();
      lista.add('data:image/jpeg;base64,${base64Encode(bytes)}');
    }
    return lista;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppEspaciado.lg,
        right: AppEspaciado.lg,
        top: AppEspaciado.lg,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppEspaciado.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Agregar ejercicio',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal)),
            const SizedBox(height: AppEspaciado.md),

            TextField(
              controller: _nombreCtrl,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: 'Nombre del ejercicio',
                hintText: 'Escribe y elige de la lista',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _buscando
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : (_elegido != null
                        ? const Icon(Icons.check_circle, color: AppColores.exito)
                        : null),
              ),
              onChanged: _alEscribir,
            ),

            if (_sugerencias.isNotEmpty && _elegido == null) ...[
              const SizedBox(height: AppEspaciado.sm),
              _listaSugerencias(),
            ],

            if (_elegido != null) ...[
              const SizedBox(height: AppEspaciado.sm),
              _tarjetaElegido(_elegido!),
            ],

            if (_pidiendoFotos && _elegido == null) ...[
              const SizedBox(height: AppEspaciado.md),
              _bloqueFotos(),
            ],

            const SizedBox(height: AppEspaciado.md),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _seriesCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Series'),
                  ),
                ),
                const SizedBox(width: AppEspaciado.md),
                Expanded(
                  child: TextField(
                    controller: _repsCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Repeticiones'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: _obsCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration:
                  const InputDecoration(labelText: 'Observaciones (opcional)'),
            ),

            if (_error != null) ...[
              const SizedBox(height: AppEspaciado.md),
              _aviso(_error!, AppColores.advertencia, Icons.warning_amber_rounded),
            ],

            const SizedBox(height: AppEspaciado.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _guardando ? null : _guardar,
                child: _guardando
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(_textoBotonGuardar()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _textoBotonGuardar() {
    if (_pidiendoFotos && _elegido == null) {
      return _fotos.isEmpty ? 'Guardar sin fotos' : 'Guardar con ${_fotos.length} foto(s)';
    }
    return 'Guardar';
  }

  Widget _listaSugerencias() {
    return Container(
      constraints: const BoxConstraints(maxHeight: 220),
      decoration: BoxDecoration(
        border: Border.all(color: AppColores.borde),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: ListView.separated(
        shrinkWrap: true,
        padding: EdgeInsets.zero,
        itemCount: _sugerencias.length,
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final e = _sugerencias[i];
          return ListTile(
            dense: true,
            leading: _miniatura(e.imagenUrl),
            title: Text(e.nombre,
                style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal)),
            subtitle: Text(
              [
                if (e.grupoMuscular != null) e.grupoMuscular!,
                if (e.tieneVideo) '▶ Con video',
                if (e.esPropio) 'Tuyo',
              ].join(' · '),
              style: const TextStyle(fontSize: 12),
            ),
            onTap: () => _elegirSugerencia(e),
          );
        },
      ),
    );
  }

  Widget _tarjetaElegido(EjercicioCatalogo e) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColores.exito.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        children: [
          _miniatura(e.imagenUrl),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(e.nombre,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal)),
                Text(
                  e.imagenUrl == null
                      ? 'Del catálogo del gimnasio'
                      : 'Con imagen de referencia',
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textoSecundario),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Elegir otro',
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _elegido = null;
              _buscar(_nombreCtrl.text);
            }),
          ),
        ],
      ),
    );
  }

  Widget _bloqueFotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _aviso(
          '"${_nombreCtrl.text.trim()}" es nuevo. Agrégale fotos para reconocerlo '
          'la próxima vez (opcional).',
          AppColores.azul,
          Icons.info_outline,
        ),
        const SizedBox(height: AppEspaciado.sm),
        if (_fotos.isNotEmpty)
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _fotos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (_, i) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    child: Image.file(_fotos[i],
                        width: 76, height: 76, fit: BoxFit.cover),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: GestureDetector(
                      onTap: () => setState(() => _fotos.removeAt(i)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close,
                            size: 14, color: Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: AppEspaciado.sm),
        OutlinedButton.icon(
          onPressed: _agregarFotos,
          icon: const Icon(Icons.add_a_photo_outlined, size: 18),
          label: Text(_fotos.isEmpty ? 'Agregar fotos' : 'Agregar más fotos'),
        ),
        const SizedBox(height: AppEspaciado.md),
        _bloqueVideo(),
      ],
    );
  }

  Widget _bloqueVideo() {
    final video = _video;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'VIDEO DE EJECUCIÓN (OPCIONAL)',
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: AppColores.textoSecundario,
          ),
        ),
        const SizedBox(height: AppEspaciado.sm),
        if (video != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColores.exito.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Row(
              children: [
                const Icon(Icons.videocam, size: 20, color: AppColores.exito),
                const SizedBox(width: AppEspaciado.sm),
                Expanded(
                  child: Text(
                    video.path.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Quitar video',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => setState(() => _video = null),
                ),
              ],
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: _eligiendoVideo ? null : _menuVideo,
            icon: _eligiendoVideo
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.videocam_outlined, size: 18),
            label: Text(_eligiendoVideo ? 'Revisando...' : 'Agregar video'),
          ),
        if (_errorVideo != null) ...[
          const SizedBox(height: AppEspaciado.sm),
          _aviso(_errorVideo!, AppColores.error, Icons.error_outline),
        ] else ...[
          const SizedBox(height: 6),
          const Text(
            'Un clip corto de máximo $_maxSegundosVideo segundos con la técnica.',
            style: TextStyle(fontSize: 12, color: AppColores.textoSecundario),
          ),
        ],
      ],
    );
  }

  Widget _miniatura(String? url) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(Icons.fitness_center,
              size: 20, color: AppColores.textoSecundario)
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(Icons.fitness_center,
                  size: 20, color: AppColores.textoSecundario),
            ),
    );
  }

  Widget _aviso(String texto, Color color, IconData icono) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        children: [
          Icon(icono, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(texto,
                style: TextStyle(
                    color: color, fontSize: 12.5, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
