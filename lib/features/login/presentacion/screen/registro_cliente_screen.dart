import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/login/dominio/entidades/sucursal.dart';
import 'package:xnox_app/features/login/presentacion/controlador/controlador_registro.dart';

/// Formulario de registro para nuevos clientes: solo DNI y contraseña.
class RegistroClienteScreen extends StatefulWidget {
  const RegistroClienteScreen({super.key});

  @override
  State<RegistroClienteScreen> createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> {
  final _codigoCtrl = TextEditingController();
  final _documentoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  final _controlador = ControladorRegistro();
  List<Sucursal> _sucursales = [];
  Sucursal? _sucursalSeleccionada;
  bool _isLoading = false;
  bool _verPassword = false;
  bool _cargandoSucursales = false;
  String? _sucursalesError;
  Timer? _debounceSucursales;

  @override
  void dispose() {
    _debounceSucursales?.cancel();
    _codigoCtrl.dispose();
    _documentoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  /// Al escribir el código de gimnasio, esperamos a que el usuario deje de
  /// teclear (debounce) y recargamos las sucursales de ese gimnasio.
  void _onCodigoChanged(String valor) {
    _debounceSucursales?.cancel();
    setState(() {
      _sucursalSeleccionada = null;
      _sucursales = [];
      _sucursalesError = null;
    });
    final codigo = valor.trim();
    if (codigo.isEmpty) return;
    _debounceSucursales =
        Timer(const Duration(milliseconds: 600), () => _cargarSucursales(codigo));
  }

  Future<void> _cargarSucursales(String codigo) async {
    setState(() => _cargandoSucursales = true);
    final sucursales = await _controlador.cargarSucursales(codigo);
    if (!mounted) return;
    setState(() {
      _cargandoSucursales = false;
      _sucursales = sucursales;
      _sucursalSeleccionada = null;
      _sucursalesError = sucursales.isEmpty
          ? 'Código inválido o sin sucursales disponibles'
          : null;
    });
  }

  Future<void> _registrar() async {
    setState(() => _isLoading = true);
    final result = await _controlador.registrar(
      codigoGimnasio: _codigoCtrl.text,
      idSucursal: _sucursalSeleccionada?.id,
      documento: _documentoCtrl.text,
      password: _passwordCtrl.text,
      confirmar: _confirmarCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? null : Colors.red,
      ),
    );

    // Si se creó la cuenta, volvemos al login para iniciar sesión.
    if (result.success) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Crear cuenta')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppEspaciado.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Regístrate como cliente',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textoPrincipal),
              ),
              const SizedBox(height: 4),
              const Text(
                'Crea tu cuenta con tu DNI y una contraseña.',
                style: TextStyle(
                    fontSize: 13.5, color: AppColores.textoSecundario),
              ),
              const SizedBox(height: AppEspaciado.xl),
              TextField(
                controller: _codigoCtrl,
                textCapitalization: TextCapitalization.characters,
                onChanged: _onCodigoChanged,
                decoration: InputDecoration(
                  labelText: 'Código de gimnasio',
                  helperText: 'Ingresa el código para ver las sucursales',
                  prefixIcon: const Icon(Icons.qr_code_2_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              DropdownButtonFormField<Sucursal>(
                initialValue: _sucursalSeleccionada,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Sucursal',
                  errorText: _sucursalesError,
                  prefixIcon: const Icon(Icons.store_outlined),
                  suffixIcon: _cargandoSucursales
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : null,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                hint: Text(_cargandoSucursales
                    ? 'Cargando sucursales...'
                    : 'Selecciona una sucursal'),
                items: _sucursales
                    .map((s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.nombre),
                        ))
                    .toList(),
                // Deshabilitado hasta que haya sucursales cargadas.
                onChanged: _sucursales.isEmpty
                    ? null
                    : (s) => setState(() => _sucursalSeleccionada = s),
              ),
              const SizedBox(height: AppEspaciado.md),
              TextField(
                controller: _documentoCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'DNI',
                  prefixIcon: const Icon(Icons.badge_outlined),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              TextField(
                controller: _passwordCtrl,
                obscureText: !_verPassword,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_verPassword
                        ? Icons.visibility_off
                        : Icons.visibility),
                    onPressed: () =>
                        setState(() => _verPassword = !_verPassword),
                  ),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              TextField(
                controller: _confirmarCtrl,
                obscureText: !_verPassword,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_outline),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: AppEspaciado.lg),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _registrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.primario,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('CREAR CUENTA',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Ya tengo cuenta · Iniciar sesión',
                      style: TextStyle(color: AppColores.acento)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
