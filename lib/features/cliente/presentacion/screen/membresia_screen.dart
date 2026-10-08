import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/asistencia_cliente.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_asistencias.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_membresia.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/asistencias_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/cliente_publicidad_screen.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/modal_vencimiento.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/pago_yape/presentacion/pago_yape_screen.dart';

/// Membresía del socio: portada con foto (plan, estado y días que le quedan),
/// aviso de deuda o de renovación, detalles del contrato y su asistencia.
class MembresiaScreen extends StatefulWidget {
  const MembresiaScreen({super.key});

  @override
  State<MembresiaScreen> createState() => _MembresiaScreenState();
}

class _MembresiaScreenState extends State<MembresiaScreen> {
  final _controlador = ControladorMembresia();
  final _asistencias = ControladorAsistencias();
  MembresiaCliente? _membresia;
  List<AsistenciaCliente> _visitas = const [];
  bool _isLoading = true;

  static final _soles = NumberFormat('#,##0.00', 'es');

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    if (_membresia == null) setState(() => _isLoading = true);
    final resultados = await Future.wait([
      _controlador.obtenerMembresia(),
      _asistencias.obtenerAsistencias(),
    ]);
    if (!mounted) return;
    setState(() {
      _membresia = resultados[0] as MembresiaCliente?;
      _visitas = resultados[1] as List<AsistenciaCliente>;
      _isLoading = false;
    });
  }

  bool get _tieneContrato => _membresia?.contratoId != null;

  @override
  Widget build(BuildContext context) {
    final m = _membresia;
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        child: _isLoading
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
                    if (m == null || !_tieneContrato)
                      _sinMembresia()
                    else ...[
                      _portada(m),
                      if (m.tieneDeuda) ...[
                        const SizedBox(height: AppEspaciado.sm + 4),
                        _avisoDeuda(m),
                      ],
                      if (m.diasRestantes < 0 || debeAvisarVencimiento(m)) ...[
                        const SizedBox(height: AppEspaciado.sm + 4),
                        _avisoRenovar(m),
                      ],
                      const SizedBox(height: AppEspaciado.lg),
                      _tituloSeccion(Icons.receipt_long_rounded, 'Tu plan'),
                      _detalles(m),
                      const SizedBox(height: AppEspaciado.lg),
                      _tituloSeccion(
                        Icons.calendar_month_rounded,
                        'Tu asistencia',
                        accion: 'Ver todas',
                        onAccion: _abrirAsistencias,
                      ),
                      _asistencia(m),
                    ],
                  ],
                ),
              ),
      ),
    );
  }

  // ------------------------------------------------------------ Cabecera

  Widget _cabecera() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mi membresía',
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
                'Tu plan, vencimiento y asistencia',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
        Material(
          color: AppColores.superficie,
          shape: CircleBorder(side: BorderSide(color: AppColores.borde)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _abrirAsistencias,
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.event_note_rounded, color: AppColores.primario),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- Portada

  String _textoDias(int dias) => switch (dias) {
    0 => 'Vence hoy',
    1 => '1 día',
    < 0 => 'Vencida',
    _ => '$dias días',
  };

  Widget _portada(MembresiaCliente m) {
    final dias = m.diasRestantes;
    final total = m.fechaVencimiento.difference(m.fechaInicio).inDays;
    final usado = total <= 0
        ? 1.0
        : (1 - dias / total).clamp(0.0, 1.0).toDouble();
    final estado = dias < 0 ? EstadoMiembro.vencido : m.estado;
    return SizedBox(
      height: 210,
      child: FotoTarjeta(
        foto: 'assets/imagenes/inicio/membresia.jpg',
        alineacion: const Alignment(0.3, -0.3),
        radio: AppEspaciado.radio + 6,
        degradadoHorizontal: true,
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'PLAN ACTUAL',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColores.destacado,
                    ),
                  ),
                  const Spacer(),
                  _pastillaEstado(estado),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                m.plan,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 25,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _textoDias(dias),
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        dias < 0
                            ? 'hace ${dias.abs()} ${dias.abs() == 1 ? 'día' : 'días'}'
                            : dias == 0
                            ? ''
                            : 'restantes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Cuánto del periodo ya pasó.
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: usado,
                  minHeight: 7,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  valueColor: AlwaysStoppedAnimation(
                    dias <= diasAvisoVencimiento
                        ? AppColores.naranja
                        : AppColores.destacado,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  _fechaPortada(m.fechaInicio),
                  const Spacer(),
                  _fechaPortada(m.fechaVencimiento),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pastillaEstado(EstadoMiembro estado) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: estado.color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        estado.etiqueta.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _fechaPortada(DateTime fecha) => Text(
    DateFormat('d MMM yyyy', 'es').format(fecha),
    style: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: Colors.white.withValues(alpha: 0.8),
    ),
  );

  // -------------------------------------------------------------- Avisos

  Widget _avisoDeuda(MembresiaCliente m) {
    return _aviso(
      color: AppColores.moroso,
      icono: Icons.account_balance_wallet_rounded,
      titulo: 'Saldo pendiente · S/ ${_soles.format(m.saldoPendiente)}',
      texto: 'Págalo desde la app con Yape y el gimnasio lo confirma.',
      boton: 'Pagar',
      onTap: () => _pagar(m),
    );
  }

  Widget _avisoRenovar(MembresiaCliente m) {
    final vencida = m.diasRestantes < 0;
    return _aviso(
      color: vencida ? AppColores.vencido : AppColores.naranja,
      icono: vencida ? Icons.event_busy_rounded : Icons.schedule_rounded,
      titulo: vencida ? 'Tu membresía venció' : 'Tu membresía está por vencer',
      texto:
          'Renueva en recepción. Mira las novedades: tal vez haya una '
          'promoción de tu interés.',
      boton: 'Novedades',
      onTap: () => abrirNovedades(context),
    );
  }

  Widget _aviso({
    required Color color,
    required IconData icono,
    required String titulo,
    required String texto,
    required String boton,
    required VoidCallback onTap,
  }) {
    final radio = BorderRadius.circular(AppEspaciado.radio);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: radio,
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  texto,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.3,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 36,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(boton),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ Detalles

  /// Tarjeta tipo ticket: inicio y vencimiento como hojas de calendario
  /// unidas por el avance del plan, y abajo duración, días usados y saldo.
  Widget _detalles(MembresiaCliente m) {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    final duracion = m.fechaVencimiento.difference(m.fechaInicio).inDays;
    final usados = hoySinHora
        .difference(m.fechaInicio)
        .inDays
        .clamp(0, duracion < 0 ? 0 : duracion);
    final avance = duracion <= 0 ? 1.0 : usados / duracion;
    final porVencer = m.diasRestantes <= diasAvisoVencimiento;
    final tono = m.diasRestantes < 0
        ? AppColores.vencido
        : porVencer
        ? AppColores.naranja
        : AppColores.primario;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
        border: Border.all(color: AppColores.borde),
        boxShadow: [
          BoxShadow(
            color: AppColores.primario.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _bannerPlan(m, tono),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: Row(
              children: [
                _hojaCalendario(m.fechaInicio, 'Inicio', AppColores.primario),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Column(
                      children: [
                        Text(
                          '$usados de $duracion ${duracion == 1 ? 'día' : 'días'}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        LayoutBuilder(
                          builder: (_, restr) {
                            final ancho = restr.maxWidth;
                            return SizedBox(
                              height: 16,
                              child: Stack(
                                alignment: Alignment.centerLeft,
                                children: [
                                  Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColores.borde,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Container(
                                    width: ancho * avance,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: tono,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  // Marca de "hoy" sobre la línea.
                                  Positioned(
                                    left: (ancho * avance - 8).clamp(
                                      0.0,
                                      ancho - 16,
                                    ),
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: BoxDecoration(
                                        color: AppColores.superficie,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: tono,
                                          width: 4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Text(
                          m.diasRestantes < 0
                              ? 'Plan terminado'
                              : m.diasRestantes == 0
                              ? 'Último día'
                              : 'Hoy',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: tono,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _hojaCalendario(m.fechaVencimiento, 'Vence', tono),
              ],
            ),
          ),
          _corteTicket(),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
            child: Row(
              children: [
                Expanded(
                  child: _datoTicket(
                    Icons.hourglass_bottom_rounded,
                    '$duracion ${duracion == 1 ? 'día' : 'días'}',
                    'Duración',
                  ),
                ),
                _separadorTicket(),
                Expanded(
                  child: _datoTicket(
                    Icons.local_fire_department_rounded,
                    m.diasRestantes < 0 ? '0' : '${m.diasRestantes}',
                    m.diasRestantes == 1 ? 'Día restante' : 'Días restantes',
                    color: tono,
                  ),
                ),
                _separadorTicket(),
                Expanded(
                  child: _datoTicket(
                    m.tieneDeuda
                        ? Icons.error_outline_rounded
                        : Icons.verified_rounded,
                    m.tieneDeuda
                        ? 'S/ ${_soles.format(m.saldoPendiente)}'
                        : 'Al día',
                    'Saldo',
                    color: m.tieneDeuda ? AppColores.moroso : AppColores.activo,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Franja con foto arriba del ticket: el nombre del plan sobre una imagen
  /// teñida con el color de la marca.
  Widget _bannerPlan(MembresiaCliente m, Color tono) {
    final dias = m.diasRestantes;
    return SizedBox(
      height: 104,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/imagenes/sesiones/espalda.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.6, -0.5),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: [
                  Color.lerp(
                    AppColores.primario,
                    Colors.black,
                    0.3,
                  )!.withValues(alpha: 0.9),
                  AppColores.primario.withValues(alpha: 0.1),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Icon(
                    Icons.workspace_premium_rounded,
                    color: AppColores.destacado,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'MEMBRESÍA',
                        style: TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                          color: AppColores.destacado,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        m.plan,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: tono == AppColores.primario
                        ? Colors.white.withValues(alpha: 0.18)
                        : tono,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    dias < 0
                        ? 'Terminado'
                        : dias == 0
                        ? 'Vence hoy'
                        : dias == 1
                        ? 'Queda 1 día'
                        : 'Quedan $dias días',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
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

  /// Fecha como hoja de calendario: mes arriba en color, día grande.
  Widget _hojaCalendario(DateTime fecha, String etiqueta, Color color) {
    return Column(
      children: [
        Container(
          width: 64,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: AppColores.superficie,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 3),
                color: color,
                child: Text(
                  DateFormat(
                    'MMM',
                    'es',
                  ).format(fecha).replaceAll('.', '').toUpperCase(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 4, 0, 5),
                child: Column(
                  children: [
                    Text(
                      '${fecha.day}',
                      style: TextStyle(
                        fontSize: 24,
                        height: 1,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      DateFormat('EEE', 'es').format(fecha).replaceAll('.', ''),
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w600,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  /// Línea punteada con muescas a los lados, como el corte de un ticket.
  Widget _corteTicket() {
    Widget muesca(bool izquierda) => Container(
      width: 11,
      height: 22,
      decoration: BoxDecoration(
        color: AppColores.fondo,
        border: Border.all(color: AppColores.borde),
        borderRadius: izquierda
            ? const BorderRadius.horizontal(right: Radius.circular(11))
            : const BorderRadius.horizontal(left: Radius.circular(11)),
      ),
    );
    return Row(
      children: [
        muesca(true),
        Expanded(
          child: LayoutBuilder(
            builder: (_, restr) {
              final n = (restr.maxWidth / 10).floor();
              return Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  for (var i = 0; i < n; i++)
                    Container(width: 5, height: 1.5, color: AppColores.borde),
                ],
              );
            },
          ),
        ),
        muesca(false),
      ],
    );
  }

  Widget _separadorTicket() =>
      Container(width: 1, height: 44, color: AppColores.borde);

  Widget _datoTicket(IconData icono, String valor, String pie, {Color? color}) {
    final tono = color ?? AppColores.primario;
    return Column(
      children: [
        Icon(icono, size: 20, color: tono),
        const SizedBox(height: 6),
        Text(
          valor,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: color ?? AppColores.textoPrincipal,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          pie,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  // ----------------------------------------------------------- Asistencia

  Widget _asistencia(MembresiaCliente m) {
    final hoy = DateTime.now();
    final inicioPlan = DateTime(
      m.fechaInicio.year,
      m.fechaInicio.month,
      m.fechaInicio.day,
    );
    final enElPlan = _visitas.where((v) => !v.fecha.isBefore(inicioPlan));
    final dias = _visitas.map((v) => v.claveDia).toSet();
    final ultima = _visitas.isEmpty
        ? null
        : _visitas.reduce((a, b) => a.fecha.isAfter(b.fecha) ? a : b);
    // Semana actual de lunes a domingo.
    final lunes = DateTime(
      hoy.year,
      hoy.month,
      hoy.day,
    ).subtract(Duration(days: hoy.weekday - 1));
    const letras = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _cifra(
                  '${enElPlan.map((v) => v.claveDia).toSet().length}',
                  'visitas en este plan',
                ),
              ),
              Container(width: 1, height: 40, color: AppColores.borde),
              Expanded(
                child: _cifra(
                  ultima == null
                      ? '—'
                      : DateFormat('d MMM', 'es').format(ultima.fecha),
                  ultima == null
                      ? 'sin visitas aún'
                      : 'última · ${ultima.hora}',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
          Divider(height: 1, color: AppColores.borde),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Builder(
                    builder: (_) {
                      final d = lunes.add(Duration(days: i));
                      final clave =
                          '${d.year.toString().padLeft(4, '0')}-'
                          '${d.month.toString().padLeft(2, '0')}-'
                          '${d.day.toString().padLeft(2, '0')}';
                      final fue = dias.contains(clave);
                      final esHoy =
                          d.day == hoy.day &&
                          d.month == hoy.month &&
                          d.year == hoy.year;
                      return Column(
                        children: [
                          Text(
                            letras[i],
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: esHoy
                                  ? AppColores.primario
                                  : AppColores.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              gradient: fue
                                  ? AppColores.degradadoRelleno
                                  : null,
                              color: fue ? null : AppColores.fondo,
                              shape: BoxShape.circle,
                              border: esHoy && !fue
                                  ? Border.all(
                                      color: AppColores.primario,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: fue
                                ? Icon(
                                    Icons.check_rounded,
                                    size: 18,
                                    color: AppColores.sobreRelleno,
                                  )
                                : Center(
                                    child: Text(
                                      '${d.day}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColores.textoSecundario,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _cifra(String valor, String pie) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColores.textoPrincipal,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          pie,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 12,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- Sin plan

  Widget _sinMembresia() {
    return Column(
      children: [
        SizedBox(
          height: 190,
          child: FotoTarjeta(
            foto: 'assets/imagenes/inicio/membresia.jpg',
            alineacion: const Alignment(0.3, -0.3),
            radio: AppEspaciado.radio + 6,
            degradadoHorizontal: true,
            child: Padding(
              padding: const EdgeInsets.all(AppEspaciado.md + 2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'SIN PLAN ACTIVO',
                    style: TextStyle(
                      fontSize: 11.5,
                      letterSpacing: 1.3,
                      fontWeight: FontWeight.w800,
                      color: AppColores.destacado,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Empieza a entrenar',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    width: 230,
                    child: Text(
                      'Acércate a recepción para activar tu membresía.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: AppEspaciado.sm + 4),
        _aviso(
          color: AppColores.primario,
          icono: Icons.campaign_rounded,
          titulo: 'Mira las novedades del gimnasio',
          texto: 'Tal vez haya una promoción de tu interés.',
          boton: 'Ver',
          onTap: () => abrirNovedades(context),
        ),
      ],
    );
  }

  // ------------------------------------------------------------ Acciones

  Widget _tituloSeccion(
    IconData icono,
    String titulo, {
    String? accion,
    VoidCallback? onAccion,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: Row(
        children: [
          Icon(icono, color: AppColores.primario, size: 24),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          if (accion != null)
            InkWell(
              onTap: onAccion,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Text(
                      accion,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColores.primario,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColores.primario,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _abrirAsistencias() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const AsistenciasScreen()));
  }

  Future<void> _pagar(MembresiaCliente m) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PagoYapeScreen(
          monto: m.saldoPendiente,
          concepto: 'Membresía: ${m.plan}',
          contratoId: m.contratoId,
        ),
      ),
    );
    // Al volver, refrescamos por si el gimnasio ya confirmó el pago.
    _cargar();
  }
}
