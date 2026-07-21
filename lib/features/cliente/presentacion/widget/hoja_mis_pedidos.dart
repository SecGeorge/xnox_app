import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pago_yape/presentacion/pago_yape_screen.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/pedido_cliente.dart';
import 'package:xnox_app/features/tienda/presentacion/controlador/controlador_tienda.dart';

/// Abre una hoja inferior con los pedidos PENDIENTES de pago del cliente para
/// que elija cuál pagar por la app. Devuelve `true` si algún pago se confirmó,
/// para que el llamador refresque su vista.
Future<bool> mostrarHojaMisPedidos(BuildContext context) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColores.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppEspaciado.md,
          right: AppEspaciado.md,
          top: AppEspaciado.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppEspaciado.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asa de la hoja.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppEspaciado.md),
                decoration: BoxDecoration(
                  color: AppColores.borde,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            Row(
              children: [
                const Icon(Icons.receipt_long_rounded,
                    color: AppColores.primario),
                const SizedBox(width: AppEspaciado.sm),
                const Expanded(
                  child: Text(
                    'Pedidos por pagar',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _cargando ? null : _cargar,
                  icon: const Icon(Icons.refresh, color: AppColores.acento),
                  tooltip: 'Actualizar',
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm),
            if (_cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_pedidos.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: EstadoVacio(
                  icono: Icons.receipt_long_outlined,
                  mensaje: 'No tienes pedidos pendientes de pago',
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _pedidos.length,
                  separatorBuilder: (_, _) => const Divider(height: 16),
                  itemBuilder: (_, i) => _fila(_pedidos[i]),
                ),
              ),
            const SizedBox(height: AppEspaciado.sm),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(_huboPago),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fila(PedidoCliente pedido) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(9),
          decoration: BoxDecoration(
            color: AppColores.advertencia.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.schedule_rounded,
              size: 18, color: AppColores.advertencia),
        ),
        const SizedBox(width: AppEspaciado.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pedido.codigo,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${_soles(pedido.total)} · ${pedido.items} '
                '${pedido.items == 1 ? 'ítem' : 'ítems'}'
                '${pedido.fecha.isNotEmpty ? ' · ${_fecha(pedido.fecha)}' : ''}',
                style: const TextStyle(
                    fontSize: 12, color: AppColores.textoSecundario),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppEspaciado.sm),
        SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: () => _pagar(pedido),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
            ),
            child: const Text('Pagar', style: TextStyle(fontSize: 12.5)),
          ),
        ),
      ],
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
