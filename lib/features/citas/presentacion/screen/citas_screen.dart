import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/citas/datos/repositorio_citas.dart';
import 'package:xnox_app/features/citas/dominio/cita.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';

/// Citas de una categoría (masajes, nutricionista…): el socio elige qué
/// reservar, el día y un turno libre; abajo ve y cancela sus citas.
class CitasScreen extends StatefulWidget {
  final Especialidad especialidad;
  final RepositorioCitas? repositorio;

  const CitasScreen({super.key, required this.especialidad, this.repositorio});

  @override
  State<CitasScreen> createState() => _CitasScreenState();
}

class _CitasScreenState extends State<CitasScreen> {
  late final _repo = widget.repositorio ?? RepositorioCitas();

  CatalogoCitas _catalogo = CatalogoCitas.vacio;
  TipoCita? _tipo;
  int? _profesionalId;
  List<TurnoCita> _turnos = const [];
  late DateTime _dia = _soloFecha(DateTime.now());
  bool _cargando = true;
  bool _cargandoTurnos = false;
  String? _error;
  bool _procesando = false;

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  List<TipoCita> get _tipos => _catalogo.tipos
      .where((t) => t.especialidad == widget.especialidad)
      .toList();

  List<CitaSocio> get _misCitas =>
      _catalogo.citas
          .where((c) => c.especialidad == widget.especialidad)
          .toList()
        ..sort((a, b) {
          // Pendientes primero (la más cercana arriba), luego el historial
          if (a.pendiente != b.pendiente) return a.pendiente ? -1 : 1;
          return a.pendiente
              ? a.inicio.compareTo(b.inicio)
              : b.inicio.compareTo(a.inicio);
        });

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _error = null);
    try {
      final catalogo = await _repo.catalogo();
      if (!mounted) return;
      setState(() {
        _catalogo = catalogo;
        final tipos = _tipos;
        _tipo =
            tipos.where((t) => t.id == _tipo?.id).firstOrNull ??
            (tipos.isEmpty ? null : tipos.first);
        _cargando = false;
      });
      await _cargarTurnos();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar las citas';
        _cargando = false;
      });
    }
  }

  Future<void> _cargarTurnos() async {
    final tipo = _tipo;
    if (tipo == null || !tipo.puedeReservar) {
      setState(() => _turnos = const []);
      return;
    }
    setState(() => _cargandoTurnos = true);
    try {
      final turnos = await _repo.turnos(tipo);
      if (!mounted || tipo.id != _tipo?.id) return;
      setState(() {
        _turnos = turnos;
        // Si el día elegido ya no tiene turnos, salta al primero que tenga
        if (_delDia(_dia).isEmpty && _filtrados.isNotEmpty) {
          _dia = _soloFecha(_filtrados.first.fecha);
        }
      });
    } catch (_) {
      if (mounted) setState(() => _turnos = const []);
    }
    if (mounted) setState(() => _cargandoTurnos = false);
  }

  List<TurnoCita> get _filtrados => _turnos
      .where((t) => _profesionalId == null || t.profesionalId == _profesionalId)
      .toList();

  List<TurnoCita> _delDia(DateTime dia) =>
      _filtrados.where((t) => _soloFecha(t.fecha) == dia).toList();

  List<DateTime> get _dias => List.generate(
    RepositorioCitas.diasAnticipacion,
    (i) => _soloFecha(DateTime.now()).add(Duration(days: i)),
  );

  // ------------------------------------------------------------- Textos

  static String _soles(double v) =>
      'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  static String _capital(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  String _cuando(DateTime fecha, String hora) {
    final hoy = _soloFecha(DateTime.now());
    final dif = _soloFecha(fecha).difference(hoy).inDays;
    final nombre = dif == 0
        ? 'Hoy'
        : dif == 1
        ? 'Mañana'
        : _capital(DateFormat("EEEE d 'de' MMMM", 'es').format(fecha));
    return '$nombre · $hora';
  }

  // ------------------------------------------------------------- Acciones

  Future<void> _reservar(TurnoCita turno) async {
    final tipo = _tipo!;
    final nota = TextEditingController();
    final confirmado = await mostrarHojaModerna<bool>(
      context,
      builder: (ctx) => HojaModerna(
        icono: widget.especialidad.icono,
        titulo: tipo.nombre,
        subtitulo:
            '${_cuando(turno.fecha, turno.horaInicio)} – ${turno.horaFin}',
        pie: BotonHoja(
          texto: tipo.incluida
              ? 'Reservar mi cita'
              : 'Reservar · pago ${_soles(tipo.precio ?? 0)}',
          icono: Icons.check_rounded,
          onPressed: () => Navigator.pop(ctx, true),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _avisoPago(tipo),
            const SizedBox(height: AppEspaciado.md),
            Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 18,
                  color: AppColores.textoSecundario,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Te atiende ${turno.profesional}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: nota,
              maxLength: 255,
              maxLines: 2,
              minLines: 1,
              decoration: InputDecoration(
                labelText: 'Motivo (opcional)',
                hintText: widget.especialidad == Especialidad.nutricion
                    ? 'Quiero bajar de peso, primera consulta…'
                    : 'Dolor de espalda, contractura…',
                border: const OutlineInputBorder(),
              ),
            ),
            Text(
              tipo.cancelarHoras > 0
                  ? 'Si no puedes ir, cancela hasta ${tipo.cancelarHoras} h antes.'
                  : 'Si no puedes ir, cancela antes de la hora.',
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
    final texto = nota.text.trim();
    nota.dispose();
    if (confirmado != true || !mounted) return;
    await _ejecutar(() => _repo.reservar(tipo, turno, texto));
  }

  Future<void> _cancelar(CitaSocio c) async {
    final ok = await confirmarDialog(
      context,
      titulo: '¿Cancelar tu cita?',
      mensaje:
          '${c.tipo} · ${_cuando(c.fecha, c.horaInicio)}. El turno queda libre.',
      icono: Icons.event_busy_rounded,
      textoConfirmar: 'Sí, cancelar',
      textoCancelar: 'No',
      peligro: true,
    );
    if (!ok || !mounted) return;
    await _ejecutar(() => _repo.cancelar(c));
  }

  Future<void> _ejecutar(Future<ResultadoClase> Function() accion) async {
    setState(() => _procesando = true);
    final r = await accion();
    if (!mounted) return;
    mostrarMensaje(
      context,
      r.mensaje,
      tipo: r.exito ? TipoMensaje.exito : TipoMensaje.advertencia,
    );
    await _cargar();
    if (mounted) setState(() => _procesando = false);
  }

  // ------------------------------------------------------------- Vista

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: 40,
      children: [
        CabeceraApp(
          titulo: widget.especialidad.nombre,
          subtitulo: 'Elige qué reservar y un turno libre',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        ..._contenido(),
      ],
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
    final tipos = _tipos;
    final misCitas = _misCitas;
    if (tipos.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.event_note_rounded,
          titulo: 'No hay citas disponibles',
          texto: 'Tu gimnasio aún no publica turnos para esta categoría.',
        ),
      ];
    }
    final tipo = _tipo!;
    return [
      if (misCitas.any((c) => c.pendiente)) ...[
        const TituloSeccion(
          icono: Icons.bookmark_added_rounded,
          titulo: 'Tus citas',
        ),
        for (final c in misCitas.where((c) => c.pendiente)) ...[
          _tarjetaMiCita(c),
          const SizedBox(height: AppEspaciado.sm),
        ],
        const SizedBox(height: AppEspaciado.md),
      ],
      if (tipos.length > 1) ...[
        _selectorTipos(tipos),
        const SizedBox(height: AppEspaciado.md),
      ],
      _infoTipo(tipo),
      const SizedBox(height: AppEspaciado.md),
      if (!tipo.puedeReservar)
        VacioApp(
          icono: Icons.lock_rounded,
          titulo: 'No puedes reservar esta cita',
          texto: tipo.motivo,
        )
      else ...[
        if (tipo.profesionales.length > 1) ...[
          _selectorProfesional(tipo),
          const SizedBox(height: AppEspaciado.sm + 4),
        ],
        _selectorDias(),
        const SizedBox(height: AppEspaciado.md),
        ..._turnosDelDia(),
      ],
      if (misCitas.any((c) => !c.pendiente)) ...[
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(icono: Icons.history_rounded, titulo: 'Historial'),
        for (final c in misCitas.where((c) => !c.pendiente).take(10)) ...[
          _tarjetaMiCita(c),
          const SizedBox(height: AppEspaciado.sm),
        ],
      ],
    ];
  }

  Widget _selectorTipos(List<TipoCita> tipos) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: tipos.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final t = tipos[i];
          return ChoiceChip(
            label: Text(t.nombre),
            selected: t.id == _tipo?.id,
            onSelected: (_) {
              setState(() {
                _tipo = t;
                _profesionalId = null;
                _turnos = const [];
              });
              _cargarTurnos();
            },
          );
        },
      ),
    );
  }

  Widget _infoTipo(TipoCita t) {
    return TarjetaPlana(
      colorBorde: t.color.withValues(alpha: 0.5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              _chipPago(t),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            [
              t.duracionTexto,
              t.profesionales.map((p) => p.nombre).join(', '),
            ].where((x) => x.isNotEmpty).join(' · '),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColores.textoSecundario,
            ),
          ),
          if (t.descripcion.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              t.descripcion,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColores.textoPrincipal,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chipPago(TipoCita t) {
    final (texto, color) = t.incluida
        ? ('Incluida', AppColores.exito)
        : t.precio != null
        ? (_soles(t.precio!), AppColores.naranja)
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

  Widget _selectorProfesional(TipoCita t) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Cualquiera'),
          selected: _profesionalId == null,
          onSelected: (_) => setState(() => _profesionalId = null),
        ),
        for (final p in t.profesionales)
          ChoiceChip(
            label: Text(p.nombre),
            selected: _profesionalId == p.id,
            onSelected: (_) => setState(() => _profesionalId = p.id),
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
          final hay = _delDia(dia).isNotEmpty;
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
              child: Opacity(
                opacity: hay || activo ? 1 : 0.45,
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
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: hay
                            ? (activo
                                      ? AppColores.sobreRelleno
                                      : AppColores.primario)
                                  .withValues(alpha: 0.55)
                            : Colors.transparent,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _turnosDelDia() {
    if (_cargandoTurnos) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 30),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    final turnos = _delDia(_dia);
    if (turnos.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.event_busy_rounded,
          titulo: 'Sin turnos libres este día',
          texto: 'Elige otro día (los que tienen punto tienen turnos).',
        ),
      ];
    }
    final varios = _tipo!.profesionales.length > 1 && _profesionalId == null;
    return [
      TituloSeccion(
        icono: Icons.schedule_rounded,
        titulo: _capital(DateFormat("EEEE d 'de' MMMM", 'es').format(_dia)),
        detalle: '${turnos.length} ${turnos.length == 1 ? 'turno' : 'turnos'}',
      ),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final t in turnos)
            SizedBox(
              width: varios ? 150 : 96,
              child: OutlinedButton(
                onPressed: _procesando ? null : () => _reservar(t),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      t.horaInicio,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (varios)
                      Text(
                        t.profesional,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    ];
  }

  Widget _tarjetaMiCita(CitaSocio c) {
    final (estado, color) = switch (c.estado) {
      2 => ('Atendida', AppColores.exito),
      3 => ('No asististe', AppColores.moroso),
      _ =>
        c.pasada
            ? ('Pendiente', AppColores.vencido)
            : ('Reservada', AppColores.exito),
    };
    return Opacity(
      opacity: c.pendiente ? 1 : 0.7,
      child: TarjetaPlana(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        colorBorde: c.pendiente ? c.color.withValues(alpha: 0.5) : null,
        child: Row(
          children: [
            Container(
              width: 6,
              height: 44,
              decoration: BoxDecoration(
                color: c.color,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.tipo,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  Text(
                    '${_cuando(c.fecha, c.horaInicio)} · ${c.profesional}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  Text(
                    c.incluida
                        ? estado
                        : '$estado · ${c.pagada ? 'Pagada' : 'Pagas ${_soles(c.monto)} en recepción'}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
            if (c.puedeCancelar)
              TextButton(
                onPressed: _procesando ? null : () => _cancelar(c),
                style: TextButton.styleFrom(foregroundColor: AppColores.moroso),
                child: const Text('Cancelar'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _avisoPago(TipoCita t) {
    final color = t.incluida ? AppColores.exito : AppColores.naranja;
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
            t.incluida ? Icons.verified_rounded : Icons.payments_rounded,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              t.incluida
                  ? 'Incluida en tu membresía: no pagas nada extra.'
                  : 'Pagas ${_soles(t.precio ?? 0)} en recepción el día de tu cita.',
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
