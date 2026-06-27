import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/asistencia_cliente.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_asistencias.dart';

/// Muestra las asistencias del cliente en un calendario mensual, marcando los
/// días que asistió. Permite filtrar por contrato/membresía para revisar el
/// historial de otros contratos.
class AsistenciasScreen extends StatefulWidget {
  const AsistenciasScreen({super.key});

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen> {
  final _controlador = ControladorAsistencias();

  bool _isLoading = true;
  List<AsistenciaCliente> _asistencias = [];
  List<OpcionMembresia> _membresias = [];
  int _filtroMembresia = 0;

  // Mes visible en el calendario (siempre normalizado al día 1).
  late DateTime _mes;
  // Día seleccionado dentro del calendario (para ver el detalle de visitas).
  DateTime? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _mes = DateTime(ahora.year, ahora.month);
    _cargarInicial();
  }

  Future<void> _cargarInicial() async {
    setState(() => _isLoading = true);
    final data = await _controlador.cargarInicial();
    if (!mounted) return;
    setState(() {
      _membresias = data.membresias;
      _asistencias = data.asistencias;
      _isLoading = false;
    });
  }

  Future<void> _cambiarFiltro(int membresiaId) async {
    setState(() {
      _filtroMembresia = membresiaId;
      _isLoading = true;
      _diaSeleccionado = null;
    });
    final lista =
        await _controlador.obtenerAsistencias(membresiaId: membresiaId);
    if (!mounted) return;
    setState(() {
      _asistencias = lista;
      _isLoading = false;
      // Posicionamos el calendario en el mes de la última asistencia.
      if (lista.isNotEmpty) {
        final ultima = lista.first.fecha;
        _mes = DateTime(ultima.year, ultima.month);
      }
    });
  }

  // ── Datos derivados ──────────────────────────────────────────────
  Map<String, List<AsistenciaCliente>> get _porDia {
    final mapa = <String, List<AsistenciaCliente>>{};
    for (final a in _asistencias) {
      mapa.putIfAbsent(a.claveDia, () => []).add(a);
    }
    return mapa;
  }

  String _clave(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int get _totalVisitas => _asistencias.length;

  int get _visitasEsteMes {
    final ahora = DateTime.now();
    return _asistencias
        .where((a) => a.fecha.year == ahora.year && a.fecha.month == ahora.month)
        .length;
  }

  int get _visitasHoy {
    final hoy = _clave(DateTime.now());
    return _asistencias.where((a) => a.claveDia == hoy).length;
  }

  int get _promedioSemanal {
    if (_asistencias.isEmpty) return 0;
    final dias = _asistencias.map((a) => a.claveDia).toSet().toList()..sort();
    if (dias.length < 2) return dias.length;
    final primera = DateTime.parse(dias.first);
    final ultima = DateTime.parse(dias.last);
    final difDias = ultima.difference(primera).inDays.abs().clamp(1, 1 << 30);
    final semanas = (difDias / 7).clamp(1, double.infinity);
    return (dias.length / semanas).round();
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarInicial,
              child: ListView(
                padding: const EdgeInsets.all(AppEspaciado.md),
                children: [
                  const SizedBox(height: AppEspaciado.sm),
                  const Text(
                    'Mis Asistencias',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColores.textoPrincipal),
                  ),
                  const SizedBox(height: 4),
                  const Text('Historial de tus visitas al gimnasio',
                      style: TextStyle(
                          fontSize: 13.5, color: AppColores.textoSecundario)),
                  const SizedBox(height: AppEspaciado.lg),
                  _buildEstadisticas(),
                  const SizedBox(height: AppEspaciado.md),
                  if (_membresias.isNotEmpty) ...[
                    _buildFiltro(),
                    const SizedBox(height: AppEspaciado.md),
                  ],
                  _buildCalendario(),
                  const SizedBox(height: AppEspaciado.md),
                  _buildDetalleDia(),
                ],
              ),
            ),
    );
  }

  Widget _buildEstadisticas() {
    return Row(
      children: [
        _resumen('Total', '$_totalVisitas', Icons.event_available,
            AppColores.azul),
        const SizedBox(width: AppEspaciado.sm),
        _resumen('Este mes', '$_visitasEsteMes', Icons.calendar_month,
            AppColores.verde),
        const SizedBox(width: AppEspaciado.sm),
        _resumen('Hoy', '$_visitasHoy', Icons.today,
            _visitasHoy > 0 ? AppColores.naranja : AppColores.vencido),
        const SizedBox(width: AppEspaciado.sm),
        _resumen('Prom/sem', '$_promedioSemanal', Icons.show_chart,
            AppColores.morado),
      ],
    );
  }

  Widget _resumen(String titulo, String valor, IconData icono, Color color) {
    return Expanded(
      child: TarjetaApp(
        padding: const EdgeInsets.symmetric(
            vertical: AppEspaciado.md, horizontal: 6),
        child: Column(
          children: [
            Icon(icono, color: color, size: 20),
            const SizedBox(height: 6),
            Text(valor,
                style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal)),
            const SizedBox(height: 2),
            Text(titulo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10.5, color: AppColores.textoSecundario)),
          ],
        ),
      ),
    );
  }

  Widget _buildFiltro() {
    return TarjetaApp(
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.filter_list,
              size: 20, color: AppColores.textoSecundario),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int>(
                value: _filtroMembresia,
                isExpanded: true,
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                style: const TextStyle(
                    fontSize: 14, color: AppColores.textoPrincipal),
                items: [
                  const DropdownMenuItem(
                      value: 0, child: Text('Todas (recientes)')),
                  ..._membresias.map((m) => DropdownMenuItem(
                        value: m.id,
                        child: Text(m.nombre, overflow: TextOverflow.ellipsis),
                      )),
                ],
                onChanged: (v) {
                  if (v != null && v != _filtroMembresia) _cambiarFiltro(v);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendario() {
    final porDia = _porDia;
    final hoyClave = _clave(DateTime.now());

    // Lunes como primer día de la semana.
    final primerDia = DateTime(_mes.year, _mes.month, 1);
    final blancosIniciales = primerDia.weekday - 1; // 0 = lunes
    final diasEnMes = DateTime(_mes.year, _mes.month + 1, 0).day;

    final celdas = <Widget>[];
    for (var i = 0; i < blancosIniciales; i++) {
      celdas.add(const SizedBox());
    }
    for (var dia = 1; dia <= diasEnMes; dia++) {
      final fecha = DateTime(_mes.year, _mes.month, dia);
      final clave = _clave(fecha);
      final tieneVisita = porDia.containsKey(clave);
      final esHoy = clave == hoyClave;
      final seleccionado = _diaSeleccionado != null &&
          _clave(_diaSeleccionado!) == clave;
      celdas.add(_celdaDia(
        dia: dia,
        tieneVisita: tieneVisita,
        esHoy: esHoy,
        seleccionado: seleccionado,
        onTap: tieneVisita
            ? () => setState(() => _diaSeleccionado = fecha)
            : null,
      ));
    }

    const labels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return TarjetaApp(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => setState(() {
                  _mes = DateTime(_mes.year, _mes.month - 1);
                  _diaSeleccionado = null;
                }),
                icon: const Icon(Icons.chevron_left),
                color: AppColores.primario,
                visualDensity: VisualDensity.compact,
              ),
              Expanded(
                child: Text(
                  toBeginningOfSentenceCase(
                          DateFormat('MMMM yyyy', 'es').format(_mes)) ??
                      '',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal),
                ),
              ),
              IconButton(
                onPressed: () => setState(() {
                  _mes = DateTime(_mes.year, _mes.month + 1);
                  _diaSeleccionado = null;
                }),
                icon: const Icon(Icons.chevron_right),
                color: AppColores.primario,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: labels
                .map((l) => Expanded(
                      child: Center(
                        child: Text(l,
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColores.textoSecundario)),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 6),
          GridView.count(
            crossAxisCount: 7,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 4,
            crossAxisSpacing: 4,
            children: celdas,
          ),
          const SizedBox(height: AppEspaciado.sm),
          _leyenda(),
        ],
      ),
    );
  }

  Widget _celdaDia({
    required int dia,
    required bool tieneVisita,
    required bool esHoy,
    required bool seleccionado,
    VoidCallback? onTap,
  }) {
    Color fondo = Colors.transparent;
    Color texto = AppColores.textoPrincipal;
    if (tieneVisita) {
      fondo = AppColores.verde;
      texto = Colors.white;
    }
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: fondo,
          shape: BoxShape.circle,
          border: seleccionado
              ? Border.all(color: AppColores.primario, width: 2)
              : esHoy
                  ? Border.all(color: AppColores.acento, width: 1.6)
                  : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$dia',
          style: TextStyle(
            fontSize: 13,
            fontWeight: tieneVisita || esHoy
                ? FontWeight.w700
                : FontWeight.w500,
            color: texto,
          ),
        ),
      ),
    );
  }

  Widget _leyenda() {
    Widget item(Widget muestra, String texto) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            muestra,
            const SizedBox(width: 4),
            Text(texto,
                style: const TextStyle(
                    fontSize: 11, color: AppColores.textoSecundario)),
          ],
        );
    return Wrap(
      spacing: AppEspaciado.md,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(
          Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(
                color: AppColores.verde, shape: BoxShape.circle),
          ),
          'Asististe',
        ),
        item(
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColores.acento, width: 1.6),
            ),
          ),
          'Hoy',
        ),
      ],
    );
  }

  Widget _buildDetalleDia() {
    final dia = _diaSeleccionado;
    if (dia == null) {
      return const SizedBox.shrink();
    }
    final visitas = _porDia[_clave(dia)] ?? [];
    final f = DateFormat("EEEE d 'de' MMMM", 'es');
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.event_note,
                  size: 18, color: AppColores.primario),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  toBeginningOfSentenceCase(f.format(dia)) ?? '',
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal),
                ),
              ),
              EtiquetaEstado(
                  texto: '${visitas.length} visita${visitas.length == 1 ? '' : 's'}',
                  color: AppColores.verde),
            ],
          ),
          const Divider(height: AppEspaciado.lg, color: AppColores.borde),
          ...visitas.map((v) => Padding(
                padding: const EdgeInsets.only(bottom: AppEspaciado.sm),
                child: Row(
                  children: [
                    const Icon(Icons.access_time,
                        size: 18, color: AppColores.textoSecundario),
                    const SizedBox(width: AppEspaciado.sm),
                    Text(v.hora.isEmpty ? '—' : v.hora,
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColores.textoPrincipal)),
                    const SizedBox(width: AppEspaciado.md),
                    Expanded(
                      child: Text(v.membresia,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColores.textoSecundario)),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
