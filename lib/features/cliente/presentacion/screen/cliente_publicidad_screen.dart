import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';

/// Pantalla de inicio del cliente: muestra la publicidad del gimnasio
/// (solo lectura). Si el backend no devuelve campañas, usa una lista demo.
class ClientePublicidadScreen extends StatefulWidget {
  const ClientePublicidadScreen({super.key});

  @override
  State<ClientePublicidadScreen> createState() =>
      _ClientePublicidadScreenState();
}

class _ClientePublicidadScreenState extends State<ClientePublicidadScreen> {
  final _controlador = ControladorPublicidad();
  List<Publicidad> _publicidades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final data = await _controlador.fetchPublicidadesActivas();
      if (!mounted) return;
      setState(() {
        // El cliente solo ve campañas vigentes; las inactivas se ocultan.
        _publicidades = data.where(_estaVigente).toList();
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _publicidades = [];
        _isLoading = false;
      });
    }
  }

  /// Una campaña está vigente si hoy cae dentro de su rango de fechas.
  bool _estaVigente(Publicidad p) {
    final hoy = DateTime.now();
    return !hoy.isBefore(p.fechaInicio) && !hoy.isAfter(p.fechaFin);
  }

  /// Muestra la imagen de la campaña a pantalla completa, como un modal.
  void _mostrarImagen(String url) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => GestureDetector(
        onTap: () => Navigator.of(ctx).pop(),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  url,
                  fit: BoxFit.contain,
                  errorBuilder: (c, e, s) => const Icon(Icons.broken_image,
                      color: Colors.white54, size: 64),
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                    AppEspaciado.lg, AppEspaciado.md, AppEspaciado.lg),
                children: [
                  const Text(
                    'Bienvenido 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Novedades y promociones del gimnasio',
                    style: TextStyle(
                        fontSize: 13.5, color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  if (_publicidades.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EstadoVacio(
                        icono: Icons.campaign_outlined,
                        mensaje: 'No hay novedades por ahora',
                      ),
                    )
                  else
                    ..._publicidades.map(_buildTarjeta),
                ],
              ),
      ),
    );
  }

  Widget _buildTarjeta(Publicidad p) {
    final formato = DateFormat('d MMM', 'es');
    final vigencia =
        '${formato.format(p.fechaInicio)} – ${formato.format(p.fechaFin)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.md),
      child: TarjetaApp(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen o banner de marca. Al tocar la imagen se ve en grande.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppEspaciado.radio)),
              child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _mostrarImagen(p.imagenUrl!),
                      child: Image.network(p.imagenUrl!,
                          height: 140,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          // Decodifica a menor resolución (más rápido y menos memoria).
                          cacheWidth: 1000,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : _cargando(),
                          errorBuilder: (context, error, stack) => _banner()),
                    )
                  : _banner(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppEspaciado.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.descripcion,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: AppEspaciado.sm + 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColores.textoSecundario),
                      const SizedBox(width: 6),
                      Text(
                        vigencia,
                        style: const TextStyle(
                            fontSize: 12, color: AppColores.textoSecundario),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cargando() {
    return Container(
      height: 140,
      width: double.infinity,
      color: AppColores.fondo,
      child: const Center(
        child: SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5),
        ),
      ),
    );
  }

  Widget _banner() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.campaign, color: Colors.white70, size: 48),
      ),
    );
  }
}
