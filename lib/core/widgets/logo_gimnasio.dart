import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';

/// Logo del gimnasio al que apunta la app, sin marco: solo la imagen. Si no
/// tiene logo o no carga, muestra la inicial de su nombre con el color de marca.
///
/// Si el logo de la web es blanco y se pierde sobre fondos claros, el admin
/// sube otro solo para la app (Ajustes → Logo y colores de la app).
class LogoGimnasio extends StatelessWidget {
  final double tamano;

  /// Muestra el nombre del gimnasio al lado del logo.
  final bool conNombre;
  final Color? colorNombre;

  const LogoGimnasio({
    super.key,
    this.tamano = 40,
    this.conNombre = false,
    this.colorNombre,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MarcaGimnasio>(
      valueListenable: ControladorMarca.instancia.marca,
      builder: (context, marca, _) {
        final logo = _Logo(marca: marca, tamano: tamano);
        if (!conNombre || (marca.nombre ?? '').isEmpty) return logo;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: AppEspaciado.sm + 2),
            Flexible(
              child: Text(
                marca.nombre!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: tamano * 0.42,
                  fontWeight: FontWeight.w700,
                  color: colorNombre ?? AppColores.textoPrincipal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Logo extends StatelessWidget {
  final MarcaGimnasio marca;
  final double tamano;

  const _Logo({required this.marca, required this.tamano});

  @override
  Widget build(BuildContext context) {
    final nombre = marca.nombre ?? '';
    final inicial = Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColores.primario.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(tamano * 0.28),
      ),
      child: Text(
        nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: tamano * 0.45,
          fontWeight: FontWeight.w800,
          color: AppColores.primario,
        ),
      ),
    );
    final url = marca.logoUrl;
    if (url == null || url.isEmpty) {
      return nombre.isEmpty ? const SizedBox.shrink() : inicial;
    }
    return SizedBox(
      width: tamano,
      height: tamano,
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => inicial,
      ),
    );
  }
}
