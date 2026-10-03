import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Tarjeta con foto de fondo, oscurecida con un degradado teñido del color de
/// la marca para que el texto blanco siempre se lea.
class FotoTarjeta extends StatelessWidget {
  final String foto;
  final Widget child;
  final double radio;
  final Alignment alineacion;
  final bool degradadoHorizontal;
  final VoidCallback? onTap;

  const FotoTarjeta({super.key,
    required this.foto,
    required this.child,
    required this.radio,
    this.alineacion = Alignment.center,
    this.degradadoHorizontal = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    final tinte = AppColores.primario;
    return Container(
      decoration: BoxDecoration(
        borderRadius: borde,
        border: Border.all(color: AppColores.destacado.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: tinte.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borde,
        child: Material(
          color: const Color(0xFF0B0F14),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset(
                    foto,
                    fit: BoxFit.cover,
                    alignment: alineacion,
                  ),
                ),
                Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: degradadoHorizontal
                            ? Alignment.centerLeft
                            : Alignment.topCenter,
                        end: degradadoHorizontal
                            ? Alignment.centerRight
                            : Alignment.bottomCenter,
                        colors: degradadoHorizontal
                            ? [
                                Color.alphaBlend(
                                  tinte.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.88),
                                ),
                                Colors.black.withValues(alpha: 0.55),
                                Colors.black.withValues(alpha: 0.05),
                              ]
                            : [
                                tinte.withValues(alpha: 0.30),
                                Colors.black.withValues(alpha: 0.35),
                                Color.alphaBlend(
                                  tinte.withValues(alpha: 0.35),
                                  Colors.black.withValues(alpha: 0.88),
                                ),
                              ],
                        stops: degradadoHorizontal
                            ? const [0.0, 0.55, 1.0]
                            : const [0.0, 0.45, 1.0],
                      ),
                    ),
                  ),
                ),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
