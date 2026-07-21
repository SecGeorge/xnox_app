import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';

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
  final _promo = ControladorPromociones();
  List<Publicidad> _publicidades = [];
  List<LineaGana> _productosPuntos = [];
  List<LineaCanje> _productosCanje = [];
  String _nombre = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarNombre();
    _cargar();
  }

  /// Lee el nombre del cliente guardado en sesión para saludarlo.
  Future<void> _cargarNombre() async {
    final prefs = await SharedPreferences.getInstance();
    final nombre = prefs.getString('nombreCliente') ?? '';
    if (!mounted) return;
    // Mostramos solo el primer nombre para un saludo más limpio.
    setState(() => _nombre = nombre.trim().split(' ').first);
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final data = await _controlador.fetchPublicidadesActivas();
      // Los puntos son secundarios: si fallan, no rompen el inicio.
      List<LineaGana> gana;
      List<LineaCanje> canje;
      try {
        final resumen = await _promo.obtenerResumen();
        gana = resumen.gana;
        canje = resumen.canje;
      } catch (_) {
        gana = [];
        canje = [];
      }
      if (!mounted) return;
      setState(() {
        // El cliente solo ve campañas vigentes; las inactivas se ocultan.
        _publicidades = data.where(_estaVigente).toList();
        _productosPuntos = gana;
        _productosCanje = canje;
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
                  Text(
                    _nombre.isEmpty ? 'Bienvenido 👋' : 'Bienvenido, $_nombre 👋',
                    style: const TextStyle(
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
                  if (_productosPuntos.isNotEmpty) ...[
                    _buildProductosPuntos(),
                    const SizedBox(height: AppEspaciado.lg),
                  ],
                  if (_productosCanje.isNotEmpty) ...[
                    _buildProductosCanje(),
                    const SizedBox(height: AppEspaciado.lg),
                  ],
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

  /// Sección que muestra al cliente qué productos otorgan puntos al comprarlos.
  Widget _buildProductosPuntos() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.naranja.withValues(alpha: 0.10),
            AppColores.naranja.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.naranja.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColores.naranja.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                ),
                child: const Icon(Icons.stars_rounded,
                    color: AppColores.naranja, size: 20),
              ),
              const SizedBox(width: AppEspaciado.sm + 2),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Productos que te dan puntos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    Text(
                      'Cómpralos y acumula para canjear',
                      style: TextStyle(
                          fontSize: 12, color: AppColores.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
          Wrap(
            spacing: AppEspaciado.sm,
            runSpacing: AppEspaciado.sm,
            children: [
              for (final g in _productosPuntos) _chipProductoPuntos(g),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipProductoPuntos(LineaGana g) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppEspaciado.sm + 2, vertical: 7),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColores.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(
              g.nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColores.naranja.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '+${g.puntos}',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColores.naranja,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección que muestra al cliente qué puede canjear y cuántos puntos cuesta.
  Widget _buildProductosCanje() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColores.acento.withValues(alpha: 0.10),
            AppColores.acento.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.acento.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColores.acento.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: AppColores.acento, size: 20),
              ),
              const SizedBox(width: AppEspaciado.sm + 2),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Canjea tus puntos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    Text(
                      'Cuánto cuesta cada premio en puntos',
                      style: TextStyle(
                          fontSize: 12, color: AppColores.textoSecundario),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
          Wrap(
            spacing: AppEspaciado.sm,
            runSpacing: AppEspaciado.sm,
            children: [
              for (final c in _productosCanje) _chipProductoCanje(c),
            ],
          ),
        ],
      ),
    );
  }

  Widget _chipProductoCanje(LineaCanje c) {
    return Container(
      padding:
          const EdgeInsets.symmetric(horizontal: AppEspaciado.sm + 2, vertical: 7),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColores.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.esMembresia ? Icons.card_membership_rounded : Icons.redeem_rounded,
            size: 14,
            color: AppColores.acento.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              c.nombre,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: AppColores.acento.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${c.puntos} pts',
              style: const TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: AppColores.acento,
              ),
            ),
          ),
        ],
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
                      // Mismo marco que se usó al encuadrar en el admin: se
                      // muestra la parte de la imagen que el usuario eligió
                      // (Alignment del encuadre). La imagen completa se ve al
                      // dar clic.
                      child: AspectRatio(
                        aspectRatio: AppEspaciado.publicidadRatio,
                        child: Image.network(p.imagenUrl!,
                            width: double.infinity,
                            fit: BoxFit.cover,
                            alignment: p.alineacion,
                            // Decodifica a menor resolución (más rápido y menos memoria).
                            cacheWidth: 1000,
                            loadingBuilder: (context, child, progress) =>
                                progress == null ? child : _cargando(),
                            errorBuilder: (context, error, stack) => _banner()),
                      ),
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
