import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Pide activar "Alarmas y recordatorios" (Android 14+) para que el fin del
/// descanso suene a tiempo con el teléfono bloqueado. Mismo estilo que
/// [confirmarCerrarSesion]: foto de cabecera, ícono flotante y botones a lo
/// ancho. Devuelve `true` si el socio quiere activarlo.
Future<bool> pedirPermisoAlarma(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.6),
    builder: (_) => const _DialogoPermisoAlarma(),
  ).then((r) => r == true);
}

class _DialogoPermisoAlarma extends StatelessWidget {
  const _DialogoPermisoAlarma();

  @override
  Widget build(BuildContext context) {
    const alturaFoto = 130.0;
    const icono = 64.0;
    final color = AppColores.primario;

    return Dialog(
      backgroundColor: AppColores.superficie,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
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
                          'assets/imagenes/inicio/rutinas.jpg',
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
                                  color,
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
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColores.superficie,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.alarm_on_rounded,
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
                    'Que no se te pase el descanso',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Para que la alarma suene justo a tiempo aunque bloquees '
                    'el teléfono o salgas de la app, tu celular necesita un '
                    'permiso.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13.5,
                      height: 1.4,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    decoration: BoxDecoration(
                      color: AppColores.fondo,
                      borderRadius: BorderRadius.circular(AppEspaciado.radio),
                    ),
                    child: const Column(
                      children: [
                        _Paso(1, 'Toca "Activar alarma"'),
                        _Paso(2, 'Enciende "Alarmas y recordatorios"'),
                        _Paso(3, 'Vuelve a la app y sigue entrenando'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton.icon(
                      onPressed: () => Navigator.pop(context, true),
                      icon: const Icon(Icons.alarm_add_rounded, size: 20),
                      label: const Text(
                        'Activar alarma',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppEspaciado.radio,
                          ),
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
                          borderRadius: BorderRadius.circular(
                            AppEspaciado.radio,
                          ),
                        ),
                      ),
                      child: const Text(
                        'Ahora no',
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
      ),
    );
  }
}

/// Un paso numerado de la guía.
class _Paso extends StatelessWidget {
  final int numero;
  final String texto;

  const _Paso(this.numero, this.texto);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: AppColores.primario,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
