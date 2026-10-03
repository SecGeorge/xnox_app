import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';

/// Publicidad del gimnasio y productos con puntos (solo lectura).
///
/// Con [incrustada] se dibuja como una sección más del inicio del cliente
/// (sin saludo, sin scroll propio); el inicio la recarga con
/// [ClientePublicidadScreenState.recargar] al deslizar para actualizar. En
/// ese modo las novedades no van en la lista: salen en un modal al abrir la
/// app (una vez por sesión) y se vuelven a abrir con
/// [ClientePublicidadScreenState.mostrarNovedades].
class ClientePublicidadScreen extends StatefulWidget {
  final bool incrustada;

  /// Avisa cuántas novedades vigentes hay (para el botón del inicio).
  final ValueChanged<int>? onNovedades;

  const ClientePublicidadScreen({
    super.key,
    this.incrustada = false,
    this.onNovedades,
  });

  @override
  State<ClientePublicidadScreen> createState() =>
      ClientePublicidadScreenState();
}

class ClientePublicidadScreenState extends State<ClientePublicidadScreen> {
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

  Future<void> recargar() => _cargar();

  /// El modal sale solo una vez por sesión de la app: volver al inicio o
  /// recargar no lo repite.
  static bool _modalMostrado = false;

  /// Abre el modal con las novedades vigentes.
  Future<void> mostrarNovedades() async {
    if (_publicidades.isEmpty || !mounted) return;
    _modalMostrado = true;
    await showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.7),
      builder: (_) => _ModalNovedades(
        publicidades: _publicidades,
        onVerImagen: _mostrarImagen,
      ),
    );
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
      widget.onNovedades?.call(_publicidades.length);
      if (widget.incrustada && !_modalMostrado && _publicidades.isNotEmpty) {
        // Tras el primer frame, para no abrir el modal en mitad del build.
        WidgetsBinding.instance.addPostFrameCallback((_) => mostrarNovedades());
      }
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
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.broken_image,
                    color: Colors.white54,
                    size: 64,
                  ),
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
    if (widget.incrustada) return _buildIncrustada();
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppEspaciado.md,
                  AppEspaciado.lg,
                  AppEspaciado.md,
                  AppEspaciado.lg,
                ),
                children: [
                  Text(
                    _nombre.isEmpty
                        ? 'Bienvenido 👋'
                        : 'Bienvenido, $_nombre 👋',
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
                      fontSize: 13.5,
                      color: AppColores.textoSecundario,
                    ),
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

  /// Puntos y novedades como secciones del inicio del cliente.
  Widget _buildIncrustada() {
    if (_isLoading) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_productosPuntos.isNotEmpty) ...[
          _buildProductosPuntos(),
          const SizedBox(height: AppEspaciado.lg),
        ],
        if (_productosCanje.isNotEmpty) ...[
          _buildProductosCanje(),
          const SizedBox(height: AppEspaciado.lg),
        ],
      ],
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
                child: const Icon(
                  Icons.stars_rounded,
                  color: AppColores.naranja,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppEspaciado.sm + 2),
              Expanded(
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
                        fontSize: 12,
                        color: AppColores.textoSecundario,
                      ),
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.sm + 2,
        vertical: 7,
      ),
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
              style: TextStyle(
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
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColores.acento,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppEspaciado.sm + 2),
              Expanded(
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
                        fontSize: 12,
                        color: AppColores.textoSecundario,
                      ),
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
            children: [for (final c in _productosCanje) _chipProductoCanje(c)],
          ),
        ],
      ),
    );
  }

  Widget _chipProductoCanje(LineaCanje c) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.sm + 2,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColores.borde),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            c.esMembresia
                ? Icons.card_membership_rounded
                : Icons.redeem_rounded,
            size: 14,
            color: AppColores.acento.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              c.nombre,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
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
              style: TextStyle(
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
                top: Radius.circular(AppEspaciado.radio),
              ),
              child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                  ? GestureDetector(
                      onTap: () => _mostrarImagen(p.imagenUrl!),
                      // Mismo marco que se usó al encuadrar en el admin: se
                      // muestra la parte de la imagen que el usuario eligió
                      // (Alignment del encuadre). La imagen completa se ve al
                      // dar clic.
                      child: AspectRatio(
                        aspectRatio: AppEspaciado.publicidadRatio,
                        child: Image.network(
                          p.imagenUrl!,
                          width: double.infinity,
                          fit: BoxFit.cover,
                          alignment: p.alineacion,
                          // Decodifica a menor resolución (más rápido y menos memoria).
                          cacheWidth: 1000,
                          loadingBuilder: (context, child, progress) =>
                              progress == null ? child : _cargando(),
                          errorBuilder: (context, error, stack) => _banner(),
                        ),
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
                    style: TextStyle(
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
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: AppEspaciado.sm + 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColores.textoSecundario,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        vigencia,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textoSecundario,
                        ),
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
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
      ),
      child: Center(
        child: Icon(
          Icons.campaign,
          color: AppColores.sobreRellenoSuave,
          size: 48,
        ),
      ),
    );
  }
}

/// Novedades del gimnasio en un modal: una tarjeta por novedad y, si hay
/// varias, se deslizan de lado a lado.
class _ModalNovedades extends StatefulWidget {
  final List<Publicidad> publicidades;
  final void Function(String url) onVerImagen;

  const _ModalNovedades({
    required this.publicidades,
    required this.onVerImagen,
  });

  @override
  State<_ModalNovedades> createState() => _ModalNovedadesState();
}

class _ModalNovedadesState extends State<_ModalNovedades> {
  final _paginas = PageController();
  int _actual = 0;

  int get _total => widget.publicidades.length;

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  void _siguiente() {
    if (_actual < _total - 1) {
      _paginas.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final alto = MediaQuery.of(context).size.height;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: alto * 0.82),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Cabecera: título, contador y cerrar.
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: Colors.white),
                const SizedBox(width: 8),
                const Text(
                  'Novedades',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
                if (_total > 1) ...[
                  const SizedBox(width: 8),
                  Text(
                    '${_actual + 1} de $_total',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                ],
                const Spacer(),
                Material(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.pop(context),
                    child: const SizedBox(
                      width: 36,
                      height: 36,
                      child: Icon(
                        Icons.close_rounded,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Alto según la imagen (proporción fija) más el texto y el botón;
            // si una descripción es larga, se desplaza dentro de su tarjeta.
            LayoutBuilder(
              builder: (context, restr) {
                final ancho = restr.maxWidth - 4;
                final altoTarjeta = (ancho / AppEspaciado.publicidadRatio + 300)
                    .clamp(0.0, alto * 0.82 - 100);
                return SizedBox(
                  height: altoTarjeta,
                  child: PageView.builder(
                    controller: _paginas,
                    itemCount: _total,
                    onPageChanged: (i) => setState(() => _actual = i),
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _tarjeta(widget.publicidades[i]),
                    ),
                  ),
                );
              },
            ),
            if (_total > 1) ...[
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _total; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      margin: const EdgeInsets.symmetric(horizontal: 3),
                      width: i == _actual ? 22 : 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: i == _actual
                            ? Colors.white
                            : Colors.white.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Días que le quedan a la campaña (0 = termina hoy).
  int _diasRestantes(Publicidad p) {
    final hoy = DateTime.now();
    final fin = DateTime(p.fechaFin.year, p.fechaFin.month, p.fechaFin.day);
    return fin.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
  }

  Widget _chipVigencia(Publicidad p) {
    final dias = _diasRestantes(p);
    final pronto = dias <= 3;
    final texto = dias <= 0
        ? 'Termina hoy'
        : pronto
        ? 'Quedan $dias ${dias == 1 ? 'día' : 'días'}'
        : 'Hasta el ${DateFormat("d 'de' MMMM", 'es').format(p.fechaFin)}';
    final tinta = pronto ? Colors.white : AppColores.primario;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: pronto
            ? AppColores.naranja
            : AppColores.primario.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            pronto ? Icons.timer_outlined : Icons.event_available_outlined,
            size: 14,
            color: tinta,
          ),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: tinta,
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagen(Publicidad p) {
    final url = p.imagenUrl;
    final respaldo = Container(
      decoration: BoxDecoration(gradient: AppColores.degradadoRelleno),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: 48,
          color: AppColores.sobreRellenoSuave,
        ),
      ),
    );
    if (url == null || url.isEmpty) return respaldo;
    return GestureDetector(
      onTap: () => widget.onVerImagen(url),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.network(
            url,
            fit: BoxFit.cover,
            alignment: p.alineacion,
            cacheWidth: 1000,
            loadingBuilder: (_, hijo, progreso) => progreso == null
                ? hijo
                : Container(
                    color: AppColores.primario.withValues(alpha: 0.06),
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ),
            errorBuilder: (_, _, _) => respaldo,
          ),
          Positioned(
            right: 10,
            bottom: 10,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.zoom_out_map_rounded,
                size: 16,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjeta(Publicidad p) {
    final formato = DateFormat("d 'de' MMMM", 'es');
    final ultima = _actual == _total - 1;
    return Container(
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 6),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: AppEspaciado.publicidadRatio,
            child: _imagen(p),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _chipVigencia(p),
                  const SizedBox(height: 12),
                  Text(
                    p.titulo,
                    style: TextStyle(
                      fontSize: 21,
                      height: 1.2,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    p.descripcion,
                    style: TextStyle(
                      fontSize: 14.5,
                      height: 1.5,
                      color: AppColores.textoPrincipal.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(
                        Icons.calendar_today_outlined,
                        size: 14,
                        color: AppColores.textoSecundario,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Del ${formato.format(p.fechaInicio)} al '
                          '${formato.format(p.fechaFin)}',
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 4, 18, 18),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _siguiente,
                child: Text(ultima ? 'Entendido' : 'Siguiente'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
