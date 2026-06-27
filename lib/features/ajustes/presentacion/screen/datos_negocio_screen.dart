import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/datos_negocio.dart';
import 'package:xnox_app/features/ajustes/presentacion/controlador/controlador_ajustes.dart';

/// "Datos del negocio": muestra y permite editar el nombre, teléfono y
/// dirección del gimnasio (tabla `ajustes` del backend).
class DatosNegocioScreen extends StatefulWidget {
  const DatosNegocioScreen({super.key});

  @override
  State<DatosNegocioScreen> createState() => _DatosNegocioScreenState();
}

class _DatosNegocioScreenState extends State<DatosNegocioScreen> {
  final _controlador = ControladorAjustes();
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  DatosNegocio? _datos;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final datos = await _controlador.obtenerDatosNegocio();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _nombreController.text = datos.nombre;
        _telefonoController.text = datos.telefono;
        _direccionController.text = datos.direccion;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarMensaje(context, 'No se pudieron cargar los datos del negocio',
          tipo: TipoMensaje.error);
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final base = _datos ?? DatosNegocio.vacio();
    final actualizado = base.copyWith(
      nombre: _nombreController.text.trim(),
      telefono: _telefonoController.text.trim(),
      direccion: _direccionController.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      final error = await _controlador.guardarDatosNegocio(actualizado);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (error == null) {
        mostrarMensaje(context, 'Datos del negocio actualizados',
            tipo: TipoMensaje.exito);
        Navigator.of(context).pop();
      } else {
        mostrarMensaje(context, error, tipo: TipoMensaje.error);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      mostrarMensaje(context, 'No se pudo guardar. Intenta nuevamente.',
          tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Datos del negocio')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(AppEspaciado.md),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildLogo(),
                    const SizedBox(height: AppEspaciado.lg),
                    _etiqueta('Nombre del negocio'),
                    TextFormField(
                      controller: _nombreController,
                      textCapitalization: TextCapitalization.words,
                      decoration:
                          const InputDecoration(hintText: 'Ej. Gimnasio XNOX'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa el nombre del negocio'
                          : null,
                    ),
                    const SizedBox(height: AppEspaciado.md),
                    _etiqueta('Teléfono'),
                    TextFormField(
                      controller: _telefonoController,
                      keyboardType: TextInputType.phone,
                      decoration:
                          const InputDecoration(hintText: 'Ej. 987654321'),
                      validator: (v) => v == null || v.trim().isEmpty
                          ? 'Ingresa el teléfono'
                          : null,
                    ),
                    const SizedBox(height: AppEspaciado.md),
                    _etiqueta('Dirección'),
                    TextFormField(
                      controller: _direccionController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                          hintText: 'Ej. Av. Principal 123'),
                      maxLines: 2,
                    ),
                    const SizedBox(height: AppEspaciado.xl),
                    ElevatedButton.icon(
                      onPressed: _isSaving ? null : _guardar,
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
                          : const Text('Guardar Cambios'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildLogo() {
    final url = _datos?.logoUrl;
    return Center(
      child: Container(
        width: 110,
        height: 110,
        decoration: BoxDecoration(
          color: AppColores.superficie,
          borderRadius: BorderRadius.circular(AppEspaciado.radio),
          border: Border.all(color: AppColores.borde),
        ),
        clipBehavior: Clip.antiAlias,
        child: url != null
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (c, e, s) => _logoPlaceholder(),
              )
            : _logoPlaceholder(),
      ),
    );
  }

  Widget _logoPlaceholder() {
    return const Center(
      child: Icon(Icons.business, size: 44, color: AppColores.vencido),
    );
  }

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
