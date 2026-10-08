import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'dart:convert';
import 'dart:io';

class FormularioPublicidadScreen extends StatefulWidget {
  /// Si se pasa [publicidad], la pantalla funciona en modo edición.
  final Publicidad? publicidad;

  const FormularioPublicidadScreen({super.key, this.publicidad});

  @override
  State<FormularioPublicidadScreen> createState() =>
      _FormularioPublicidadScreenState();
}

class _FormularioPublicidadScreenState
    extends State<FormularioPublicidadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controlador = ControladorPublicidad();

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();

  File? _imageFile;
  bool _isSaving = false;

  // Posición del encuadre: qué parte de la imagen completa se ve en el marco.
  // -1..1 en cada eje (Alignment). La imagen NO se recorta; solo se guarda esta
  // posición para mostrar la parte elegida.
  Alignment _encuadre = Alignment.center;

  bool get _esEdicion => widget.publicidad != null;

  bool get _tieneImagen =>
      _imageFile != null ||
      (_esEdicion && (widget.publicidad?.imagenUrl?.isNotEmpty ?? false));

  @override
  void initState() {
    super.initState();
    final p = widget.publicidad;
    if (p != null) {
      final fmt = DateFormat('yyyy-MM-dd');
      _tituloController.text = p.titulo;
      _descripcionController.text = p.descripcion;
      _fechaInicioController.text = fmt.format(p.fechaInicio);
      _fechaFinController.text = fmt.format(p.fechaFin);
      _encuadre = p.alineacion; // conserva el encuadre guardado
    }
  }

  Future<void> _selectDate(
    BuildContext context,
    TextEditingController controller,
  ) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    // Se guarda la imagen COMPLETA (solo la reducimos para que cargue rápido).
    // El encuadre se elige después arrastrando la imagen dentro del marco.
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 75,
    );
    if (image == null) return;
    setState(() {
      _imageFile = File(image.path);
      _encuadre = Alignment.center; // imagen nueva -> encuadre centrado
    });
  }

  /// Actualiza el encuadre al arrastrar la imagen dentro del marco.
  /// [boxW]/[boxH] son el tamaño del marco; convierten el desplazamiento en
  /// pixeles a un cambio de [Alignment] (-1..1).
  void _arrastrarEncuadre(DragUpdateDetails d, double boxW, double boxH) {
    setState(() {
      final nx = (_encuadre.x - d.delta.dx * 2 / boxW).clamp(-1.0, 1.0);
      final ny = (_encuadre.y - d.delta.dy * 2 / boxH).clamp(-1.0, 1.0);
      _encuadre = Alignment(nx, ny);
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final publicidad = Publicidad(
        id: widget.publicidad?.id,
        titulo: _tituloController.text,
        descripcion: _descripcionController.text,
        fechaInicio: DateTime.parse(_fechaInicioController.text),
        fechaFin: DateTime.parse(_fechaFinController.text),
        encuadre:
            '${_encuadre.x.toStringAsFixed(2)},${_encuadre.y.toStringAsFixed(2)}',
      );

      // Convertimos la imagen a base64 para enviarla al backend.
      String? imagenBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imagenBase64 = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      }

      final success = _esEdicion
          ? await _controlador.editarPublicidad(publicidad, imagenBase64)
          : await _controlador.addPublicidad(publicidad, imagenBase64);
      if (!mounted) return;
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Error al guardar la publicidad');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: PieBoton(
        texto: _esEdicion ? 'Guardar cambios' : 'Publicar campaña',
        icono: Icons.check_rounded,
        cargando: _isSaving,
        onPressed: _save,
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppEspaciado.md),
            children: [
              CabeceraApp(
                titulo: _esEdicion ? 'Editar publicidad' : 'Nueva publicidad',
                subtitulo: 'Se mostrará como novedad en la app del socio',
              ),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(icono: Icons.image_rounded, titulo: 'Imagen'),
              _selectorImagen(),
              if (_tieneImagen) ...[
                const SizedBox(height: AppEspaciado.sm),
                Row(
                  children: [
                    const Icon(
                      Icons.open_with_rounded,
                      size: 16,
                      color: AppColores.textoSecundario,
                    ),
                    const SizedBox(width: 6),
                    const Expanded(
                      child: Text(
                        'Arrastra la imagen para elegir qué parte se ve',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Cambiar'),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.edit_note_rounded,
                titulo: 'Contenido',
              ),
              TarjetaPlana(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _etiqueta('Título'),
                    TextFormField(
                      controller: _tituloController,
                      decoration: const InputDecoration(
                        hintText: 'Ej. Promoción de verano',
                      ),
                      validator: (value) => value == null || value.isEmpty
                          ? 'Campo requerido'
                          : null,
                    ),
                    const SizedBox(height: AppEspaciado.md),
                    _etiqueta('Descripción'),
                    TextFormField(
                      controller: _descripcionController,
                      decoration: const InputDecoration(
                        hintText: 'Detalle de la campaña',
                      ),
                      maxLines: 3,
                      validator: (value) => value == null || value.isEmpty
                          ? 'Campo requerido'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.date_range_rounded,
                titulo: 'Vigencia',
              ),
              TarjetaPlana(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _etiqueta('Desde'),
                          TextFormField(
                            controller: _fechaInicioController,
                            decoration: const InputDecoration(
                              hintText: 'Seleccionar',
                              prefixIcon: Icon(Icons.event_rounded),
                            ),
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _fechaInicioController),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppEspaciado.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _etiqueta('Hasta'),
                          TextFormField(
                            controller: _fechaFinController,
                            decoration: const InputDecoration(
                              hintText: 'Seleccionar',
                              prefixIcon: Icon(Icons.event_available_rounded),
                            ),
                            readOnly: true,
                            onTap: () =>
                                _selectDate(context, _fechaFinController),
                            validator: (value) => value == null || value.isEmpty
                                ? 'Requerido'
                                : null,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Marco de la publicidad. Muestra la imagen completa con [BoxFit.cover] y la
  /// posición [_encuadre]; al arrastrar se cambia qué parte se ve. Si no hay
  /// imagen, toca para cargar una.
  Widget _selectorImagen() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = w / AppEspaciado.publicidadRatio;
        return GestureDetector(
          onTap: _tieneImagen ? null : _pickImage,
          onPanUpdate: _tieneImagen ? (d) => _arrastrarEncuadre(d, w, h) : null,
          child: Container(
            width: w,
            height: h,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
              border: Border.all(
                color: AppColores.primario.withValues(alpha: 0.25),
                width: 1.4,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: _imagenMarco(),
          ),
        );
      },
    );
  }

  Widget _imagenMarco() {
    if (_imageFile != null) {
      return Image.file(
        _imageFile!,
        fit: BoxFit.cover,
        alignment: _encuadre,
        width: double.infinity,
        height: double.infinity,
      );
    }
    if (_esEdicion && (widget.publicidad?.imagenUrl?.isNotEmpty ?? false)) {
      return Image.network(
        widget.publicidad!.imagenUrl!,
        fit: BoxFit.cover,
        alignment: _encuadre,
        width: double.infinity,
        height: double.infinity,
        errorBuilder: (c, e, s) => _placeholderImagen(),
      );
    }
    return _placeholderImagen();
  }

  Widget _placeholderImagen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const IconoSuave(
          Icons.add_photo_alternate_rounded,
          tamano: 56,
          circular: true,
        ),
        const SizedBox(height: AppEspaciado.sm),
        Text(
          'Toca para cargar una imagen',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: AppColores.textoPrincipal,
          ),
        ),
        const Text(
          'Formato horizontal, como un banner',
          style: TextStyle(fontSize: 12, color: AppColores.textoSecundario),
        ),
      ],
    );
  }

  // En este apartado colocar siempre la etiqueta
  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColores.textoPrincipal,
        ),
      ),
    );
  }
}
