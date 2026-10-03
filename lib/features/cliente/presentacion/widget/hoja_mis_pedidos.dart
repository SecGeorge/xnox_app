import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/features/pago_yape/presentacion/pago_yape_screen.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/pedido_cliente.dart';
import 'package:xnox_app/features/tienda/presentacion/controlador/controlador_tienda.dart';

/// Abre una hoja inferior con los pedidos PENDIENTES de pago del cliente para
/// que elija cuál pagar por la app. Devuelve `true` si algún pago se confirmó,
/// para que el llamador refresque su vista.
Future<bool> mostrarHojaMisPedidos(BuildContext context) async {
  final resultado = await mostrarHojaModerna<bool>(
    context,
    builder: (_) => const _HojaMisPedidos(),
  );
  return resultado ?? false;
}

class _HojaMisPedidos extends StatefulWidget {
  const _HojaMisPedidos();

  @override
  State<_HojaMisPedidos> createState() => _HojaMisPedidosState();
}

class _HojaMisPedidosState extends State<_HojaMisPedidos> {
  final _controlador = ControladorTienda();

  List<PedidoCliente> _pedidos = const [];
  bool _cargando = true;
  bool _huboPago = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final pedidos = await _controlador.obtenerMisPedidos();
      if (!mounted) return;
      setState(() {
        _pedidos = pedidos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  String _soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

  Future<void> _pagar(PedidoCliente pedido) async {
    final pagado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PagoYapeScreen(
          monto: pedido.total,
          concepto: 'Pedido ${pedido.codigo}',
          pedidoId: pedido.id,
        ),
      ),
    );
    if (!mounted) return;
    if (pagado == true) {
      _huboPago = true;
      // Revalidamos contra el backend: el pedido pagado pasa a "vendido".
      await _cargar();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = _pedidos.fold<double>(0, (t, p) => t + p.total);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) Navigator.of(context).pop(_huboPago);
      },
      child: HojaModerna(
        icono: Icons.receipt_long_rounded,
        titulo: 'Mis pedidos',
        subtitulo: _cargando
            ? 'Cargando…'
            : _pedidos.isEmpty
            ? 'Todo al día'
            : '${_pedidos.length} por pagar · ${_soles(total)}',
        accion: IconButton(
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(
            Icons.refresh_rounded,
            color: AppColores.textoSecundario,
          ),
          tooltip: 'Actualizar',
        ),
        child: _cargando
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            : _pedidos.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: AppColores.exito.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.task_alt_rounded,
                        size: 38,
                        color: AppColores.exito,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'No tienes pedidos por pagar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                  ],
                ),
              )
            : Column(children: [for (final p in _pedidos) _fila(p)]),
      ),
    );
  }

  Widget _fila(PedidoCliente pedido) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.sm + 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColores.naranja.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: const Icon(
              Icons.schedule_rounded,
              color: AppColores.naranja,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _soles(pedido.total),
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  '${pedido.codigo} · ${pedido.items} '
                  '${pedido.items == 1 ? 'producto' : 'productos'}'
                  '${pedido.fecha.isNotEmpty ? ' · ${_fecha(pedido.fecha)}' : ''}',
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
          const SizedBox(width: 8),
          SizedBox(
            height: 38,
            child: ElevatedButton.icon(
              onPressed: () => _pagar(pedido),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 14),
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Pagar', style: TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  String _fecha(String fecha) {
    // Backend entrega 'YYYY-MM-DD HH:MM:SS'; mostramos 'DD/MM'.
    final soloFecha = fecha.split(' ').first;
    final partes = soloFecha.split('-');
    if (partes.length == 3) return '${partes[2]}/${partes[1]}';
    return fecha;
  }
}
