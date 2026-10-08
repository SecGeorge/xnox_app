import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/detalle_rutina_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/dia_rutina_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/sesion_ejercicio_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/foto_sesion.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';

/// Rutinas del socio en tres vistas:
/// - Mi semana: lo que le toca cada día, con el avance del día elegido.
/// - Mis rutinas: todas (las que armó el gimnasio, sugeridas y propias).
/// - Historial: las sesiones registradas, agrupadas por fecha.
///
/// Todo sale del SQLite local (rutinas, ejercicios y marcas) y se pinta con la
/// paleta del gimnasio.
class RutinasScreen extends StatefulWidget {
  const RutinasScreen({super.key});

  @override
  State<RutinasScreen> createState() => _RutinasScreenState();
}

enum _Vista { semana, rutinas, historial }

class _RutinasScreenState extends State<RutinasScreen> {
  final _controlador = ControladorRutinas();
  bool _cargando = true;
  _Vista _vista = _Vista.semana;

  /// Día elegido en la tira de la semana (0 = lunes).
  int _dia = DateTime.now().weekday - 1;

  /// Rutina elegida cuando varias tienen el mismo día.
  int? _rutinaElegidaId;

  static const _nombresDia = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      await _controlador.sincronizar();
    } catch (_) {
      // Sin red: se queda con lo del SQLite.
      await _controlador.asegurarCargado();
    }
    if (!mounted) return;
    setState(() => _cargando = false);
  }

  // ------------------------------------------------------------- Datos

  static String _normalizar(String t) => t
      .toLowerCase()
      .trim()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  /// Todas las rutinas en orden de prioridad: las del gimnasio para el socio,
  /// las suyas y las sugeridas.
  List<Rutina> get _todas => [
    ..._controlador.obtenerAsignadas(),
    ..._controlador.obtenerMisRutinas(),
    ..._controlador.obtenerSugeridas(),
  ];

  /// Rutinas que tienen ejercicios el día [indice] de la semana, con ese día.
  List<(Rutina, DiaRutina)> _opcionesDelDia(int indice) {
    final buscado = _normalizar(_nombresDia[indice]);
    return [
      for (final r in _todas)
        for (final d in r.dias)
          if (_normalizar(d.diaSemana) == buscado && d.ejercicios.isNotEmpty)
            (r, d),
    ];
  }

  /// Fecha del día [indice] en la semana actual.
  DateTime _fechaDe(int indice) {
    final hoy = DateTime.now();
    final lunes = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: hoy.weekday - 1));
    return lunes.add(Duration(days: indice));
  }

  static bool _mismoDia(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  bool _hecho(Ejercicio e, DateTime fecha) =>
      e.marcas.any((m) => _mismoDia(m.fecha, fecha));

  /// Duración estimada: unos 2,5 minutos por serie (incluye el descanso).
  int _minutos(DiaRutina d) {
    final series = d.ejercicios.fold<int>(0, (s, e) => s + e.series);
    final min = (series * 2.5 / 5).round() * 5;
    return min < 10 ? 10 : min;
  }

  Future<void> _abrirDia(Rutina r, DiaRutina d) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DiaRutinaScreen(rutinaId: r.id, diaId: d.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _abrirEjercicio(Rutina r, Ejercicio e) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SesionEjercicioScreen(rutinaId: r.id, ejercicioId: e.id),
      ),
    );
    if (mounted) setState(() {});
  }

  Future<void> _abrirRutina(Rutina r) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalleRutinaScreen(rutinaId: r.id)),
    );
    // Al volver puede haber registrado series o cambiado la rutina.
    if (mounted) setState(() {});
  }

  // -------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppEspaciado.md,
                    AppEspaciado.md,
                    AppEspaciado.md,
                    110,
                  ),
                  children: [
                    _cabecera(),
                    const SizedBox(height: AppEspaciado.md + 4),
                    _pestanas(),
                    const SizedBox(height: AppEspaciado.md + 4),
                    ...switch (_vista) {
                      _Vista.semana => _vistaSemana(),
                      _Vista.rutinas => _vistaRutinas(),
                      _Vista.historial => _vistaHistorial(),
                    },
                  ],
                ),
              ),
      ),
    );
  }

  Widget _cabecera() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Rutinas',
                style: TextStyle(
                  fontSize: 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 2),
              const Text(
                'Tu plan de entrenamiento, siempre contigo',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        // Crear rutina propia.
        Material(
          color: AppColores.relleno,
          shape: CircleBorder(side: AppColores.ladoBoton ?? BorderSide.none),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _nuevaRutina,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(
                Icons.add_rounded,
                size: 26,
                color: AppColores.sobreRelleno,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Pestañas de texto con una línea que se desliza bajo la activa.
  Widget _pestanas() {
    const vistas = [
      (_Vista.semana, 'Mi semana'),
      (_Vista.rutinas, 'Rutinas'),
      (_Vista.historial, 'Historial'),
    ];
    final activa = vistas.indexWhere((v) => v.$1 == _vista);
    return LayoutBuilder(
      builder: (context, restr) {
        final ancho = restr.maxWidth / vistas.length;
        return SizedBox(
          height: 46,
          child: Stack(
            children: [
              // Línea base.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: AppColores.borde),
              ),
              // Indicador de la pestaña activa.
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: ancho * activa + ancho * 0.2,
                width: ancho * 0.6,
                bottom: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColores.primario,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  for (final (vista, texto) in vistas)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => setState(() => _vista = vista),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: vista == _vista
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: vista == _vista
                                  ? AppColores.primario
                                  : AppColores.textoSecundario,
                            ),
                            child: Text(texto),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------- Mi semana

  List<Widget> _vistaSemana() {
    final opciones = _opcionesDelDia(_dia);
    final elegida = opciones.isEmpty
        ? null
        : opciones.firstWhere(
            (o) => o.$1.id == _rutinaElegidaId,
            orElse: () => opciones.first,
          );
    final fecha = _fechaDe(_dia);
    return [
      _tiraSemana(),
      const SizedBox(height: AppEspaciado.md + 4),
      if (elegida == null)
        _diaDescanso()
      else ...[
        if (opciones.length > 1) ...[
          _selectorRutina(opciones, elegida.$1),
          const SizedBox(height: AppEspaciado.sm + 4),
        ],
        _tarjetaDia(elegida.$1, elegida.$2, fecha),
        const SizedBox(height: AppEspaciado.lg),
        _tituloEjercicios(fecha),
        const SizedBox(height: AppEspaciado.sm + 4),
        for (var i = 0; i < elegida.$2.ejercicios.length; i++)
          _filaEjercicio(i + 1, elegida.$2.ejercicios[i], elegida.$1, fecha),
      ],
      const SizedBox(height: AppEspaciado.sm),
      _avisoOtrasRutinas(),
    ];
  }

  Widget _tiraSemana() {
    final hoy = DateTime.now().weekday - 1;
    const cortos = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _dia = i;
                _rutinaElegidaId = null;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  gradient: i == _dia ? AppColores.degradadoRelleno : null,
                  color: i == _dia ? null : AppColores.superficie,
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  border: i == _dia
                      ? (AppColores.bordeCabecera ??
                            Border.all(color: Colors.transparent))
                      : Border.all(
                          color: i == hoy
                              ? AppColores.primario.withValues(alpha: 0.5)
                              : AppColores.borde,
                        ),
                ),
                child: Column(
                  children: [
                    Text(
                      cortos[i],
                      style: TextStyle(
                        fontSize: 11.5,
                        color: i == _dia
                            ? AppColores.sobreRellenoSuave
                            : AppColores.textoSecundario,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_fechaDe(i).day}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: i == _dia
                            ? AppColores.sobreRelleno
                            : AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Punto en los días que tienen rutina.
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _opcionesDelDia(i).isEmpty
                            ? Colors.transparent
                            : i == _dia
                            ? AppColores.sobreRelleno
                            : AppColores.primario,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _selectorRutina(List<(Rutina, DiaRutina)> opciones, Rutina actual) {
    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final o in opciones)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(o.$1.nombre),
                selected: o.$1.id == actual.id,
                onSelected: (_) => setState(() => _rutinaElegidaId = o.$1.id),
                selectedColor: AppColores.primario,
                backgroundColor: AppColores.superficie,
                side: BorderSide(color: AppColores.borde),
                showCheckmark: false,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: o.$1.id == actual.id
                      ? Colors.white
                      : AppColores.textoPrincipal,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _tarjetaDia(Rutina r, DiaRutina d, DateTime fecha) {
    final total = d.totalEjercicios;
    final hechos = d.ejercicios.where((e) => _hecho(e, fecha)).length;
    final porcentaje = total == 0 ? 0 : (hechos / total * 100).round();
    final esHoy = _mismoDia(fecha, DateTime.now());
    final futuro = fecha.isAfter(DateTime.now());
    final String mensaje;
    if (hechos >= total) {
      mensaje = '¡Completado! Excelente trabajo.';
    } else if (hechos > 0) {
      mensaje = '¡Vamos! Mantén la intensidad y sigue mejorando.';
    } else if (futuro) {
      mensaje = 'Así se viene tu ${d.diaSemana.toLowerCase()}. ¡Prepárate!';
    } else {
      mensaje = esHoy
          ? 'Tu entrenamiento de hoy te espera.'
          : 'Este día no registraste series.';
    }

    return FotoTarjeta(
      foto: FotoSesion.para(r, d).ruta,
      alineacion: FotoSesion.para(r, d).alineacion,
      radio: AppEspaciado.radio + 6,
      degradadoHorizontal: true,
      child: Padding(
        padding: const EdgeInsets.all(AppEspaciado.md + 2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _chipFoto(
                  Icons.today_rounded,
                  esHoy ? 'RUTINA DE HOY' : d.diaSemana.toUpperCase(),
                ),
                const Spacer(),
                _duracion(_minutos(d)),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            if (FotoSesion.subtitulo(r, d) != null)
              Text(
                FotoSesion.subtitulo(r, d)!.toUpperCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.75),
                ),
              ),
            Text(
              FotoSesion.titulo(r, d),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 25,
                height: 1.1,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.3,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: 230,
              child: Text(
                mensaje,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.35,
                  color: Colors.white.withValues(alpha: 0.82),
                ),
              ),
            ),
            const SizedBox(height: AppEspaciado.md),
            Row(
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$hechos / $total',
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const TextSpan(text: ' ejercicios completados'),
                    ],
                  ),
                  style: const TextStyle(fontSize: 12.5, color: Colors.white),
                ),
                const Spacer(),
                Text(
                  '$porcentaje%',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.destacado,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (var i = 0; i < total; i++) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: i < hechos
                            ? AppColores.destacado
                            : Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            _botonFoto('Ver detalles', () => _abrirDia(r, d)),
          ],
        ),
      ),
    );
  }

  Widget _chipFoto(IconData icono, String texto) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 5, 12, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColores.destacado.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 17, color: AppColores.destacado),
          const SizedBox(width: 6),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 0.8,
              fontWeight: FontWeight.w800,
              color: AppColores.destacado,
            ),
          ),
        ],
      ),
    );
  }

  Widget _duracion(int minutos) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 5, 10, 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.local_fire_department_rounded,
            size: 18,
            color: AppColores.destacado,
          ),
          const SizedBox(width: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Duración aprox.',
                style: TextStyle(
                  fontSize: 9.5,
                  color: Colors.white.withValues(alpha: 0.7),
                ),
              ),
              Text(
                '$minutos min',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _botonFoto(String texto, VoidCallback onTap) {
    final claro = AppColores.bordeRelleno != null;
    final fondo = claro ? AppColores.relleno : AppColores.destacado;
    final tinta = claro
        ? AppColores.sobreRelleno
        : AppColores.destacado.computeLuminance() > 0.45
        ? const Color(0xFF0E1A12)
        : Colors.white;
    final radio = BorderRadius.circular(AppEspaciado.radioSm);
    return Material(
      color: fondo,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: SizedBox(
          width: 190,
          height: 44,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                texto,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w800,
                  color: tinta,
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.chevron_right_rounded, size: 20, color: tinta),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tituloEjercicios(DateTime fecha) {
    final esHoy = _mismoDia(fecha, DateTime.now());
    return Row(
      children: [
        Icon(Icons.fitness_center_rounded, color: AppColores.primario),
        const SizedBox(width: AppEspaciado.sm),
        Expanded(
          child: Text(
            esHoy ? 'Ejercicios de hoy' : 'Ejercicios del día',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
        ),
        Text(
          DateFormat("d 'de' MMMM", 'es').format(fecha),
          style: const TextStyle(
            fontSize: 12.5,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _filaEjercicio(int numero, Ejercicio e, Rutina r, DateTime fecha) {
    final hecho = _hecho(e, fecha);
    final futuro = fecha.isAfter(DateTime.now());
    final radio = BorderRadius.circular(AppEspaciado.radio);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 2),
      child: Material(
        color: AppColores.superficie,
        borderRadius: radio,
        child: InkWell(
          borderRadius: radio,
          onTap: () => _abrirEjercicio(r, e),
          child: Ink(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              borderRadius: radio,
              border: Border.all(
                color: hecho
                    ? AppColores.exito.withValues(alpha: 0.35)
                    : AppColores.borde,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  child: SizedBox(
                    width: 64,
                    height: 56,
                    child: (e.imagenUrl ?? '').isEmpty
                        ? _miniaturaVacia()
                        : Image.network(
                            e.imagenUrl!,
                            fit: BoxFit.cover,
                            cacheWidth: 200,
                            errorBuilder: (_, _, _) => _miniaturaVacia(),
                          ),
                  ),
                ),
                const SizedBox(width: AppEspaciado.sm + 4),
                Container(
                  width: 24,
                  height: 24,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: hecho
                        ? AppColores.primario
                        : AppColores.primario.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$numero',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: hecho ? Colors.white : AppColores.primario,
                    ),
                  ),
                ),
                const SizedBox(width: AppEspaciado.sm + 2),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${e.series} × ${e.repeticiones}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                // Solo el ícono: así el nombre del ejercicio tiene espacio.
                Tooltip(
                  message: hecho
                      ? 'Hecho'
                      : futuro
                      ? 'Próximo'
                      : 'Pendiente',
                  child: Icon(
                    hecho
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked,
                    size: 22,
                    color: hecho
                        ? AppColores.exito
                        : AppColores.textoSecundario,
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColores.textoSecundario,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniaturaVacia() => Container(
    color: AppColores.primario.withValues(alpha: 0.08),
    alignment: Alignment.center,
    child: Icon(
      Icons.fitness_center_rounded,
      size: 22,
      color: AppColores.primario.withValues(alpha: 0.6),
    ),
  );

  Widget _diaDescanso() {
    final esHoy = _dia == DateTime.now().weekday - 1;
    return SizedBox(
      height: 230,
      child: FotoTarjeta(
        foto: FotoSesion.descanso.ruta,
        alineacion: FotoSesion.descanso.alineacion,
        radio: AppEspaciado.radio + 6,
        degradadoHorizontal: true,
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _chipFoto(
                Icons.self_improvement_rounded,
                esHoy ? 'HOY · DESCANSO' : _nombresDia[_dia].toUpperCase(),
              ),
              const Spacer(),
              const Text(
                'Día de descanso',
                style: TextStyle(
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.3,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: 240,
                child: Text(
                  'El músculo crece cuando descansa. Hidrátate, estira y '
                  'duerme bien para volver con todo.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _avisoOtrasRutinas() {
    final radio = BorderRadius.circular(AppEspaciado.radio);
    return Material(
      color: AppColores.primario.withValues(alpha: 0.06),
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: () => setState(() => _vista = _Vista.rutinas),
        child: Ink(
          padding: const EdgeInsets.all(AppEspaciado.md),
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(
              color: AppColores.primario.withValues(alpha: 0.18),
            ),
          ),
          child: Row(
            children: [
              Icon(Icons.description_outlined, color: AppColores.primario),
              const SizedBox(width: AppEspaciado.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '¿No es tu rutina?',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const Text(
                      'Mira todas tus rutinas o crea una nueva.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'Ver todas',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColores.primario,
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColores.primario),
            ],
          ),
        ),
      ),
    );
  }

  // --------------------------------------------------------- Mis rutinas

  List<Widget> _vistaRutinas() {
    final asignadas = _controlador.obtenerAsignadas();
    final sugeridas = _controlador.obtenerSugeridas();
    final mias = _controlador.obtenerMisRutinas();
    return [
      if (asignadas.isNotEmpty) ...[
        _tituloLista('Armadas para ti', '${asignadas.length}'),
        ...asignadas.map((r) => _tarjetaRutina(r, 'Para ti')),
        const SizedBox(height: AppEspaciado.md),
      ],
      if (sugeridas.isNotEmpty) ...[
        _tituloLista('Del gimnasio', '${sugeridas.length}'),
        ...sugeridas.map((r) => _tarjetaRutina(r, 'Del gimnasio')),
        const SizedBox(height: AppEspaciado.md),
      ],
      _tituloLista('Mis rutinas', mias.isEmpty ? null : '${mias.length}'),
      ...mias.map((r) => _tarjetaRutina(r, 'Mía')),
      _crearPrimera(hayPropias: mias.isNotEmpty),
    ];
  }

  Widget _tituloLista(String texto, String? cantidad) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4, left: 2),
      child: Row(
        children: [
          Text(
            texto,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          if (cantidad != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColores.primario.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                cantidad,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColores.primario,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _crearPrimera({required bool hayPropias}) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radio,
          onTap: _nuevaRutina,
          child: Ink(
            padding: const EdgeInsets.symmetric(
              horizontal: AppEspaciado.md,
              vertical: AppEspaciado.md + 2,
            ),
            decoration: BoxDecoration(
              borderRadius: radio,
              border: Border.all(
                color: AppColores.primario.withValues(alpha: 0.35),
                width: 1.4,
              ),
              color: AppColores.primario.withValues(alpha: 0.04),
            ),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppColores.primario.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.add_rounded, color: AppColores.primario),
                ),
                const SizedBox(width: AppEspaciado.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hayPropias
                            ? 'Crear otra rutina'
                            : 'Crea tu propia rutina',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColores.primario,
                        ),
                      ),
                      const Text(
                        'Elige los días y arma tus ejercicios',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Tarjeta de una rutina: foto según lo que se entrena, la semana en
  /// miniatura con los días de entreno y sus números.
  Widget _tarjetaRutina(Rutina r, String origen) {
    final foto = FotoSesion.para(r, r.dias.isEmpty ? null : r.dias.first);
    final hoy = DateTime.now().weekday - 1;
    final diasConEntreno = <int>{
      for (var i = 0; i < 7; i++)
        if (r.dias.any(
          (d) =>
              _normalizar(d.diaSemana) == _normalizar(_nombresDia[i]) &&
              d.ejercicios.isNotEmpty,
        ))
          i,
    };
    final minutos = r.dias.isEmpty
        ? 0
        : (r.dias.map(_minutos).reduce((a, b) => a + b) / r.dias.length)
              .round();
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 6),
      child: SizedBox(
        height: 178,
        child: FotoTarjeta(
          foto: foto.ruta,
          alineacion: foto.alineacion,
          radio: AppEspaciado.radio + 4,
          degradadoHorizontal: true,
          onTap: () => _abrirRutina(r),
          child: Padding(
            padding: const EdgeInsets.all(AppEspaciado.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: AppColores.destacado.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Text(
                        origen.toUpperCase(),
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: AppColores.destacado,
                        ),
                      ),
                    ),
                    if (diasConEntreno.contains(hoy)) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColores.exito,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'HOY',
                          style: TextStyle(
                            fontSize: 10.5,
                            letterSpacing: 0.8,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    if (!r.esSugerida)
                      GestureDetector(
                        onTap: () => _eliminarRutina(r),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ),
                  ],
                ),
                const Spacer(),
                Text(
                  r.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 21,
                    height: 1.15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.totalDias} ${r.totalDias == 1 ? 'día' : 'días'} · '
                  '${r.totalEjercicios} '
                  '${r.totalEjercicios == 1 ? 'ejercicio' : 'ejercicios'}'
                  '${minutos > 0 ? ' · ~$minutos min' : ''}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 10),
                // La semana en miniatura.
                Row(
                  children: [
                    for (var i = 0; i < 7; i++) ...[
                      if (i > 0) const SizedBox(width: 5),
                      Container(
                        width: 26,
                        height: 26,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: diasConEntreno.contains(i)
                              ? AppColores.destacado
                              : Colors.white.withValues(alpha: 0.12),
                          border: i == hoy
                              ? Border.all(color: Colors.white, width: 1.6)
                              : null,
                        ),
                        child: Text(
                          letras[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: diasConEntreno.contains(i)
                                ? (AppColores.destacado.computeLuminance() >
                                          0.45
                                      ? const Color(0xFF0E1A12)
                                      : Colors.white)
                                : Colors.white.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ----------------------------------------------------------- Historial

  List<Widget> _vistaHistorial() {
    // Cada marca es una sesión de un ejercicio; se agrupan por fecha.
    final sesiones = <(Marca, Ejercicio)>[
      for (final r in _todas)
        for (final e in r.ejercicios)
          for (final m in e.marcas) (m, e),
    ]..sort((a, b) => b.$1.fecha.compareTo(a.$1.fecha));

    if (sesiones.isEmpty) {
      return [
        const SizedBox(height: AppEspaciado.lg),
        Center(
          child: Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.history_rounded,
              size: 40,
              color: AppColores.primario,
            ),
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        Text(
          'Aún no hay sesiones',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: AppColores.textoPrincipal,
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cuando registres tus series, aquí verás\ntu avance día por día.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13.5,
            height: 1.4,
            color: AppColores.textoSecundario,
          ),
        ),
      ];
    }

    // Récord (peso más alto) de cada ejercicio, para marcarlo en la lista.
    final records = <Ejercicio, double>{};
    for (final (m, e) in sesiones) {
      if (m.peso > (records[e] ?? -1)) records[e] = m.peso;
    }
    final hoy = DateTime.now();
    final delMes = sesiones
        .where(
          (s) => s.$1.fecha.year == hoy.year && s.$1.fecha.month == hoy.month,
        )
        .toList();
    final diasDelMes = delMes
        .map((s) => '${s.$1.fecha.year}-${s.$1.fecha.month}-${s.$1.fecha.day}')
        .toSet()
        .length;
    final volumenMes = delMes.fold<double>(
      0,
      (t, s) =>
          t +
          s.$1.peso *
              (s.$1.repsPorSerie.isEmpty
                  ? s.$1.repeticiones
                  : s.$1.repsPorSerie.fold<int>(0, (a, b) => a + b)),
    );

    final porDia = <String, List<(Marca, Ejercicio)>>{};
    for (final s in sesiones) {
      final f = s.$1.fecha;
      porDia.putIfAbsent('${f.year}-${f.month}-${f.day}', () => []).add(s);
    }
    final dias = porDia.values.take(30).toList();

    return [
      _resumenHistorial(diasDelMes, volumenMes, records.length),
      const SizedBox(height: AppEspaciado.lg),
      for (var i = 0; i < dias.length; i++)
        _diaHistorial(dias[i], records, ultimo: i == dias.length - 1),
    ];
  }

  Widget _resumenHistorial(int dias, double volumen, int ejercicios) {
    String kg(double v) => v >= 1000
        ? '${(v / 1000).toStringAsFixed(v >= 10000 ? 0 : 1)} t'
        : '${v.round()} kg';
    Widget dato(String valor, String etiqueta) => Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColores.sobreRelleno,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            etiqueta,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11.5,
              color: AppColores.sobreRellenoSuave,
            ),
          ),
        ],
      ),
    );
    Widget separador() => Container(
      width: 1,
      height: 34,
      color: AppColores.sobreRelleno.withValues(alpha: 0.18),
    );
    final mes = DateFormat('MMMM', 'es').format(DateTime.now());
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
      ),
      child: Column(
        children: [
          Text(
            'TU ${mes.toUpperCase()}',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColores.sobreRellenoSuave,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              dato('$dias', dias == 1 ? 'día entrenado' : 'días entrenados'),
              separador(),
              dato(kg(volumen), 'volumen levantado'),
              separador(),
              dato('$ejercicios', 'ejercicios con marca'),
            ],
          ),
        ],
      ),
    );
  }

  /// Un día del historial en la línea de tiempo: la fecha a la izquierda y
  /// lo que entrenó a la derecha.
  Widget _diaHistorial(
    List<(Marca, Ejercicio)> dia,
    Map<Ejercicio, double> records, {
    required bool ultimo,
  }) {
    final fecha = dia.first.$1.fecha;
    final esHoy = _mismoDia(fecha, DateTime.now());
    final volumen = dia.fold<double>(
      0,
      (t, s) =>
          t +
          s.$1.peso *
              (s.$1.repsPorSerie.isEmpty
                  ? s.$1.repeticiones
                  : s.$1.repsPorSerie.fold<int>(0, (a, b) => a + b)),
    );
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Fecha + línea de tiempo.
          SizedBox(
            width: 52,
            child: Column(
              children: [
                Container(
                  width: 48,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    gradient: esHoy ? AppColores.degradadoRelleno : null,
                    color: esHoy ? null : AppColores.superficie,
                    border: esHoy
                        ? AppColores.bordeCabecera
                        : Border.all(color: AppColores.borde),
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${fecha.day}',
                        style: TextStyle(
                          fontSize: 18,
                          height: 1.1,
                          fontWeight: FontWeight.w800,
                          color: esHoy
                              ? AppColores.sobreRelleno
                              : AppColores.textoPrincipal,
                        ),
                      ),
                      Text(
                        DateFormat(
                          'MMM',
                          'es',
                        ).format(fecha).replaceAll('.', '').toUpperCase(),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: esHoy
                              ? AppColores.sobreRellenoSuave
                              : AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!ultimo)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: AppColores.borde,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm + 4),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: AppEspaciado.md),
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
                decoration: BoxDecoration(
                  color: AppColores.superficie,
                  borderRadius: BorderRadius.circular(AppEspaciado.radio),
                  border: Border.all(color: AppColores.borde),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          esHoy
                              ? 'Hoy'
                              : _capitalizar(
                                  DateFormat('EEEE', 'es').format(fecha),
                                ),
                          style: TextStyle(
                            fontSize: 14.5,
                            fontWeight: FontWeight.w800,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${volumen.round()} kg movidos',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColores.primario,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    for (final (m, e) in dia)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: AppColores.primario.withValues(
                                  alpha: 0.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: AppColores.textoPrincipal,
                                ),
                              ),
                            ),
                            if (m.peso > 0 && m.peso == records[e]) ...[
                              const Icon(
                                Icons.emoji_events_rounded,
                                size: 15,
                                color: AppColores.naranja,
                              ),
                              const SizedBox(width: 4),
                            ],
                            Text(
                              '${_num(m.peso)} kg',
                              style: TextStyle(
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                                color: AppColores.textoPrincipal,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '× ${m.repsTexto}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColores.textoSecundario,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _capitalizar(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  // ------------------------------------------------------------ Acciones

  Future<void> _eliminarRutina(Rutina r) async {
    final confirmar = await confirmarDialog(
      context,
      titulo: 'Eliminar rutina',
      mensaje: '¿Eliminar "${r.nombre}" y todos sus ejercicios?',
      icono: Icons.delete_outline,
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!confirmar) return;
    await _controlador.eliminarRutina(r.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _nuevaRutina() async {
    final datos = await showModalBottomSheet<_NuevaRutina>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => const _HojaNuevaRutina(),
    );
    if (datos == null) return;

    final id = await _controlador.crearRutina(datos.nombre, datos.descripcion);
    // Los días elegidos se crean de una vez, en orden de lunes a domingo.
    for (final i in datos.dias.toList()..sort()) {
      await _controlador.agregarDia(id, _nombresDia[i]);
    }
    if (!mounted) return;
    setState(() {});
    // Abrir el detalle para que agregue los ejercicios de cada día.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalleRutinaScreen(rutinaId: id)),
    );
    if (!mounted) return;
    setState(() {});
  }
}

class _NuevaRutina {
  final String nombre;
  final String descripcion;
  final Set<int> dias; // 0 = lunes

  const _NuevaRutina(this.nombre, this.descripcion, this.dias);
}

/// Hoja para crear una rutina SEMANAL: nombre (con planes sugeridos que ya
/// marcan sus días), los días de la semana en que se entrena y una nota.
class _HojaNuevaRutina extends StatefulWidget {
  const _HojaNuevaRutina();

  @override
  State<_HojaNuevaRutina> createState() => _HojaNuevaRutinaState();
}

class _HojaNuevaRutinaState extends State<_HojaNuevaRutina> {
  final _nombre = TextEditingController();
  final _descripcion = TextEditingController();
  final Set<int> _dias = {};
  String? _error;

  static const _letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

  /// Planes semanales comunes con sus días de entreno.
  static const _planes = <(String, Set<int>)>[
    ('Full body · 3 días', {0, 2, 4}),
    ('Torso / Pierna · 4 días', {0, 1, 3, 4}),
    ('Push · Pull · Legs', {0, 1, 2, 3, 4, 5}),
    ('Hipertrofia · 5 días', {0, 1, 2, 4, 5}),
  ];

  @override
  void dispose() {
    _nombre.dispose();
    _descripcion.dispose();
    super.dispose();
  }

  void _elegirPlan((String, Set<int>) plan) {
    setState(() {
      _nombre.text = plan.$1;
      _dias
        ..clear()
        ..addAll(plan.$2);
      _error = null;
    });
  }

  void _crear() {
    final nombre = _nombre.text.trim();
    if (nombre.isEmpty) {
      setState(() => _error = 'Ponle un nombre a tu rutina');
      return;
    }
    if (_dias.isEmpty) {
      setState(() => _error = 'Elige al menos un día de la semana');
      return;
    }
    Navigator.pop(
      context,
      _NuevaRutina(nombre, _descripcion.text.trim(), {..._dias}),
    );
  }

  Widget _etiqueta(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 8, left: 2),
    child: Text(
      texto.toUpperCase(),
      style: const TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: AppColores.textoSecundario,
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: teclado),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppEspaciado.lg,
            10,
            AppEspaciado.lg,
            AppEspaciado.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColores.borde,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppEspaciado.md + 2),
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: AppColores.degradadoRelleno,
                      border: AppColores.bordeCabecera,
                      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    ),
                    child: Icon(
                      Icons.calendar_view_week_rounded,
                      color: AppColores.sobreRelleno,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Nueva rutina semanal',
                          style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        const Text(
                          'Elige tus días; luego armas los ejercicios',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppEspaciado.lg),
              _etiqueta('Empieza con un plan'),
              SizedBox(
                height: 38,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _planes.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final plan = _planes[i];
                    final activo = _nombre.text == plan.$1;
                    return GestureDetector(
                      onTap: () => _elegirPlan(plan),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activo
                              ? AppColores.primario
                              : AppColores.primario.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: activo
                                ? AppColores.primario
                                : AppColores.primario.withValues(alpha: 0.18),
                          ),
                        ),
                        child: Text(
                          plan.$1,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: activo ? Colors.white : AppColores.primario,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: AppEspaciado.md + 2),
              _etiqueta('Nombre'),
              TextField(
                controller: _nombre,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() => _error = null),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColores.textoPrincipal,
                ),
                decoration: const InputDecoration(
                  hintText: 'Ej. Mi plan de fuerza',
                  prefixIcon: Icon(Icons.edit_note_rounded),
                ),
              ),
              const SizedBox(height: AppEspaciado.md + 2),
              Row(
                children: [
                  Expanded(child: _etiqueta('Días que entrenas')),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _dias.isEmpty
                          ? 'Ninguno'
                          : '${_dias.length} ${_dias.length == 1 ? 'día' : 'días'} por semana',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColores.primario,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  for (var i = 0; i < 7; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() {
                          _dias.contains(i) ? _dias.remove(i) : _dias.add(i);
                          _error = null;
                        }),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            gradient: _dias.contains(i)
                                ? AppColores.degradadoRelleno
                                : null,
                            color: _dias.contains(i) ? null : AppColores.fondo,
                            borderRadius: BorderRadius.circular(
                              AppEspaciado.radioSm,
                            ),
                            border: _dias.contains(i)
                                ? AppColores.bordeCabecera
                                : Border.all(color: AppColores.borde),
                          ),
                          child: Text(
                            _letras[i],
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: _dias.contains(i)
                                  ? AppColores.sobreRelleno
                                  : AppColores.textoSecundario,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'Los días que no marques quedan como descanso.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(height: AppEspaciado.md + 2),
              _etiqueta('Nota (opcional)'),
              TextField(
                controller: _descripcion,
                textCapitalization: TextCapitalization.sentences,
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText: 'Objetivo, cómo calentar, recordatorios…',
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: AppEspaciado.sm + 2),
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 17,
                      color: AppColores.moroso,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _error!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColores.moroso,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: AppEspaciado.lg),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _crear,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Crear y armar ejercicios'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
