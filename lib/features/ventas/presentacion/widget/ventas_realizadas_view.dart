import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/venta_realizada.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';

/// Historial de ventas de la sucursal, tanto las de mostrador como las
/// generadas al cobrar pedidos de la app. Versión móvil de
/// `Ventas > Ventas realizadas` del panel web.
class VentasRealizadasView extends StatefulWidget {
  const VentasRealizadasView({super.key});

  @override
  State<VentasRealizadasView> createState() => _VentasRealizadasViewState();
}

class _VentasRealizadasViewState extends State<VentasRealizadasView> {
  final _controlador = ControladorVentas();

  List<VentaRealizada> _ventas = const [];
  bool _cargando = true;
  String _busqueda = '';

  /// Periodo consultado. En null el backend devuelve las ventas de HOY.
  DateTimeRange? _periodo;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final ventas = await _controlador.obtenerVentas(
        desde: _periodo?.start,
        hasta: _periodo?.end,
      );
      if (!mounted) return;
      setState(() {
        _ventas = ventas;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudieron cargar las ventas',
          tipo: TipoMensaje.error);
    }
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  String _fecha(String valor) {
    final f = DateTime.tryParse(valor);
    return f == null ? valor : DateFormat('dd/MM/yyyy').format(f);
  }

  String get _etiquetaPeriodo {
    final p = _periodo;
    if (p == null) return 'Hoy';
    final f = DateFormat('dd/MM/yy');
    return '${f.format(p.start)} — ${f.format(p.end)}';
  }

  List<VentaRealizada> get _filtradas {
    final t = _busqueda.toLowerCase().trim();
    if (t.isEmpty) return _ventas;
    return _ventas
        .where((v) =>
            v.codigo.toLowerCase().contains(t) ||
            v.cliente.toLowerCase().contains(t) ||
            v.dni.toLowerCase().contains(t))
        .toList();
  }

  // Los totales se calculan solo sobre las ventas válidas: una venta anulada
  // no cobró nada.
  List<VentaRealizada> get _validas =>
      _filtradas.where((v) => !v.anulada).toList();
  double get _totalCobrado => _validas.fold(0.0, (a, v) => a + v.montoTotal);
  double get _ticketPromedio =>
      _validas.isEmpty ? 0 : _totalCobrado / _validas.length;
  int get _anuladas => _filtradas.where((v) => v.anulada).length;

  Future<void> _elegirPeriodo() async {
    final hoy = DateTime.now();
    final rango = await showDateRangePicker(
      context: context,
      firstDate: DateTime(hoy.year - 3),
      lastDate: hoy,
      initialDateRange: _periodo,
      helpText: 'Periodo de ventas',
      saveText: 'Aplicar',
    );
    if (rango == null || !mounted) return;
    setState(() => _periodo = rango);
    await _cargar();
  }

  Future<void> _verHoy() async {
    setState(() => _periodo = null);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                    AppEspaciado.sm, AppEspaciado.md, AppEspaciado.lg),
                children: [
                  _banner(),
                  const SizedBox(height: AppEspaciado.md),
                  _resumen(),
                  const SizedBox(height: AppEspaciado.md),
                  _buscador(),
                  const SizedBox(height: AppEspaciado.md),
                  if (_filtradas.isEmpty)
                    const Padding(
                      padding: EdgeInsets.only(top: 40),
                      child: EstadoVacio(
                        icono: Icons.receipt_outlined,
                        mensaje: 'No hay ventas en este periodo',
                      ),
                    )
                  else
                    for (final v in _filtradas) ...[
                      _tarjetaVenta(v),
                      const SizedBox(height: AppEspaciado.sm + 4),
                    ],
                ],
              ),
            ),
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.white, size: 22),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ventas realizadas',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Historial · $_etiquetaPeriodo',
                  style: const TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _elegirPeriodo,
            icon: const Icon(Icons.date_range, color: Colors.white),
            tooltip: 'Elegir periodo',
          ),
          if (_periodo != null)
            IconButton(
              onPressed: _verHoy,
              icon: const Icon(Icons.close, color: Colors.white70),
              tooltip: 'Ver hoy',
            ),
        ],
      ),
    );
  }

  Widget _resumen() {
    return Row(
      children: [
        Expanded(
          child: _tarjetaDato('Ventas', '${_validas.length}',
              Icons.receipt_outlined, AppColores.azul),
        ),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: _tarjetaDato('Cobrado', _soles(_totalCobrado),
              Icons.payments_outlined, AppColores.verde),
        ),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: _tarjetaDato('Ticket prom.', _soles(_ticketPromedio),
              Icons.sell_outlined, AppColores.naranja),
        ),
        const SizedBox(width: AppEspaciado.sm + 4),
        Expanded(
          child: _tarjetaDato('Anuladas', '$_anuladas',
              Icons.cancel_outlined, AppColores.moroso),
        ),
      ],
    );
  }

  Widget _tarjetaDato(
      String titulo, String valor, IconData icono, Color color) {
    return TarjetaApp(
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.sm, vertical: AppEspaciado.sm + 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icono, color: color, size: 18),
          const SizedBox(height: AppEspaciado.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(
                fontSize: 11, color: AppColores.textoSecundario),
          ),
        ],
      ),
    );
  }

  Widget _buscador() {
    return TextField(
      onChanged: (v) => setState(() => _busqueda = v),
      decoration: InputDecoration(
        hintText: 'Buscar por cliente, código o DNI...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
          onPressed: _cargar,
        ),
      ),
    );
  }

  Widget _tarjetaVenta(VentaRealizada v) {
    return TarjetaApp(
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
      onTap: () => _verDetalle(v),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColores.primario.withValues(alpha: 0.10),
                child: Text(
                  v.inicial,
                  style: const TextStyle(
                    color: AppColores.primario,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: AppEspaciado.sm + 4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.cliente.isEmpty ? 'Sin nombre' : v.cliente,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.codigo} · ${_fecha(v.fecha)}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColores.textoSecundario),
                    ),
                  ],
                ),
              ),
              Text(
                _soles(v.montoTotal),
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: v.anulada
                      ? AppColores.textoSecundario
                      : AppColores.verde,
                  decoration:
                      v.anulada ? TextDecoration.lineThrough : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          Row(
            children: [
              EtiquetaEstado(
                texto: v.anulada ? 'Anulada' : 'Realizada',
                color: v.anulada ? AppColores.moroso : AppColores.verde,
              ),
              const SizedBox(width: AppEspaciado.sm),
              Flexible(
                child: Text(
                  '${v.tipoPago} · ${v.usuario}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textoSecundario),
                ),
              ),
              const Spacer(),
              Text(
                '${v.detalle.length} ${v.detalle.length == 1 ? 'ítem' : 'ítems'}',
                style: const TextStyle(
                    fontSize: 11.5, color: AppColores.textoSecundario),
              ),
              const Icon(Icons.chevron_right,
                  size: 18, color: AppColores.textoSecundario),
            ],
          ),
        ],
      ),
    );
  }

  /// El detalle ya viene con la venta, así que la hoja se abre sin esperar.
  void _verDetalle(VentaRealizada v) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(AppEspaciado.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            EncabezadoSeccion(
              titulo: 'Detalle de la venta',
              subtitulo:
                  '${v.codigo} · ${v.cliente.isEmpty ? 'Sin nombre' : v.cliente}',
              accion: EtiquetaEstado(
                texto: v.anulada ? 'Anulada' : 'Realizada',
                color: v.anulada ? AppColores.moroso : AppColores.verde,
              ),
            ),
            const SizedBox(height: AppEspaciado.sm),
            Text(
              '${_fecha(v.fecha)} · ${v.tipoPago} · ${v.usuario}',
              style: const TextStyle(
                  fontSize: 12.5, color: AppColores.textoSecundario),
            ),
            const SizedBox(height: AppEspaciado.md),
            if (v.detalle.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Sin productos',
                    style: TextStyle(color: AppColores.textoSecundario)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: v.detalle.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (_, i) {
                    final d = v.detalle[i];
                    return Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                d.nombre,
                                style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${d.cantidad.toStringAsFixed(0)} x ${_soles(d.precio)} · ${d.unidadMedida}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColores.textoSecundario),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _soles(d.total),
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColores.textoPrincipal),
                        ),
                      ],
                    );
                  },
                ),
              ),
            const Divider(height: AppEspaciado.lg),
            Row(
              children: [
                const Text('Total',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                const Spacer(),
                Text(
                  _soles(v.montoTotal),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColores.primario,
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
  }
}
