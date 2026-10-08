import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ventas/dominio/entidades/venta_realizada.dart';
import 'package:xnox_app/features/ventas/presentacion/controlador/controlador_ventas.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/piezas_ventas.dart';

/// Historial de ventas de la sucursal, tanto las de mostrador como las
/// generadas al cobrar pedidos de la app. Versión móvil de
/// `Ventas > Ventas realizadas` del panel web.
class VentasRealizadasView extends StatefulWidget {
  /// Cabecera de Ventas (título y pestañas), va arriba del desplazamiento.
  final Widget cabecera;

  /// Pestaña visible. Al volver a ella se recargan los datos: una venta
  /// hecha en otra pestaña tiene que verse sin jalar para actualizar.
  final bool activa;

  const VentasRealizadasView({
    super.key,
    required this.cabecera,
    this.activa = true,
  });

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

  @override
  void didUpdateWidget(covariant VentasRealizadasView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.activa && !oldWidget.activa) _cargar(silencioso: true);
  }

  /// [silencioso]: sin el indicador de carga, la lista se reemplaza al llegar.
  Future<void> _cargar({bool silencioso = false}) async {
    if (!silencioso) setState(() => _cargando = true);
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
      mostrarMensaje(
        context,
        'No se pudieron cargar las ventas',
        tipo: TipoMensaje.error,
      );
    }
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
        .where(
          (v) =>
              v.codigo.toLowerCase().contains(t) ||
              v.cliente.toLowerCase().contains(t) ||
              v.dni.toLowerCase().contains(t),
        )
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
    final ventas = _filtradas;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md,
          AppEspaciado.md,
          AppEspaciado.md,
          110,
        ),
        children: [
          widget.cabecera,
          const SizedBox(height: AppEspaciado.md),
          if (_cargando)
            const Padding(
              padding: EdgeInsets.only(top: 80),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            _portada(),
            const SizedBox(height: AppEspaciado.md + 4),
            FilaChips(
              chips: [
                ChipApp(
                  texto: 'Hoy',
                  icono: Icons.today_rounded,
                  activo: _periodo == null,
                  onTap: _periodo == null ? null : _verHoy,
                ),
                ChipApp(
                  texto: _periodo == null ? 'Elegir fechas' : _etiquetaPeriodo,
                  icono: Icons.date_range_rounded,
                  activo: _periodo != null,
                  onTap: _elegirPeriodo,
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm + 4),
            BuscadorApp(
              hint: 'Buscar por cliente, código o DNI…',
              onChanged: (v) => setState(() => _busqueda = v),
            ),
            const SizedBox(height: AppEspaciado.md + 4),
            TituloSeccion(
              icono: Icons.receipt_long_rounded,
              titulo: 'Ventas',
              detalle:
                  '${ventas.length} ${ventas.length == 1 ? 'venta' : 'ventas'}',
            ),
            if (ventas.isEmpty)
              VacioApp(
                icono: Icons.receipt_outlined,
                titulo: 'No hay ventas en este periodo',
                texto: _periodo == null
                    ? 'Todavía no se registran ventas hoy.'
                    : 'Prueba con otras fechas.',
              )
            else
              for (final v in ventas) ...[
                _tarjetaVenta(v),
                const SizedBox(height: AppEspaciado.sm + 4),
              ],
          ],
        ],
      ),
    );
  }

  /// Portada con foto: lo cobrado en el periodo y sus números.
  Widget _portada() {
    return PortadaFoto(
      foto: FotosApp.progreso,
      altura: 170,
      etiqueta: _periodo == null
          ? 'Vendido hoy'
          : 'Vendido · $_etiquetaPeriodo',
      titulo: soles(_totalCobrado),
      texto: 'Mostrador y pedidos cobrados.',
      pie: Row(
        children: [
          DatoPortada(
            icono: Icons.receipt_rounded,
            valor: '${_validas.length}',
            pie: 'ventas',
          ),
          const SizedBox(width: AppEspaciado.md),
          DatoPortada(
            icono: Icons.sell_rounded,
            valor: soles(_ticketPromedio),
            pie: 'ticket prom.',
          ),
          if (_anuladas > 0) ...[
            const SizedBox(width: AppEspaciado.md),
            DatoPortada(
              icono: Icons.block_rounded,
              valor: '$_anuladas',
              pie: 'anuladas',
            ),
          ],
        ],
      ),
    );
  }

  Widget _tarjetaVenta(VentaRealizada v) {
    final productos = v.detalle.length;
    return TarjetaPlana(
      padding: const EdgeInsets.all(14),
      onTap: () => _verDetalle(v),
      child: Column(
        children: [
          Row(
            children: [
              AvatarInicial(nombreCliente(v.cliente)[0].toUpperCase()),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombreCliente(v.cliente),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${v.codigo} · ${fechaCorta(v.fecha)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    soles(v.montoTotal),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: v.anulada
                          ? AppColores.textoSecundario
                          : AppColores.textoPrincipal,
                      decoration: v.anulada ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$productos ${productos == 1 ? 'producto' : 'productos'}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              PildoraVenta(
                v.anulada ? 'Anulada' : 'Realizada',
                v.anulada ? AppColores.moroso : AppColores.verde,
                icono: v.anulada
                    ? Icons.block_rounded
                    : Icons.check_circle_rounded,
                suave: true,
              ),
              const SizedBox(width: 8),
              if (v.tipoPago.isNotEmpty)
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: PildoraVenta(
                      v.tipoPago,
                      AppColores.primario,
                      icono: Icons.payments_outlined,
                      suave: true,
                    ),
                  ),
                )
              else
                const Spacer(),
              const SizedBox(width: 8),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: AppColores.textoSecundario,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// El detalle ya viene con la venta, así que la hoja se abre sin esperar.
  void _verDetalle(VentaRealizada v) {
    mostrarHojaModerna<void>(
      context,
      builder: (ctx) => HojaModerna(
        cabecera: AvatarInicial(
          nombreCliente(v.cliente)[0].toUpperCase(),
          tamano: 44,
        ),
        titulo: nombreCliente(v.cliente),
        subtitulo: '${v.codigo} · ${fechaCorta(v.fecha)}',
        accion: PildoraVenta(
          v.anulada ? 'Anulada' : 'Realizada',
          v.anulada ? AppColores.moroso : AppColores.verde,
          suave: true,
        ),
        pie: TotalVenta(v.montoTotal),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (v.tipoPago.isNotEmpty) ...[
                  PildoraVenta(
                    v.tipoPago,
                    AppColores.primario,
                    icono: Icons.payments_outlined,
                    suave: true,
                  ),
                  const SizedBox(width: 8),
                ],
                if (v.usuario.isNotEmpty)
                  Flexible(
                    child: PildoraVenta(
                      v.usuario,
                      AppColores.textoSecundario,
                      icono: Icons.person_outline_rounded,
                      suave: true,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: AppEspaciado.md),
            if (v.detalle.isEmpty)
              const SinProductosHoja()
            else
              for (final d in v.detalle)
                FilaDetalleVenta(
                  nombre: d.nombre,
                  cantidad: d.cantidad,
                  precio: d.precio,
                  unidad: d.unidadMedida,
                  total: d.total,
                ),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
  }
}
