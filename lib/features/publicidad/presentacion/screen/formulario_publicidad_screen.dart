import 'package:flutter/material.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'dart:io';

class FormularioPublicidadScreen extends StatefulWidget {
  const FormularioPublicidadScreen({super.key});

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
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
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
        titulo: _tituloController.text,
        descripcion: _descripcionController.text,
        fechaInicio: DateTime.parse(_fechaInicioController.text),
        fechaFin: DateTime.parse(_fechaFinController.text),
      );

      Map<String, dynamic> imagenData = {};
      if (_imageFile != null) {
        imagenData = {
          'nombre': _imageFile!.path.split('/').last,
          'ruta': _imageFile!.path,
        };
      }

      final success = await _controlador.addPublicidad(publicidad, imagenData);
      if (success) {
        Navigator.of(context).pop(true);
      } else {
        throw Exception('Error al guardar la publicidad');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva Publicidad'),
        backgroundColor: const Color(0xFF1A2B4C),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _tituloController,
                decoration: const InputDecoration(labelText: 'Título', border: OutlineInputBorder()),
                validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descripcionController,
                decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder()),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty ? 'Campo requerido' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _fechaInicioController,
                      decoration: const InputDecoration(labelText: 'Fecha Inicio', border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: () => _selectDate(context, _fechaInicioController),
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      controller: _fechaFinController,
                      decoration: const InputDecoration(labelText: 'Fecha Fin', border: OutlineInputBorder()),
                      readOnly: true,
                      onTap: () => _selectDate(context, _fechaFinController),
                      validator: (value) => value == null || value.isEmpty ? 'Requerido' : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Center(
                child: Column(
                  children: [
                    _imageFile != null 
                      ? Image.file(_imageFile!, height: 150) 
                      : Container(height: 150, color: Colors.grey[200], child: const Icon(Icons.image, size: 50)),
                    TextButton.icon(
                      onPressed: _pickImage,
                      icon: const Icon(Icons.upload_file),
                      label: const Text('Cargar Imagen'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSaving ? null : _save,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1A2B4C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                ),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text('Guardar Publicidad'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
