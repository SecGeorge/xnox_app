import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Confirmación de salir del entrenamiento con temporizador, con el mismo
/// estilo que [confirmarCerrarSesion]: foto de cabecera, ícono flotante y
/// botones a lo ancho. Devuelve `true` si confirma salir.
Future<bool> confirmarSalirEntrenamiento(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (ctx) => const _DialogoSalirEntrenamiento(),
  ).then((r) => r == true);
}

class _DialogoSalirEntrenamiento extends StatelessWidget {
  const _DialogoSalirEntrenamiento();

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
                        'assets/imagenes/inicio/rutina_hoy.jpg',
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
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 28,
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
                  '¿Salir del entrenamiento?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Se perderá el avance de esta sesión: series, rondas y '
                  'tiempos que llevas hasta ahora.',
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
                      'Sí, salir',
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
                      'Seguir entrenando',
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
