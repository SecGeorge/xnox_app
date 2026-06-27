import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
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
  State<FormularioPublicidadScreen> createState() => _FormularioPublicidadScreenState();
}

class _FormularioPublicidadScreenState extends State<FormularioPublicidadScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controlador = ControladorPublicidad();

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _fechaInicioController = TextEditingController();
  final _fechaFinController = TextEditingController();

  File? _imageFile;
  bool _isSaving = false;

  bool get _esEdicion => widget.publicidad != null;

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
    }
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
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
    // Comprimimos al seleccionar para que la campaña cargue rápido.
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 70,
    );
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
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
      );

      // Convertimos la imagen a base64 para enviarla al backend.
      String? imagenBase64;
      if (_imageFile != null) {
        final bytes = await _imageFile!.readAsBytes();
        imagenBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(_esEdicion ? 'Editar Publicidad' : 'Nueva Publicidad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEspaciado.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _etiqueta('Título'),
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(hintText: 'Ej. Promoción de verano'),
                validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppEspaciado.md),
              _etiqueta('Descripción'),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(hintText: 'Detalle de la campaña'),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: AppEspaciado.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Fecha Inicio'),
                        TextFormField(
                          controller: _fechaInicioController,
                          decoration: const InputDecoration(
                            hintText: 'Seleccionar',
                            prefixIcon: Icon(Icons.event),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _fechaInicioController),
                          validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppEspaciado.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _etiqueta('Fecha Fin'),
                        TextFormField(
                          controller: _fechaFinController,
                          decoration: const InputDecoration(
                            hintText: 'Seleccionar',
                            prefixIcon: Icon(Icons.event),
                          ),
                          readOnly: true,
                          onTap: () => _selectDate(context, _fechaFinController),
                          validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppEspaciado.lg),
              _etiqueta('Imagen'),
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 170,
                  decoration: BoxDecoration(
                    color: AppColores.superficie,
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    border: Border.all(
                      color: AppColores.borde,
                      width: 1.4,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover, width: double.infinity)
                      : (_esEdicion && widget.publicidad?.imagenUrl != null
                          ? Image.network(
                              widget.publicidad!.imagenUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (c, e, s) => _placeholderImagen(),
                            )
                          : _placeholderImagen()),
                ),
              ),
              const SizedBox(height: AppEspaciado.xl),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _save,
                icon: _isSaving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.save_outlined),
                label: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : Text(_esEdicion
                        ? 'Guardar Cambios'
                        : 'Guardar Publicidad'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholderImagen() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: const [
        Icon(Icons.add_photo_alternate_outlined,
            size: 40, color: AppColores.textoSecundario),
        SizedBox(height: AppEspaciado.sm),
        Text(
          'Toca para cargar una imagen',
          style: TextStyle(color: AppColores.textoSecundario),
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
        style: const TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColores.textoPrincipal,
        ),
      ),
    );
  }
}
