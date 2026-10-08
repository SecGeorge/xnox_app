import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';

/// Vista ampliada de una campaña: imagen grande, título y descripción.
class DetallePublicidadScreen extends StatelessWidget {
  final Publicidad publicidad;

  const DetallePublicidadScreen({super.key, required this.publicidad});

  @override
  Widget build(BuildContext context) {
    final p = publicidad;
    final formato = DateFormat('d MMM yyyy', 'es');
    final vigencia =
        '${formato.format(p.fechaInicio)} – ${formato.format(p.fechaFin)}';

    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          // Imagen grande (con zoom) o banner de marca, con atrás encima.
          Stack(
            children: [
              SizedBox(
                height: 280 + top,
                width: double.infinity,
                child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                    ? InteractiveViewer(
                        child: Image.network(
                          p.imagenUrl!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          cacheWidth: 1280,
                          loadingBuilder: (context, child, progress) =>
                              progress == null
                              ? child
                              : const Center(
                                  child: CircularProgressIndicator(),
                                ),
                          errorBuilder: (context, error, stack) => _banner(),
                        ),
                      )
                    : _banner(),
              ),
              Positioned(
                top: top + 8,
                left: 12,
                child: Material(
                  color: Colors.black.withValues(alpha: 0.4),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).maybePop(),
                    child: const SizedBox(
                      width: 42,
                      height: 42,
                      child: Icon(
                        Icons.arrow_back_rounded,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(AppEspaciado.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColores.primario.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 16,
                        color: AppColores.primario,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        vigencia,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppColores.primario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppEspaciado.md),
                Text(
                  p.titulo,
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: AppEspaciado.md),
                Text(
                  p.descripcion,
                  style: TextStyle(
                    fontSize: 15.5,
                    height: 1.45,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _banner() {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
      ),
      child: Center(
        child: Icon(
          Icons.campaign,
          color: AppColores.sobreRellenoSuave,
          size: 72,
        ),
      ),
    );
  }
}
