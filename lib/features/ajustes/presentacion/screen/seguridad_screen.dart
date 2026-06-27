import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ajustes/presentacion/controlador/controlador_ajustes.dart';

/// "Seguridad": permite al usuario cambiar su contraseña. Verifica la
/// contraseña actual antes de establecer la nueva.
class SeguridadScreen extends StatefulWidget {
  const SeguridadScreen({super.key});

  @override
  State<SeguridadScreen> createState() => _SeguridadScreenState();
}

class _SeguridadScreenState extends State<SeguridadScreen> {
  final _controlador = ControladorAjustes();
  final _formKey = GlobalKey<FormState>();

  final _actualController = TextEditingController();
  final _nuevaController = TextEditingController();
  final _confirmarController = TextEditingController();

  bool _verActual = false;
  bool _verNueva = false;
  bool _verConfirmar = false;
  bool _isSaving = false;

  @override
  void dispose() {
    _actualController.dispose();
    _nuevaController.dispose();
    _confirmarController.dispose();
    super.dispose();
  }

  Future<void> _cambiar() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _isSaving = true);
    try {
      // 1) Verificamos la contraseña actual antes de cambiarla.
      final correcta =
          await _controlador.verificarPassword(_actualController.text);
      if (!mounted) return;
      if (!correcta) {
        setState(() => _isSaving = false);
        mostrarMensaje(context, 'La contraseña actual es incorrecta',
            tipo: TipoMensaje.error);
        return;
      }

      // 2) Establecemos la nueva contraseña.
      final error = await _controlador.cambiarPassword(_nuevaController.text);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (error == null) {
        mostrarMensaje(context, 'Contraseña actualizada correctamente',
            tipo: TipoMensaje.exito);
        Navigator.of(context).pop();
      } else {
        mostrarMensaje(context, error, tipo: TipoMensaje.error);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      mostrarMensaje(context, 'No se pudo cambiar la contraseña',
          tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Seguridad')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppEspaciado.md),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const EncabezadoSeccion(
                titulo: 'Cambiar contraseña',
                subtitulo: 'Protege el acceso a tu cuenta',
              ),
              const SizedBox(height: AppEspaciado.lg),
              _etiqueta('Contraseña actual'),
              TextFormField(
                controller: _actualController,
                obscureText: !_verActual,
                decoration: InputDecoration(
                  hintText: '••••••••',
                  suffixIcon: _toggleVer(
                      _verActual, () => setState(() => _verActual = !_verActual)),
                ),
                validator: (v) => v == null || v.isEmpty
                    ? 'Ingresa tu contraseña actual'
                    : null,
              ),
              const SizedBox(height: AppEspaciado.md),
              _etiqueta('Nueva contraseña'),
              TextFormField(
                controller: _nuevaController,
                obscureText: !_verNueva,
                decoration: InputDecoration(
                  hintText: 'Mínimo 6 caracteres',
                  suffixIcon: _toggleVer(
                      _verNueva, () => setState(() => _verNueva = !_verNueva)),
                ),
                validator: (v) {
                  if (v == null || v.isEmpty) return 'Ingresa la nueva contraseña';
                  if (v.length < 6) return 'Debe tener al menos 6 caracteres';
                  if (v == _actualController.text) {
                    return 'La nueva contraseña debe ser distinta a la actual';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppEspaciado.md),
              _etiqueta('Confirmar nueva contraseña'),
              TextFormField(
                controller: _confirmarController,
                obscureText: !_verConfirmar,
                decoration: InputDecoration(
                  hintText: 'Repite la nueva contraseña',
                  suffixIcon: _toggleVer(_verConfirmar,
                      () => setState(() => _verConfirmar = !_verConfirmar)),
                ),
                validator: (v) => v != _nuevaController.text
                    ? 'Las contraseñas no coinciden'
                    : null,
              ),
              const SizedBox(height: AppEspaciado.xl),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _cambiar,
                icon: _isSaving
                    ? const SizedBox.shrink()
                    : const Icon(Icons.lock_reset),
                label: _isSaving
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2.5),
                      )
                    : const Text('Cambiar Contraseña'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _toggleVer(bool visible, VoidCallback onTap) {
    return IconButton(
      icon: Icon(
        visible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
        color: AppColores.textoSecundario,
      ),
      onPressed: onTap,
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
