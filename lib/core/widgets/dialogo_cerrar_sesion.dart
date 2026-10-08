import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Confirmación de cierre de sesión con el estilo de las pantallas nuevas:
/// foto de cabecera, ícono flotante y botones a lo ancho. La usan el admin y
/// el socio. Devuelve `true` si confirma.
Future<bool> confirmarCerrarSesion(BuildContext context, {String nombre = ''}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => _DialogoCerrarSesion(nombre: nombre.split(' ').first),
  ).then((r) => r == true);
}

class _DialogoCerrarSesion extends StatelessWidget {
  final String nombre;

  const _DialogoCerrarSesion({required this.nombre});

  @override
  Widget build(BuildContext context) {
    const alturaFoto = 130.0;
    const icono = 64.0;
    final rojo = AppColores.error;

    return Dialog(
      backgroundColor: AppColores.superficie,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: alturaFoto + icono / 2,
            child: Stack(
              children: [
                Positioned.fill(
                  bottom: icono / 2,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(
                        'assets/imagenes/inicio/motivacion.jpg',
                        fit: BoxFit.cover,
                      ),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.1),
                              Color.lerp(
                                AppColores.primario,
                                Colors.black,
                                0.4,
                              )!.withValues(alpha: 0.85),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: icono,
                    height: icono,
                    decoration: BoxDecoration(
                      color: rojo,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColores.superficie,
                        width: 4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: rojo.withValues(alpha: 0.35),
                          blurRadius: 14,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.logout_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 14, 22, 18),
            child: Column(
              children: [
                Text(
                  nombre.isEmpty ? '¿Ya te vas?' : '¿Ya te vas, $nombre?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Tus datos quedan guardados. Para volver a entrar '
                  'tendrás que iniciar sesión otra vez.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: rojo,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppEspaciado.radio),
                      ),
                    ),
                    child: const Text(
                      'Sí, cerrar sesión',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  height: 46,
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColores.textoPrincipal,
                      backgroundColor: AppColores.fondo,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppEspaciado.radio),
                      ),
                    ),
                    child: const Text(
                      'Quedarme',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
