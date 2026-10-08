import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
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
    final inicial = _nombre.trim().isNotEmpty
        ? _nombre.trim()[0].toUpperCase()
        : '?';
    return PantallaApp(
      children: [
        const CabeceraApp(titulo: 'Mi perfil', subtitulo: 'Datos de tu cuenta'),
        const SizedBox(height: AppEspaciado.md + 4),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else ...[
          SizedBox(
            height: 190,
            child: FotoTarjeta(
              foto: FotosApp.hombros,
              alineacion: const Alignment(0.4, -0.4),
              radio: AppEspaciado.radio + 6,
              degradadoHorizontal: true,
              child: Padding(
                padding: const EdgeInsets.all(AppEspaciado.md + 2),
                child: Row(
                  children: [
                    Container(
                      width: 76,
                      height: 76,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.16),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.5),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        inicial,
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: AppEspaciado.md),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'USUARIO',
                            style: TextStyle(
                              fontSize: 11.5,
                              letterSpacing: 1.3,
                              fontWeight: FontWeight.w800,
                              color: AppColores.destacado,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _nombre.isEmpty ? 'Usuario' : _nombre,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              height: 1.1,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppEspaciado.lg),
          const TituloSeccion(icono: Icons.badge_rounded, titulo: 'Cuenta'),
          GrupoFilas(
            filas: [
              FilaApp(
                inicio: const IconoSuave(Icons.person_rounded),
                titulo: _nombre.isEmpty ? 'Usuario' : _nombre,
                subtitulo: 'Nombre de usuario',
              ),
              FilaApp(
                inicio: IconoSuave(_tipo.icono),
                titulo: _tipo.etiqueta,
                subtitulo: 'Perfil con el que iniciaste sesión',
              ),
            ],
          ),
        ],
      ],
    );
  }
}
