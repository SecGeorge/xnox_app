import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Títulos sobre fondo oscuro o foto: gruesos e inclinados como el logo.
const tituloXnet = TextStyle(
  fontWeight: FontWeight.w900,
  fontStyle: FontStyle.italic,
  letterSpacing: 0.3,
  color: Colors.white,
);

/// Fondo oscuro del reverso de las tarjetas y de los banners del inicio. Es
/// casi negro en XNET y toma el tinte de la marca en los demás gimnasios.
class FondoXnet extends StatelessWidget {
  final Widget child;
  final double radio;
  final VoidCallback? onTap;

  const FondoXnet({
    super.key,
    required this.child,
    required this.radio,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borde = BorderRadius.circular(radio);
    final fondo = Color.alphaBlend(
      AppColores.primario.withValues(alpha: 0.35),
      const Color(0xFF0B0F14),
    );
    return Container(
      decoration: BoxDecoration(
        borderRadius: borde,
        border: Border.all(color: AppColores.destacado.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: AppColores.primario.withValues(alpha: 0.22),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: borde,
        child: Material(
          color: fondo,
          child: InkWell(onTap: onTap, child: child),
        ),
      ),
    );
  }
}
