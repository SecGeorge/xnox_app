import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';
import 'package:xnox_app/features/pagos/presentacion/controlador/controlador_pagos.dart';
import 'package:xnox_app/features/pagos/presentacion/widget/grafico_barra.dart';

/// Pantalla de Pagos (membresías del gimnasio): lo cobrado, la semana, el año,
/// los ingresos por plan y las asistencias por turno. Mismos datos que el
/// dashboard web `InicioComponent.vue` (endpoint `inicio.php`).
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final _controlador = ControladorPagos();
  ResumenPagos? _resumen;
  bool _cargando = true;

  static const _meses = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', //
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic',
  ];

  /// Colores de los planes en "Ingresos por plan".
  static const _paleta = [
    Color(0xFF3B82F6),
    Color(0xFF22A06B),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFF14B8A6),
  ];

  static String _capital(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  /// "Jul" -> "julio".
  String _mesLargo(String corto) {
    final i = _meses.indexOf(corto);
    return i < 0
        ? corto.toLowerCase()
        : DateFormat('MMMM', 'es').format(DateTime(2000, i + 1));
  }

  /// "Vie" -> "viernes".
  static String _diaLargo(String corto) =>
      const {
        'Dom': 'domingo',
        'Lun': 'lunes',
        'Mar': 'martes',
        'Mié': 'miércoles',
        'Jue': 'jueves',
        'Vie': 'viernes',
        'Sáb': 'sábado',
      }[corto] ??
      corto.toLowerCase();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resumen = await _controlador.obtenerResumen();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(
        context,
        'No se pudieron cargar los pagos',
        tipo: TipoMensaje.error,
      );
    }
  }

  String _soles(double valor) =>
      'S/ ${NumberFormat('#,##0', 'es').format(valor)}';

  /// Para encima de las barras: "S/ 1,2 mil" en vez de "S/ 1.240".
  String _corto(double valor) => valor >= 1000
      ? '${NumberFormat('#,##0.#', 'es').format(valor / 1000)} mil'
      : NumberFormat('#,##0', 'es').format(valor);

  @override
  Widget build(BuildContext context) {
    final r = _resumen;
    return PantallaApp(
      onRefresh: _cargarDatos,
      children: [
        const CabeceraApp(
          titulo: 'Pagos',
          subtitulo: 'Cobranza de membresías',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (r == null)
          const VacioApp(
            icono: Icons.cloud_off_rounded,
            titulo: 'No se pudo cargar la información de pagos',
            texto: 'Desliza hacia abajo para reintentar.',
          )
        else
          ..._vistaContenido(r),
      ],
    );
  }

  List<Widget> _vistaContenido(ResumenPagos r) {
    final hoy = DateTime.now();
    final indiceMes = r.serieMeses.indexWhere(
      (b) => b.etiqueta == _meses[hoy.month - 1],
    );
    final indiceMesAnterior = r.serieMeses.indexWhere(
      (b) => b.etiqueta == _meses[(hoy.month + 10) % 12],
    );
    final totalSemana = r.serieSemana.fold<double>(0, (a, b) => a + b.total);

    return [
      _portada(r, indiceMesAnterior),
      const SizedBox(height: AppEspaciado.md),
      _indicadores(r),
      const SizedBox(height: AppEspaciado.lg),
      TituloSeccion(
        icono: Icons.bar_chart_rounded,
        titulo: 'Esta semana',
        detalle: _soles(totalSemana),
      ),
      TarjetaPlana(
        child: GraficoBarra(
          datos: r.serieSemana,
          // DAYOFWEEK: la serie va de domingo (0) a sábado (6).
          resaltado: hoy.weekday % 7,
          color: AppColores.primario,
          formatoValor: _corto,
        ),
      ),
      const SizedBox(height: AppEspaciado.lg),
      TituloSeccion(
        icono: Icons.insights_rounded,
        titulo: 'Por mes',
        detalle: '${hoy.year}',
      ),
      TarjetaPlana(
        child: GraficoBarra(
          datos: r.serieMeses,
          resaltado: indiceMes < 0 ? null : indiceMes,
          color: AppColores.naranja,
          formatoValor: _corto,
        ),
      ),
      if (r.membresias.isNotEmpty) ...[
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.card_membership_rounded,
          titulo: 'Ingresos por plan',
        ),
        _ingresosPorPlan(r.membresias),
      ],
      if (r.asistencias.isNotEmpty) ...[
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.schedule_rounded,
          titulo: 'Asistencias por turno',
        ),
        _asistenciasPorTurno(r.asistencias),
      ],
    ];
  }

  // ----------------------------------------------------------------- Portada

  Widget _portada(ResumenPagos r, int indiceMesAnterior) {
    final hoy = DateTime.now();
    final mes = DateFormat('MMMM', 'es').format(hoy);
    final anterior = indiceMesAnterior < 0
        ? 0.0
        : r.serieMeses[indiceMesAnterior].total;
    // Neutro: a inicio de mes, un "% vs el mes pasado" saldría siempre en
    // rojo aunque el mes vaya bien.
    final comparacion = anterior > 0
        ? '${_capital(DateFormat('MMMM', 'es').format(DateTime(hoy.year, hoy.month - 1)))} cerró en ${_soles(anterior)}'
        : null;

    return PortadaFoto(
      foto: FotosApp.membresia,
      alineacion: const Alignment(0.3, -0.3),
      altura: 190,
      etiqueta: 'Cobrado en $mes',
      titulo: _soles(r.pagosMes),
      pie: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (comparacion != null) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.history_rounded,
                    size: 14,
                    color: AppColores.destacado,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    comparacion,
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              DatoPortada(
                icono: Icons.today_rounded,
                valor: _soles(r.pagosHoy),
                pie: 'hoy',
              ),
              const SizedBox(width: 18),
              DatoPortada(
                icono: Icons.date_range_rounded,
                valor: _soles(r.pagosSemana),
                pie: 'esta semana',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Indicadores

  Widget _indicadores(ResumenPagos r) {
    final hoy = DateTime.now();
    final promedioDiario = hoy.day == 0 ? 0.0 : r.pagosMes / hoy.day;

    BarraPago? mejor(List<BarraPago> l) =>
        l.isEmpty ? null : l.reduce((a, b) => b.total > a.total ? b : a);
    final mejorMes = mejor(r.serieMeses);
    final mejorDia = mejor(r.serieSemana);

    final datos = [
      _Kpi(
        'Total histórico',
        _soles(r.totalPagos),
        'desde el inicio',
        Icons.account_balance_wallet_rounded,
        AppColores.azul,
      ),
      _Kpi(
        'Promedio diario',
        _soles(promedioDiario),
        'en lo que va del mes',
        Icons.speed_rounded,
        AppColores.verde,
      ),
      _Kpi(
        'Mejor mes',
        mejorMes == null || mejorMes.total <= 0 ? '—' : _soles(mejorMes.total),
        mejorMes == null || mejorMes.total <= 0
            ? 'sin pagos este año'
            : 'fue ${_mesLargo(mejorMes.etiqueta)}',
        Icons.emoji_events_rounded,
        AppColores.naranja,
      ),
      _Kpi(
        'Mejor día',
        mejorDia == null || mejorDia.total <= 0 ? '—' : _soles(mejorDia.total),
        mejorDia == null || mejorDia.total <= 0
            ? 'sin pagos esta semana'
            : 'de la semana: ${_diaLargo(mejorDia.etiqueta)}',
        Icons.star_rounded,
        AppColores.morado,
      ),
    ];

    Widget fila(_Kpi a, _Kpi b) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _tarjetaKpi(a)),
          const SizedBox(width: AppEspaciado.sm + 4),
          Expanded(child: _tarjetaKpi(b)),
        ],
      ),
    );

    return Column(
      children: [
        fila(datos[0], datos[1]),
        const SizedBox(height: AppEspaciado.sm + 4),
        fila(datos[2], datos[3]),
      ],
    );
  }

  /// Igual que los indicadores del inicio: ícono sólido, valor grande y un
  /// círculo decorativo del color en la esquina.
  Widget _tarjetaKpi(_Kpi kpi) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 4);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: radio,
        border: Border.all(color: kpi.color.withValues(alpha: 0.25)),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -26,
            top: -26,
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: kpi.color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: kpi.color,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: kpi.color.withValues(alpha: 0.3),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(kpi.icono, color: Colors.white, size: 21),
                ),
                const SizedBox(height: 12),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    kpi.valor,
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  kpi.titulo,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  kpi.pie,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
    );
  }

  // ------------------------------------------------------- Ingresos por plan

  Widget _ingresosPorPlan(List<ItemDistribucion> planes) {
    final ordenados = [...planes]..sort((a, b) => b.valor.compareTo(a.valor));
    final total = ordenados.fold<double>(0, (a, p) => a + p.valor);
    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Column(
        children: [
          // Barra apilada con la participación de cada plan.
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < ordenados.length; i++)
                    Expanded(
                      flex: total <= 0
                          ? 1
                          : (ordenados[i].valor / total * 1000).round().clamp(
                              1,
                              1000,
                            ),
                      child: Container(color: _paleta[i % _paleta.length]),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          for (var i = 0; i < ordenados.length; i++)
            _filaPlan(
              ordenados[i],
              _paleta[i % _paleta.length],
              total <= 0 ? 0 : ordenados[i].valor / total,
            ),
        ],
      ),
    );
  }

  Widget _filaPlan(ItemDistribucion p, Color color, double parte) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(Icons.card_membership_rounded, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.etiqueta,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: parte,
                    minHeight: 6,
                    color: color,
                    backgroundColor: color.withValues(alpha: 0.12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _soles(p.valor),
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
              Text(
                '${(parte * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------- Asistencias por turno

  Widget _asistenciasPorTurno(List<ItemDistribucion> turnos) {
    final total = turnos.fold<double>(0, (a, t) => a + t.valor);
    final maximo = turnos
        .map((t) => t.valor)
        .fold<double>(0, (a, b) => b > a ? b : a);

    (IconData, Color) estilo(String turno) {
      final t = turno.toLowerCase();
      if (t.contains('ma')) return (Icons.wb_sunny_rounded, AppColores.naranja);
      if (t.contains('tar')) {
        return (Icons.wb_twilight_rounded, AppColores.azul);
      }
      return (Icons.nightlight_round, AppColores.morado);
    }

    return Row(
      children: [
        for (var i = 0; i < turnos.length; i++) ...[
          if (i > 0) const SizedBox(width: AppEspaciado.sm + 2),
          Expanded(
            child: Builder(
              builder: (_) {
                final t = turnos[i];
                final (icono, color) = estilo(t.etiqueta);
                final pico = t.valor == maximo && maximo > 0;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 10,
                  ),
                  decoration: BoxDecoration(
                    color: pico
                        ? color.withValues(alpha: 0.10)
                        : AppColores.superficie,
                    borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
                    border: Border.all(
                      color: pico
                          ? color.withValues(alpha: 0.45)
                          : AppColores.borde,
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(icono, color: color, size: 26),
                      const SizedBox(height: 8),
                      Text(
                        NumberFormat('#,##0', 'es').format(t.valor),
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      Text(
                        t.etiqueta,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                      if (total > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          pico
                              ? 'Más concurrido'
                              : '${(t.valor / total * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: pico ? color : AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Kpi {
  final String titulo;
  final String valor;
  final String pie;
  final IconData icono;
  final Color color;
  _Kpi(this.titulo, this.valor, this.pie, this.icono, this.color);
}
