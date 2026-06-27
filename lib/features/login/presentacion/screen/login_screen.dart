import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_shell.dart';
import 'package:xnox_app/features/login/presentacion/controlador/controlador_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';
import 'package:xnox_app/features/login/presentacion/screen/registro_cliente_screen.dart';
import 'package:xnox_app/features/dashboard/presentacion/screen/dashboard_screen.dart';

class LoginScreen extends StatefulWidget {

  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usuarioController = TextEditingController();
  final _passwordController = TextEditingController();
  final _loginController = ControladorLogin();
  bool _isLoading = false;
  bool _ocultarPassword = true;
  // El texto del botón solo se muestra cuando está totalmente expandido, para
  // que no aparezca apretado dentro del círculo durante la animación.
  bool _mostrarTexto = true;
  TipoUsuario _tipoUsuario = TipoUsuario.administrador;

  void _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _isLoading = true;
      _mostrarTexto = false;
    });

    final result = await _loginController.login(
      _usuarioController.text.trim(),
      _passwordController.text.trim(),
      _tipoUsuario,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result.success) {
      final destino = _tipoUsuario == TipoUsuario.cliente
          ? const ClienteShell()
          : const DashboardScreen();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => destino),
      );
    } else {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message), backgroundColor: Colors.red),
      );
    }
  }

  void _irARegistro() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegistroClienteScreen()),
    );
  }

  @override
  void dispose() {
    _usuarioController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Selector segmentado para elegir el tipo de usuario.
  Widget _buildSelectorTipo() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF1F3F8),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: TipoUsuario.values.map((tipo) {
          final seleccionado = _tipoUsuario == tipo;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tipoUsuario = tipo),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: seleccionado ? const Color(0xFF1A2B4C) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      tipo.icono,
                      size: 18,
                      color: seleccionado ? Colors.white : Colors.black54,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      tipo.etiqueta,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: seleccionado ? Colors.white : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Text(
                'XNOX-SOFT',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A2B4C),
                ),
              ),
              const Text(
                'OPTIMIZA / CRECE / LIDERA',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.black54,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 40),
              const Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: 400,
                child: Column(
                  children: [
                    _buildSelectorTipo(),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _usuarioController,
                      decoration: InputDecoration(
                        labelText: 'Usuario',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _passwordController,
                      obscureText: _ocultarPassword,
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _ocultarPassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                            color: Colors.black54,
                          ),
                          tooltip: _ocultarPassword
                              ? 'Mostrar contraseña'
                              : 'Ocultar contraseña',
                          onPressed: () => setState(
                              () => _ocultarPassword = !_ocultarPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: () {},
                        child: const Text(
                          '¿Olvidaste tu contraseña?',
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    LayoutBuilder(
                      builder: (context, constraints) => Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        height: 50,
                        width: _isLoading ? 50 : constraints.maxWidth,
                        onEnd: () {
                          // Al terminar de expandirse, recién mostramos el texto.
                          if (!_isLoading && !_mostrarTexto) {
                            setState(() => _mostrarTexto = true);
                          }
                        },
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A2B4C),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF1A2B4C),
                            disabledForegroundColor: Colors.white,
                            padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(
                              borderRadius:
                                  BorderRadius.circular(_isLoading ? 25 : 8),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                            surfaceTintColor: Colors.transparent,
                          ).copyWith(
                            overlayColor: WidgetStateProperty.all(
                              Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                          child: _isLoading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.4,
                                ),
                              )
                            : _mostrarTexto
                                ? const Text(
                                    'INGRESAR',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 0.2,
                                    ),
                                  )
                                : const SizedBox.shrink(),
                        ),
                      ),
                      ),
                    ),
                    if (_tipoUsuario == TipoUsuario.cliente) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('¿No tienes cuenta?',
                              style: TextStyle(
                                  fontSize: 13, color: Colors.black54)),
                          TextButton(
                            onPressed: _irARegistro,
                            child: const Text(
                              'Regístrate',
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColores.acento),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 40),
                    const Text(
                      'Contactanos por WhatsApp 938197971',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
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
}
