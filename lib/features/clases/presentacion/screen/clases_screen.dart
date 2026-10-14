import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/clases/datos/repositorio_clases.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';

/// Clases del gimnasio (zumba, spinning…): el socio elige el día, ve los
/// cupos y reserva o cancela su lugar. Si la clase no viene en su membresía
/// se le avisa cuánto paga en recepción antes de reservar.
class ClasesScreen extends StatefulWidget {
  /// Solo para pruebas: por defecto habla con `clases.php`.
  final RepositorioClases? repositorio;

  const ClasesScreen({super.key, this.repositorio});

  @override
  State<ClasesScreen> createState() => _ClasesScreenState();
}

class _ClasesScreenState extends State<ClasesScreen> {
  late final _repo = widget.repositorio ?? RepositorioClases();
  List<SesionClase> _sesiones = const [];
  bool _cargando = true;
  String? _error;
  late DateTime _dia = _soloFecha(DateTime.now());

  /// Sesión que se está reservando o cancelando (deshabilita su botón).
  String? _procesando;

  static String _clave(SesionClase s) =>
      '${s.horarioId}|${DateFormat('yyyy-MM-dd').format(s.fecha)}';

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _sesiones.isEmpty;
      _error = null;
    });
    try {
      final sesiones = await _repo.agenda();
      if (!mounted) return;
      setState(() {
        _sesiones = sesiones;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las clases';
        _cargando = false;
      });
    }
  }

  List<DateTime> get _dias => List.generate(
    RepositorioClases.diasAnticipacion,
    (i) => _soloFecha(DateTime.now()).add(Duration(days: i)),
  );

  List<SesionClase> _delDia(DateTime dia) =>
      _sesiones.where((s) => _soloFecha(s.fecha) == dia).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  List<SesionClase> get _misReservas =>
      _sesiones.where((s) => s.reservaEstado == 1 && !s.pasada).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));

  // ------------------------------------------------------------- Textos

  static String _soles(double v) =>
      'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  String _cuando(SesionClase s) {
    final hoy = _soloFecha(DateTime.now());
    final dia = _soloFecha(s.fecha);
    final dif = dia.difference(hoy).inDays;
    final nombre = dif == 0
        ? 'Hoy'
        : dif == 1
        ? 'Mañana'
        : _capital(DateFormat('EEEE d', 'es').format(dia));
    return '$nombre · ${s.horaInicio}';
  }

  static String _capital(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  // ------------------------------------------------------------- Acciones

  Future<void> _reservar(SesionClase s) async {
    final confirmado = await mostrarHojaModerna<bool>(
      context,
      builder: (ctx) => HojaModerna(
        icono: Icons.event_available_rounded,
        titulo: 'Reservar ${s.nombre}',
        subtitulo: '${_cuando(s)} – ${s.horaFin}',
        pie: BotonHoja(
          texto: s.incluida
              ? 'Reservar mi lugar'
              : 'Reservar · pago ${_soles(s.precio ?? 0)}',
          icono: Icons.check_rounded,
          onPressed: () => Navigator.pop(ctx, true),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avisoAcceso(s),
            if (s.descripcion.isNotEmpty) ...[
              const SizedBox(height: AppEspaciado.md),
              Text(
                s.descripcion,
                style: TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ],
            const SizedBox(height: AppEspaciado.md),
            Text(
              s.cancelarHoras > 0
                  ? 'Si no puedes ir, cancela hasta ${s.cancelarHoras} h antes '
                        'para liberar el cupo.'
                  : 'Si no puedes ir, cancela antes de que empiece para '
                        'liberar el cupo.',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColores.textoSecundario,
              ),
            ),
            const SizedBox(height: AppEspaciado.md),
          ],
        ),
      ),
    );
    if (confirmado != true || !mounted) return;
    await _ejecutar(s, () => _repo.reservar(s));
  }

  Future<void> _cancelar(SesionClase s) async {
    final ok = await confirmarDialog(
      context,
      titulo: '¿Cancelar tu reserva?',
      mensaje:
          '${s.nombre} · ${_cuando(s)}. Tu cupo queda libre para otro socio.',
      icono: Icons.event_busy_rounded,
      textoConfirmar: 'Sí, cancelar',
      textoCancelar: 'No',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await _ejecutar(s, () => _repo.cancelar(s));
  }

  Future<void> _ejecutar(
    SesionClase s,
    Future<ResultadoClase> Function() accion,
  ) async {
    setState(() => _procesando = _clave(s));
    final r = await accion();
    if (!mounted) return;
    mostrarMensaje(
      context,
      r.mensaje,
      tipo: r.exito ? TipoMensaje.exito : TipoMensaje.advertencia,
    );
    await _cargar();
    if (mounted) setState(() => _procesando = null);
  }

  bool _estaProcesando(SesionClase s) => _procesando == _clave(s);

  // ------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    final proximas = _misReservas;
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: 40,
      children: [
        const CabeceraApp(
          titulo: 'Clases',
          subtitulo: 'Reserva tu lugar en las clases del gimnasio',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.motivacion,
          etiqueta: proximas.isEmpty ? 'Clases grupales' : 'Tu próxima clase',
          titulo: _cargando
              ? '…'
              : proximas.isEmpty
              ? 'Elige una clase'
              : proximas.first.nombre,
          texto: proximas.isEmpty
              ? 'Mira el horario de la semana y separa tu cupo.'
              : '${_cuando(proximas.first)}'
                    '${proximas.length > 1 ? ' · tienes ${proximas.length} reservas' : ''}',
        ),
        const SizedBox(height: AppEspaciado.md),
        if (proximas.length > 1) ...[
          _misReservasCarrusel(proximas),
          const SizedBox(height: AppEspaciado.md),
        ],
        _selectorDias(),
        const SizedBox(height: AppEspaciado.md),
        ..._contenido(),
      ],
    );
  }

  Widget _misReservasCarrusel(List<SesionClase> reservas) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const TituloSeccion(
          icono: Icons.bookmark_added_rounded,
          titulo: 'Mis reservas',
        ),
        SizedBox(
          height: 76,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: reservas.length,
            separatorBuilder: (_, _) => const SizedBox(width: 10),
            itemBuilder: (_, i) {
              final s = reservas[i];
              return SizedBox(
                width: 200,
                child: TarjetaPlana(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  colorBorde: s.color.withValues(alpha: 0.5),
                  onTap: () => setState(() => _dia = _soloFecha(s.fecha)),
                  child: Row(
                    children: [
                      Container(
                        width: 6,
                        decoration: BoxDecoration(
                          color: s.color,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              s.nombre,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: AppColores.textoPrincipal,
                              ),
                            ),
                            Text(
                              _cuando(s),
                              style: const TextStyle(
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
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _selectorDias() {
    return SizedBox(
      height: 74,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _dias.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final dia = _dias[i];
          final activo = dia == _dia;
          final sesiones = _delDia(dia);
          final reservado = sesiones.any((s) => s.reservaEstado == 1);
          return GestureDetector(
            onTap: () => setState(() => _dia = dia),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 56,
              decoration: BoxDecoration(
                gradient: activo ? AppColores.degradadoRelleno : null,
                color: activo ? null : AppColores.superficie,
                borderRadius: BorderRadius.circular(AppEspaciado.radio),
                border: activo
                    ? AppColores.bordeCabecera
                    : Border.all(color: AppColores.borde),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    i == 0
                        ? 'Hoy'
                        : _capital(DateFormat('EEE', 'es').format(dia))
                              .replaceAll('.', ''),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: activo
                          ? AppColores.sobreRellenoSuave
                          : AppColores.textoSecundario,
                    ),
                  ),
                  Text(
                    '${dia.day}',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: activo
                          ? AppColores.sobreRelleno
                          : AppColores.textoPrincipal,
                    ),
                  ),
                  // Punto: hay clases ese día (lleno si ya reservaste)
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: sesiones.isEmpty
                          ? Colors.transparent
                          : reservado
                          ? AppColores.naranja
                          : (activo
                                    ? AppColores.sobreRelleno
                                    : AppColores.primario)
                                .withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        VacioApp(
          icono: Icons.cloud_off_rounded,
          titulo: _error!,
          texto: 'Desliza hacia abajo para reintentar.',
        ),
      ];
    }
    if (_sesiones.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.event_note_rounded,
          titulo: 'Tu gimnasio aún no tiene clases',
          texto: 'Cuando publique su horario de clases, lo verás aquí.',
        ),
      ];
    }
    final sesiones = _delDia(_dia);
    if (sesiones.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.event_busy_rounded,
          titulo: 'No hay clases este día',
          texto: 'Elige otro día de la semana.',
        ),
      ];
    }
    return [
      TituloSeccion(
        icono: Icons.event_rounded,
        titulo: _capital(DateFormat("EEEE d 'de' MMMM", 'es').format(_dia)),
        detalle:
            '${sesiones.length} ${sesiones.length == 1 ? 'clase' : 'clases'}',
      ),
      for (final s in sesiones) ...[
        _tarjeta(s),
        const SizedBox(height: AppEspaciado.sm + 4),
      ],
    ];
  }

  Widget _tarjeta(SesionClase s) {
    final ocupacion = s.aforo == 0
        ? 0.0
        : (s.ocupados / s.aforo).clamp(0.0, 1.0);
    return Opacity(
      opacity: s.pasada && !s.reservada ? 0.55 : 1,
      child: TarjetaPlana(
        padding: EdgeInsets.zero,
        colorBorde: s.reservada ? s.color.withValues(alpha: 0.6) : null,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 6,
                decoration: BoxDecoration(
                  color: s.color,
                  borderRadius: const BorderRadius.horizontal(
                    left: Radius.circular(AppEspaciado.radio + 2),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            s.horaInicio,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: AppColores.textoPrincipal,
                            ),
                          ),
                          Text(
                            ' – ${s.horaFin}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                          const Spacer(),
                          _chipAcceso(s),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        s.nombre,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      if (s.entrenador.isNotEmpty || s.salon.isNotEmpty)
                        Text(
                          [
                            s.entrenador,
                            s.salon,
                          ].where((t) => t.isNotEmpty).join(' · '),
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          value: ocupacion,
                          minHeight: 6,
                          backgroundColor: s.color.withValues(alpha: 0.12),
                          color: s.llena ? AppColores.moroso : s.color,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              s.llena
                                  ? 'Clase llena · ${s.aforo} cupos'
                                  : '${s.libres} de ${s.aforo} cupos libres',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: s.llena
                                    ? AppColores.moroso
                                    : AppColores.textoSecundario,
                              ),
                            ),
                          ),
                          _accion(s),
                        ],
                      ),
                      if (!s.reservada &&
                          s.motivo.isNotEmpty &&
                          !s.pasada &&
                          !s.llena)
                        Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Text(
                            s.motivo,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.naranja,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipAcceso(SesionClase s) {
    final (texto, color) = s.reservada && (s.reservaMonto ?? 0) > 0
        ? ('Pagas ${_soles(s.reservaMonto!)}', AppColores.naranja)
        : s.incluida
        ? ('Incluida', AppColores.exito)
        : s.precio != null
        ? (_soles(s.precio!), AppColores.naranja)
        : ('No incluida', AppColores.vencido);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  Widget _accion(SesionClase s) {
    final cargando = _estaProcesando(s);
    if (s.reservada) {
      final estado = switch (s.reservaEstado) {
        2 => 'Asististe',
        3 => 'Faltaste',
        _ => 'Reservada',
      };
      if (s.puedeCancelar) {
        return OutlinedButton.icon(
          onPressed: cargando ? null : () => _cancelar(s),
          icon: const Icon(Icons.check_circle_rounded, size: 18),
          label: Text(cargando ? '…' : 'Reservada · cancelar'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColores.exito,
            side: BorderSide(color: AppColores.exito.withValues(alpha: 0.5)),
            visualDensity: VisualDensity.compact,
            shape: const StadiumBorder(),
          ),
        );
      }
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            s.reservaEstado == 3
                ? Icons.cancel_rounded
                : Icons.check_circle_rounded,
            size: 18,
            color: s.reservaEstado == 3 ? AppColores.moroso : AppColores.exito,
          ),
          const SizedBox(width: 4),
          Text(
            estado,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: s.reservaEstado == 3
                  ? AppColores.moroso
                  : AppColores.exito,
            ),
          ),
        ],
      );
    }
    if (s.pasada) return const SizedBox.shrink();
    return FilledButton(
      onPressed: s.puedeReservar && !cargando ? () => _reservar(s) : null,
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        shape: const StadiumBorder(),
      ),
      child: Text(
        cargando
            ? '…'
            : s.llena
            ? 'Llena'
            : 'Reservar',
      ),
    );
  }

  Widget _avisoAcceso(SesionClase s) {
    final incluida = s.incluida;
    final color = incluida ? AppColores.exito : AppColores.naranja;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(
            incluida ? Icons.verified_rounded : Icons.payments_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              incluida
                  ? 'Incluida en tu membresía: no pagas nada extra.'
                  : 'Esta clase no viene en tu membresía. Pagas '
                        '${_soles(s.precio ?? 0)} en recepción.',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
