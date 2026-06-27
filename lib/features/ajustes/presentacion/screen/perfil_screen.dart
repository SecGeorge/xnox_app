import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';

/// "Mi perfil": muestra únicamente el nombre del usuario y el perfil (rol)
/// con el que inició sesión.
class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String _nombre = '';
  TipoUsuario _tipo = TipoUsuario.administrador;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _nombre = prefs.getString('usuarioNombre') ?? '';
      _tipo = TipoUsuario.desdeTexto(prefs.getString('tipoUsuario'));
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Mi perfil')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(AppEspaciado.md),
              children: [
                _buildTarjeta(),
              ],
            ),
    );
  }

  Widget _buildTarjeta() {
    final inicial =
        _nombre.trim().isNotEmpty ? _nombre.trim()[0].toUpperCase() : '?';
    return TarjetaApp(
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColores.primario.withValues(alpha: 0.10),
            child: Text(
              inicial,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.bold,
                color: AppColores.primario,
              ),
            ),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _nombre.isEmpty ? 'Usuario' : _nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(_tipo.icono,
                        size: 16, color: AppColores.textoSecundario),
                    const SizedBox(width: 4),
                    Text(
                      _tipo.etiqueta,
                      style: const TextStyle(
                        fontSize: 13.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
