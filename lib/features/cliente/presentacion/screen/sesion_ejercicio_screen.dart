import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/hoja_numero.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/temporizador_descanso.dart';
import 'package:xnox_app/features/ejercicios/datos/repositorio_ejercicios.dart';
import 'package:xnox_app/features/ejercicios/presentacion/screen/detalle_ejercicio_screen.dart';
import 'package:xnox_app/features/ejercicios/presentacion/screen/reproductor_ejercicio_screen.dart';

/// Un ejercicio de la rutina, listo para entrenar: foto, objetivo, carga de
/// hoy, descanso entre series, las series del día (se marcan una a una) y la
/// evolución de la carga en las sesiones anteriores.
class SesionEjercicioScreen extends StatefulWidget {
  final int rutinaId;
  final int ejercicioId;

  const SesionEjercicioScreen({
    super.key,
    required this.rutinaId,
    required this.ejercicioId,
  });

  @override
  State<SesionEjercicioScreen> createState() => _SesionEjercicioScreenState();
}

class _SesionEjercicioScreenState extends State<SesionEjercicioScreen> {
  final _controlador = ControladorRutinas();
  final _descanso = ControlDescanso();

  /// Peso con el que se registrarán las series de hoy.
  double? _peso;

  // Referencia de ejecución del catálogo del gimnasio (fotos, video, texto).
  // La rutina solo guarda la portada y el video: lo demás se pide al abrir.
  final _paginas = PageController();
  int _foto = 0;
  List<String> _imagenes = [];
  String? _video;
  String? _descripcion;
  String? _grupoMuscular;

  @override
  void initState() {
    super.initState();
    final e = _ejercicio;
    if (e != null) {
      _imagenes = [if ((e.imagenUrl ?? '').isNotEmpty) e.imagenUrl!];
      _video = e.videoUrl;
      if (e.catalogoId != null) _cargarCatalogo(e.catalogoId!);
    }
  }

  @override
  void dispose() {
    _paginas.dispose();
    super.dispose();
  }

  Future<void> _cargarCatalogo(int id) async {
    try {
      final c = await RepositorioEjercicios().obtener(id);
      if (c == null || !mounted) return;
      setState(() {
        if (c.imagenes.isNotEmpty) _imagenes = c.imagenes;
        if (c.tieneVideo) _video = c.videoUrl;
        _descripcion = c.descripcion;
        _grupoMuscular = c.grupoMuscular;
      });
    } catch (_) {
      /* sin red: queda la portada de la rutina */
    }
  }

  bool get _tieneVideo => (_video ?? '').isNotEmpty;

  void _verVideo(String titulo) {
    if (!_tieneVideo) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            ReproductorEjercicioScreen(url: _video!, titulo: titulo),
      ),
    );
  }

  Ejercicio? get _ejercicio {
    final r = _controlador.obtenerRutina(widget.rutinaId);
    if (r == null) return null;
    for (final e in r.ejercicios) {
      if (e.id == widget.ejercicioId) return e;
    }
    return null;
  }

  Marca? _sesionHoy(Ejercicio e) {
    Marca? s;
    for (final m in e.marcas) {
      if (m.esHoy && (s == null || m.fecha.isAfter(s.fecha))) s = m;
    }
    return s;
  }

  /// Última sesión que no es la de hoy (la referencia para comparar).
  Marca? _anterior(Ejercicio e) {
    final previas = e.marcasOrdenadas.where((m) => !m.esHoy).toList();
    return previas.isEmpty ? null : previas.last;
  }

  /// Carga sugerida: si la última vez cumplió todas las reps, subir 2,5 kg
  /// (sobrecarga progresiva); si no, repetir el peso.
  double? _sugerido(Ejercicio e) {
    final previa = _anterior(e);
    if (previa == null) return null;
    final cumplio =
        previa.repsPorSerie.length >= e.series &&
        previa.repsPorSerie.every((r) => r >= e.repeticiones);
    return cumplio ? previa.peso + 2.5 : previa.peso;
  }

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final e = _ejercicio;
    if (e == null) {
      return const Scaffold(
        body: EstadoVacio(
          icono: Icons.error_outline,
          mensaje: 'Ejercicio no encontrado',
        ),
      );
    }
    final hoy = _sesionHoy(e);
    _peso ??= hoy?.peso ?? _sugerido(e) ?? e.ultimaMarca?.peso;

    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: CustomScrollView(
        slivers: [
          _cabecera(e),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppEspaciado.md,
              0,
              AppEspaciado.md,
              AppEspaciado.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text(
                  e.nombre,
                  style: TextStyle(
                    fontSize: 25,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                if ((_grupoMuscular ?? '').isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(
                        Icons.accessibility_new_rounded,
                        size: 16,
                        color: AppColores.primario,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _grupoMuscular!,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColores.primario,
                        ),
                      ),
                    ],
                  ),
                ],
                if ((e.observaciones ?? '').isNotEmpty) ...[
                  const SizedBox(height: AppEspaciado.sm + 2),
                  _nota(e.observaciones!),
                ],
                const SizedBox(height: AppEspaciado.md),
                _datos(e, hoy),
                const SizedBox(height: AppEspaciado.sm + 4),
                TemporizadorDescanso(
                  ejercicioId: e.id,
                  porDefecto: e.descansoSeg,
                  control: _descanso,
                ),
                if (_tieneVideo ||
                    (_descripcion ?? '').isNotEmpty ||
                    _imagenes.length > 1) ...[
                  const SizedBox(height: AppEspaciado.lg),
                  _titulo('Cómo se hace', null),
                  _comoSeHace(e),
                ],
                const SizedBox(height: AppEspaciado.lg),
                _titulo(
                  'Series de hoy',
                  '${hoy?.repsPorSerie.length ?? 0} de ${e.series}',
                ),
                _seriesDeHoy(e, hoy),
                const SizedBox(height: AppEspaciado.lg),
                _titulo('Evolución de la carga', null),
                _evolucion(e),
                if (e.marcas.isNotEmpty) ...[
                  const SizedBox(height: AppEspaciado.lg),
                  _titulo('Historial', '${e.marcas.length} sesiones'),
                  _historial(e),
                ],
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cabecera(Ejercicio e) {
    Widget respaldo() =>
        Image.asset('assets/imagenes/inicio/rutinas.jpg', fit: BoxFit.cover);
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColores.relleno,
      foregroundColor: AppColores.sobreRelleno,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: CircleAvatar(
          backgroundColor: Colors.black.withValues(alpha: 0.4),
          child: IconButton(
            icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Stack(
          fit: StackFit.expand,
          children: [
            // Galería de la ejecución: se desliza entre las fotos del catálogo.
            _imagenes.isEmpty
                ? respaldo()
                : PageView.builder(
                    controller: _paginas,
                    itemCount: _imagenes.length,
                    onPageChanged: (i) => setState(() => _foto = i),
                    itemBuilder: (_, i) => Image.network(
                      _imagenes[i],
                      fit: BoxFit.cover,
                      cacheWidth: 1000,
                      errorBuilder: (_, _, _) => respaldo(),
                    ),
                  ),
            IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.35),
                      Colors.transparent,
                      AppColores.fondo,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ),
            if (_tieneVideo)
              Center(
                child: GestureDetector(
                  onTap: () => _verVideo(e.nombre),
                  child: Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.play_arrow_rounded,
                      size: 42,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            if (_imagenes.length > 1)
              Positioned(
                bottom: AppEspaciado.lg,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < _imagenes.length; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        width: i == _foto ? 18 : 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: i == _foto
                              ? AppColores.primario
                              : AppColores.primario.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(3),
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

  /// Referencia de la técnica: video, miniaturas de las fotos y descripción.
  Widget _comoSeHace(Ejercicio e) {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_tieneVideo) ...[
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => _verVideo(e.nombre),
                icon: const Icon(Icons.play_circle_fill_rounded),
                label: const Text('Ver video de ejecución'),
              ),
            ),
            const SizedBox(height: AppEspaciado.md),
          ],
          if (_imagenes.length > 1) ...[
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _imagenes.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => GestureDetector(
                  onTap: () => _paginas.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOut,
                  ),
                  child: Container(
                    width: 64,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                      border: Border.all(
                        color: i == _foto
                            ? AppColores.primario
                            : AppColores.borde,
                        width: i == _foto ? 2 : 1,
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Image.network(
                      _imagenes[i],
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppEspaciado.md),
          ],
          if ((_descripcion ?? '').isNotEmpty)
            Text(
              _descripcion!,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColores.textoPrincipal.withValues(alpha: 0.8),
              ),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => DetalleEjercicioScreen(
                    nombre: e.nombre,
                    catalogoId: e.catalogoId,
                    imagenUrl: e.imagenUrl,
                    videoUrl: _video,
                  ),
                ),
              ),
              icon: const Icon(Icons.zoom_out_map_rounded, size: 17),
              label: const Text('Ver fotos en grande'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _nota(String texto) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColores.primario.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: AppColores.primario.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.sticky_note_2_rounded,
            size: 18,
            color: AppColores.primario,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              texto,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datos(Ejercicio e, Marca? hoy) {
    final sugerido = _sugerido(e);
    Widget caja({required Widget child}) => Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColores.superficie,
          borderRadius: BorderRadius.circular(AppEspaciado.radio),
          border: Border.all(color: AppColores.borde),
        ),
        child: child,
      ),
    );
    const etiqueta = TextStyle(fontSize: 12, color: AppColores.textoSecundario);
    final valor = TextStyle(
      fontSize: 22,
      height: 1.2,
      fontWeight: FontWeight.w800,
      color: AppColores.textoPrincipal,
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          caja(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Series y repeticiones', style: etiqueta),
                const SizedBox(height: 6),
                Text('${e.series} × ${e.repeticiones}', style: valor),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm + 2),
          caja(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Carga (kg)', style: etiqueta),
                      const SizedBox(height: 6),
                      Text(_peso == null ? '--' : _num(_peso!), style: valor),
                      if (sugerido != null)
                        Text(
                          'Sugerido: ${_num(sugerido)} kg',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColores.primario,
                          ),
                        ),
                    ],
                  ),
                ),
                Material(
                  color: AppColores.primario.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    onTap: () => _editarPeso(e, hoy),
                    child: SizedBox(
                      width: 40,
                      height: 40,
                      child: Icon(
                        Icons.edit_rounded,
                        size: 19,
                        color: AppColores.primario,
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

  Widget _titulo(String texto, String? detalle) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 2, left: 2),
      child: Row(
        children: [
          Text(
            texto.toUpperCase(),
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColores.textoSecundario,
            ),
          ),
          const Spacer(),
          if (detalle != null)
            Text(
              detalle,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColores.primario,
              ),
            ),
        ],
      ),
    );
  }

  /// Una fila por serie del objetivo (más las extra que haya hecho). Las hechas
  /// muestran sus reps; la siguiente pendiente se registra con un toque.
  Widget _seriesDeHoy(Ejercicio e, Marca? hoy) {
    final hechas = hoy?.repsPorSerie ?? const <int>[];
    final filas = hechas.length > e.series ? hechas.length : e.series;
    return Container(
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          for (var i = 0; i < filas; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColores.borde, indent: 56),
            _filaSerie(
              e,
              hoy,
              i,
              i < hechas.length ? hechas[i] : null,
              siguiente: i == hechas.length,
            ),
          ],
          if (hechas.length >= e.series) ...[
            Divider(height: 1, color: AppColores.borde),
            TextButton.icon(
              onPressed: () => _registrarSerie(e),
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Serie extra'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _filaSerie(
    Ejercicio e,
    Marca? hoy,
    int i,
    int? reps, {
    required bool siguiente,
  }) {
    final hecha = reps != null;
    return InkWell(
      onTap: hecha
          ? () => _editarSerie(hoy!, i, reps)
          : siguiente
          ? () => _registrarSerie(e)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: hecha ? AppColores.exito : Colors.transparent,
                border: Border.all(
                  color: hecha
                      ? AppColores.exito
                      : siguiente
                      ? AppColores.primario
                      : AppColores.borde,
                  width: 2,
                ),
              ),
              child: hecha
                  ? const Icon(
                      Icons.check_rounded,
                      size: 17,
                      color: Colors.white,
                    )
                  : null,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'Serie ${i + 1}',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w600,
                  color: hecha || siguiente
                      ? AppColores.textoPrincipal
                      : AppColores.textoSecundario,
                ),
              ),
            ),
            if (hecha)
              Text(
                '$reps reps · ${_num(hoy!.peso)} kg',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              )
            else if (siguiente)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: AppColores.degradadoRelleno,
                  border: AppColores.bordeCabecera,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Registrar',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.sobreRelleno,
                  ),
                ),
              )
            else
              Text(
                '${e.repeticiones} reps',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColores.textoSecundario,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _evolucion(Ejercicio e) {
    final sesiones = e.marcasOrdenadas;
    final pesos = sesiones.map((m) => m.peso).toList();
    final pr = e.mejorMarca;
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          if (pesos.length >= 2)
            Row(
              children: [
                _chipKg('Inicio', pesos.first, AppColores.textoSecundario),
                const Spacer(),
                if (pr != null) _chipKg('Récord', pr.peso, AppColores.naranja),
                const SizedBox(width: 6),
                _chipKg('Última', pesos.last, AppColores.primario),
              ],
            ),
          const SizedBox(height: AppEspaciado.sm),
          GraficoEvolucion(
            puntos: [
              for (final m in sesiones)
                PuntoEvolucion(m.fecha, m.peso, detalle: '${m.repsTexto} reps'),
            ],
            unidad: 'kg',
            cabecera: false,
            enTarjeta: false,
            alto: 150,
            textoVacio: 'Termina esta sesión y aquí verás tu progreso',
            textoUnPunto: 'En la próxima sesión verás tu curva de cargas',
          ),
        ],
      ),
    );
  }

  Widget _chipKg(String etiqueta, double kg, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$etiqueta ${_num(kg)} kg',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _historial(Ejercicio e) {
    final sesiones = e.marcasOrdenadas.reversed.take(10).toList();
    final pr = e.mejorMarca;
    final formato = DateFormat("d MMM", 'es');
    return Container(
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          for (var i = 0; i < sesiones.length; i++) ...[
            if (i > 0) Divider(height: 1, color: AppColores.borde, indent: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              child: Row(
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      sesiones[i].esHoy
                          ? 'Hoy'
                          : formato.format(sesiones[i].fecha),
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ),
                  Text(
                    '${_num(sesiones[i].peso)} kg',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  if (identical(sesiones[i], pr) ||
                      (pr != null && sesiones[i].id == pr.id)) ...[
                    const SizedBox(width: 6),
                    const EtiquetaEstado(
                      texto: 'PR',
                      color: AppColores.naranja,
                    ),
                  ],
                  const Spacer(),
                  Text(
                    '${sesiones[i].repsTexto} reps',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Acciones

  Future<void> _editarPeso(Ejercicio e, Marca? hoy) async {
    final previa = _anterior(e);
    final sugerido = _sugerido(e);
    final pr = e.mejorMarca;
    final atajos = <AtajoNumero>[
      if (previa != null) AtajoNumero('Última vez', previa.peso),
      if (sugerido != null && sugerido != previa?.peso)
        AtajoNumero('Sugerido', sugerido),
      if (pr != null && pr.peso != previa?.peso && pr.peso != sugerido)
        AtajoNumero('Récord', pr.peso),
    ];
    final nuevo = await pedirNumero(
      context,
      titulo: 'Carga de hoy',
      subtitulo: e.nombre,
      icono: Icons.fitness_center_rounded,
      unidad: 'kg',
      inicial: _peso ?? sugerido ?? previa?.peso,
      paso: 2.5,
      decimales: true,
      atajos: atajos,
    );
    if (nuevo == null) return;
    if (hoy?.id != null) await _controlador.editarPesoSesion(hoy!.id!, nuevo);
    if (mounted) setState(() => _peso = nuevo);
  }

  Future<void> _registrarSerie(Ejercicio e) async {
    if (_peso == null || _peso! <= 0) {
      await _editarPeso(e, _sesionHoy(e));
      if (_peso == null || _peso! <= 0) return;
    }
    final hechas = _sesionHoy(e)?.repsPorSerie.length ?? 0;
    final reps = await _pedirReps('Serie ${hechas + 1}', e.repeticiones);
    if (reps == null) return;
    await _controlador.agregarSerie(e.id, _peso!, reps);
    if (!mounted) return;
    setState(() {});
    // Toca descansar antes de la siguiente.
    _descanso.iniciar();
  }

  Future<void> _editarSerie(Marca hoy, int i, int reps) async {
    final accion = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: AppEspaciado.sm),
            ListTile(
              leading: Icon(Icons.edit_rounded, color: AppColores.primario),
              title: Text('Cambiar repeticiones de la serie ${i + 1}'),
              onTap: () => Navigator.pop(ctx, 'editar'),
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppColores.moroso,
              ),
              title: const Text(
                'Quitar esta serie',
                style: TextStyle(color: AppColores.moroso),
              ),
              onTap: () => Navigator.pop(ctx, 'borrar'),
            ),
          ],
        ),
      ),
    );
    if (accion == 'editar') {
      final nuevas = await _pedirReps('Serie ${i + 1}', reps);
      if (nuevas == null) return;
      await _controlador.editarSerie(hoy.id!, i + 1, nuevas);
    } else if (accion == 'borrar') {
      await _controlador.eliminarSerie(hoy.id!, i + 1);
    } else {
      return;
    }
    if (mounted) setState(() {});
  }

  /// Pide las repeticiones de una serie con la hoja de número (− / +).
  Future<int?> _pedirReps(String titulo, int inicial) async {
    final e = _ejercicio;
    final v = await pedirNumero(
      context,
      titulo: titulo,
      subtitulo: e == null
          ? null
          : 'Objetivo: ${e.repeticiones} reps · ${_peso == null ? '--' : _num(_peso!)} kg',
      icono: Icons.repeat_rounded,
      unidad: 'repeticiones',
      inicial: inicial.toDouble(),
      atajos: [
        if (e != null) AtajoNumero('Objetivo', e.repeticiones.toDouble()),
      ],
    );
    return v?.round();
  }
}
