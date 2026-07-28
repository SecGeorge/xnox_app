import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/login/dominio/entidades/sucursal.dart';
import 'package:xnox_app/features/login/presentacion/controlador/controlador_registro.dart';

/// Formulario de registro para nuevos clientes: solo DNI y contraseña.
class RegistroClienteScreen extends StatefulWidget {
  const RegistroClienteScreen({super.key});

  @override
  State<RegistroClienteScreen> createState() => _RegistroClienteScreenState();
}

class _RegistroClienteScreenState extends State<RegistroClienteScreen> {
  final _documentoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmarCtrl = TextEditingController();

  final _controlador = ControladorRegistro();
  List<Sucursal> _sucursales = [];
  Sucursal? _sucursalSeleccionada;
  bool _isLoading = false;
  bool _verPassword = false;
  bool _cargandoSucursales = true;
  String? _sucursalesError;

  /// Código de gimnasio que ya escribió el usuario al abrir la app por primera
  /// vez; no se le vuelve a pedir aquí.
  String _codigoGimnasio = '';

  @override
  void initState() {
    super.initState();
    _cargarSucursales();
  }

  @override
  void dispose() {
    _documentoCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmarCtrl.dispose();
    super.dispose();
  }

  /// Sucursales del gimnasio guardado. Se usa el código que reconoce ese
  /// servidor (`codigoParaBackend`), que no siempre es el que escribió el
  /// usuario.
  Future<void> _cargarSucursales() async {
    final empresa = await EmpresaDao.instancia.activa();
    if (!mounted) return;
    if (empresa == null) {
      setState(() {
        _cargandoSucursales = false;
        _sucursalesError = 'No hay un gimnasio configurado en esta app';
      });
      return;
    }
    _codigoGimnasio = empresa.codigoParaBackend;
    final sucursales = await _controlador.cargarSucursales(_codigoGimnasio);
    if (!mounted) return;
    setState(() {
      _cargandoSucursales = false;
      _sucursales = sucursales;
      _sucursalSeleccionada = sucursales.length == 1 ? sucursales.first : null;
      _sucursalesError =
          sucursales.isEmpty ? 'No hay sucursales disponibles' : null;
    });
  }

  Future<void> _registrar() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    final result = await _controlador.registrar(
      codigoGimnasio: _codigoGimnasio,
      idSucursal: _sucursalSeleccionada?.id,
      documento: _documentoCtrl.text,
      password: _passwordCtrl.text,
      confirmar: _confirmarCtrl.text,
    );
    if (!mounted) return;
    setState(() => _isLoading = false);

    // Un solo aviso a la vez: los toques repetidos reemplazan el anterior en
    // lugar de apilar varios.
    mostrarMensajeGlobal(
      result.message,
      tipo: result.success ? TipoMensaje.exito : TipoMensaje.error,
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
