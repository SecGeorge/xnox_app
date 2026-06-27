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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text('Publicidad')),
      body: ListView(
        children: [
          // Imagen grande (con zoom) o banner de marca.
          AspectRatio(
            aspectRatio: 16 / 10,
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
                                  child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stack) => _banner(),
                    ),
                  )
                : _banner(),
          ),
          Padding(
            padding: const EdgeInsets.all(AppEspaciado.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.titulo,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: AppEspaciado.sm),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 15, color: AppColores.textoSecundario),
                    const SizedBox(width: 6),
                    Text(
                      vigencia,
                      style: const TextStyle(
                          fontSize: 13, color: AppColores.textoSecundario),
                    ),
                  ],
                ),
                const SizedBox(height: AppEspaciado.lg),
                Text(
                  p.descripcion,
                  style: const TextStyle(
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.campaign, color: Colors.white70, size: 72),
      ),
    );
  }
}
