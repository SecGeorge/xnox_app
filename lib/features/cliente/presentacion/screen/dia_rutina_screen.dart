import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/detalle_rutina_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/sesion_ejercicio_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/foto_sesion.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/temporizador_descanso.dart';

/// Un día de la rutina para entrenar: cronómetro de la sesión, notas del
/// entrenador y los ejercicios con su casilla (se marca al terminarlo) y su
/// temporizador de descanso.
class DiaRutinaScreen extends StatefulWidget {
  final int rutinaId;
  final int diaId;

  const DiaRutinaScreen({
    super.key,
    required this.rutinaId,
    required this.diaId,
  });

  @override
  State<DiaRutinaScreen> createState() => _DiaRutinaScreenState();
}

class _DiaRutinaScreenState extends State<DiaRutinaScreen> {
  final _controlador = ControladorRutinas();

  /// Inicio de la sesión en curso, por día de rutina. Estático para que el
  /// cronómetro siga corriendo si el socio sale a otra pantalla y vuelve.
  static final Map<int, DateTime> _inicioSesion = {};
  Timer? _tic;

  @override
  void initState() {
    super.initState();
    if (_inicioSesion.containsKey(widget.diaId)) _arrancarTic();
  }

  @override
  void dispose() {
    _tic?.cancel();
    super.dispose();
  }

  void _arrancarTic() {
    _tic?.cancel();
    _tic = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  (Rutina, DiaRutina)? get _datos {
    final r = _controlador.obtenerRutina(widget.rutinaId);
    if (r == null) return null;
    for (final d in r.dias) {
      if (d.id == widget.diaId) return (r, d);
    }
    return null;
  }

  bool _hechoHoy(Ejercicio e) => e.marcas.any((m) => m.esHoy);

  static String _num(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);

  @override
  Widget build(BuildContext context) {
    final datos = _datos;
    if (datos == null) {
      return const Scaffold(
        body: EstadoVacio(
          icono: Icons.error_outline,
          mensaje: 'Rutina no encontrada',
        ),
      );
    }
    final (rutina, dia) = datos;
    final total = dia.totalEjercicios;
    final hechos = dia.ejercicios.where(_hechoHoy).length;

    final foto = FotoSesion.para(rutina, dia);
    final subtitulo = FotoSesion.subtitulo(rutina, dia);
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: CustomScrollView(
        slivers: [
          // Portada con la foto de la sesión (piernas, espalda...): la flecha
          // y el menú van encima de la foto, y el título sobre ella.
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            backgroundColor: AppColores.relleno,
            foregroundColor: AppColores.sobreRelleno,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: _botonFoto(
                Icons.arrow_back_rounded,
                'Volver',
                () => Navigator.pop(context),
              ),
            ),
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: PopupMenuButton<String>(
                  tooltip: 'Más opciones',
                  color: AppColores.superficie,
                  position: PopupMenuPosition.under,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  ),
                  onSelected: (_) async {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            DetalleRutinaScreen(rutinaId: rutina.id),
                      ),
                    );
                    if (mounted) setState(() {});
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'rutina',
                      child: Row(
                        children: [
                          Icon(
                            rutina.esSugerida
                                ? Icons.calendar_view_week_rounded
                                : Icons.edit_rounded,
                            size: 20,
                            color: AppColores.primario,
                          ),
                          const SizedBox(width: 10),
                          Text(
                            rutina.esSugerida
                                ? 'Ver rutina completa'
                                : 'Editar rutina',
                          ),
                        ],
                      ),
                    ),
                  ],
                  child: _circuloFoto(Icons.more_vert_rounded),
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    foto.ruta,
                    fit: BoxFit.cover,
                    alignment: foto.alineacion,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0.45),
                          Colors.black.withValues(alpha: 0.10),
                          Color.alphaBlend(
                            AppColores.primario.withValues(alpha: 0.35),
                            Colors.black.withValues(alpha: 0.85),
                          ),
                        ],
                        stops: const [0, 0.4, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: AppEspaciado.md,
                    right: AppEspaciado.md,
                    bottom: AppEspaciado.md + 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.35),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: AppColores.destacado.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          child: Text(
                            dia.diaSemana.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.5,
                              letterSpacing: 1,
                              fontWeight: FontWeight.w800,
                              color: AppColores.destacado,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (subtitulo != null)
                          Text(
                            subtitulo,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.8),
                            ),
                          ),
                        Text(
                          FotoSesion.titulo(rutina, dia),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 27,
                            height: 1.15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.4,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Marca la casilla de cada ejercicio al terminarlo.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              AppEspaciado.md,
              AppEspaciado.md + 2,
              AppEspaciado.md,
              AppEspaciado.xl,
            ),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _sesion(hechos, total),
                if (rutina.descripcion.trim().isNotEmpty) ...[
                  const SizedBox(height: AppEspaciado.md),
                  _notas(rutina),
                ],
                const SizedBox(height: AppEspaciado.lg),
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center_rounded,
                      size: 20,
                      color: AppColores.primario,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'EJERCICIOS',
                      style: TextStyle(
                        fontSize: 12,
                        letterSpacing: 1.3,
                        fontWeight: FontWeight.w800,
                        color: AppColores.primario,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$total ${total == 1 ? 'ejercicio' : 'ejercicios'}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppEspaciado.sm + 4),
                for (final e in dia.ejercicios) _tarjetaEjercicio(rutina, e),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  /// Botón redondo oscuro para ir encima de la foto de portada.
  Widget _circuloFoto(IconData icono) => Container(
    width: 40,
    height: 40,
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.4),
      shape: BoxShape.circle,
    ),
    child: Icon(icono, size: 22, color: Colors.white),
  );

  Widget _botonFoto(IconData icono, String ayuda, VoidCallback onTap) {
    return Tooltip(
      message: ayuda,
      child: InkResponse(onTap: onTap, radius: 24, child: _circuloFoto(icono)),
    );
  }

  /// Avance del día y cronómetro de la sesión.
  Widget _sesion(int hechos, int total) {
    final inicio = _inicioSesion[widget.diaId];
    final transcurrido = inicio == null
        ? Duration.zero
        : DateTime.now().difference(inicio);
    String dos(int n) => n.toString().padLeft(2, '0');
    final reloj = transcurrido.inHours > 0
        ? '${transcurrido.inHours}:${dos(transcurrido.inMinutes % 60)}:'
              '${dos(transcurrido.inSeconds % 60)}'
        : '${dos(transcurrido.inMinutes)}:${dos(transcurrido.inSeconds % 60)}';
    final porcentaje = total == 0 ? 0.0 : hechos / total;

    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    inicio == null ? 'SESIÓN' : 'EN CURSO',
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                      color: AppColores.sobreRellenoSuave,
                    ),
                  ),
                  Text(
                    reloj,
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: AppColores.sobreRelleno,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              Material(
                color: AppColores.sobreRelleno,
                shape: const StadiumBorder(),
                child: InkWell(
                  customBorder: const StadiumBorder(),
                  onTap: () {
                    setState(() {
                      if (inicio == null) {
                        _inicioSesion[widget.diaId] = DateTime.now();
                        _arrancarTic();
                      } else {
                        _inicioSesion.remove(widget.diaId);
                        _tic?.cancel();
                        mostrarMensaje(
                          context,
                          '¡Sesión terminada! Entrenaste $reloj',
                          tipo: TipoMensaje.exito,
                        );
                      }
                    });
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          inicio == null
                              ? Icons.play_arrow_rounded
                              : Icons.flag_rounded,
                          size: 19,
                          color: AppColores.relleno,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          inicio == null ? 'Empezar' : 'Terminar',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            color: AppColores.relleno,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              Text(
                '$hechos / $total completados',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: AppColores.sobreRelleno,
                ),
              ),
              const Spacer(),
              Text(
                '${(porcentaje * 100).round()}%',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: AppColores.sobreRelleno,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: porcentaje,
              minHeight: 7,
              color: AppColores.sobreRelleno,
              backgroundColor: AppColores.sobreRelleno.withValues(alpha: 0.18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _notas(Rutina r) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColores.primario.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.primario.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sticky_note_2_rounded,
                size: 18,
                color: AppColores.primario,
              ),
              const SizedBox(width: 6),
              Text(
                r.esSugerida ? 'NOTAS DEL ENTRENADOR' : 'MIS NOTAS',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1,
                  fontWeight: FontWeight.w800,
                  color: AppColores.primario,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            r.descripcion.trim(),
            style: TextStyle(
              fontSize: 13.5,
              height: 1.45,
              color: AppColores.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tarjetaEjercicio(Rutina r, Ejercicio e) {
    final hecho = _hechoHoy(e);
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          color: AppColores.superficie,
          borderRadius: radio,
          border: Border.all(
            color: hecho
                ? AppColores.exito.withValues(alpha: 0.45)
                : AppColores.borde,
            width: hecho ? 1.4 : 1,
          ),
        ),
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(AppEspaciado.radio + 2),
              ),
              onTap: () => _abrirEjercicio(r, e),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(6, 10, 8, 8),
                child: Row(
                  children: [
                    // Casilla: marcar el ejercicio como hecho hoy.
                    IconButton(
                      onPressed: () => _alternar(r, e),
                      icon: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: hecho
                            ? const Icon(
                                Icons.check_circle_rounded,
                                key: ValueKey(true),
                                size: 28,
                                color: AppColores.exito,
                              )
                            : const Icon(
                                Icons.radio_button_unchecked_rounded,
                                key: ValueKey(false),
                                size: 28,
                                color: AppColores.textoSecundario,
                              ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                      child: SizedBox(
                        width: 62,
                        height: 62,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            (e.imagenUrl ?? '').isEmpty
                                ? Container(
                                    color: AppColores.primario.withValues(
                                      alpha: 0.08,
                                    ),
                                    child: Icon(
                                      Icons.fitness_center_rounded,
                                      color: AppColores.primario.withValues(
                                        alpha: 0.6,
                                      ),
                                    ),
                                  )
                                : Image.network(
                                    e.imagenUrl!,
                                    fit: BoxFit.cover,
                                    cacheWidth: 200,
                                    errorBuilder: (_, _, _) => Container(
                                      color: AppColores.primario.withValues(
                                        alpha: 0.08,
                                      ),
                                    ),
                                  ),
                            if (e.tieneVideo)
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow_rounded,
                                    size: 18,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AppEspaciado.sm + 4),
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
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              decoration: hecho
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: AppColores.textoSecundario,
                              color: hecho
                                  ? AppColores.textoSecundario
                                  : AppColores.textoPrincipal,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Text(
                                '${e.series} × ${e.repeticiones}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColores.primario,
                                ),
                              ),
                              if (e.ultimaMarca != null) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '· ${_num(e.ultimaMarca!.peso)} kg',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColores.textoSecundario,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
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
            Divider(height: 1, color: AppColores.borde),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: TemporizadorDescanso(
                ejercicioId: e.id,
                porDefecto: e.descansoSeg,
                compacto: true,
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Marcar la casilla: si ya entrenó antes ese ejercicio, se registra la
  /// sesión de hoy con su último peso y las reps del objetivo (se puede
  /// ajustar luego). Sin peso previo, o si ya está hecho, abre el ejercicio.
  Future<void> _alternar(Rutina r, Ejercicio e) async {
    final ultima = e.ultimaMarca;
    if (_hechoHoy(e) || ultima == null) {
      await _abrirEjercicio(r, e);
      return;
    }
    await _controlador.registrarMarca(
      e.id,
      ultima.peso,
      List.filled(e.series, e.repeticiones),
    );
    if (!mounted) return;
    setState(() {});
    mostrarMensaje(
      context,
      '${e.nombre}: ${e.series} × ${e.repeticiones} con ${_num(ultima.peso)} kg. '
      'Toca el ejercicio para ajustarlo.',
      tipo: TipoMensaje.exito,
    );
  }
}
