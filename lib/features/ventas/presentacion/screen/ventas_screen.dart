import 'package:flutter/material.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/pedidos_pendientes_view.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/punto_venta_view.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/ventas_realizadas_view.dart';

/// Módulo de ventas del admin en el móvil. Reúne las dos operaciones de
/// mostrador del panel web: vender productos (punto de venta) y cobrar los
/// pedidos que los clientes hacen desde la app.
class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  int _seccion = 0;
  List<_SeccionVentas> _secciones = const [];
  bool _cargado = false;

  @override
  void initState() {
    super.initState();
    _cargarPermisos();
  }

  Future<void> _cargarPermisos() async {
    final p = await Permisos.cargar();
    if (!mounted) return;
    setState(() {
      _secciones = [
        // Una sola palabra por pestaña: con tres segmentos en pantallas
        // angostas, los textos largos se amontonaban.
        if (p.tiene(PermisosMovil.ventas))
          const _SeccionVentas(
            'Vender',
            Icons.point_of_sale,
            PuntoVentaView(),
          ),
        if (p.tiene(PermisosMovil.pedidos))
          const _SeccionVentas(
            'Pedidos',
            Icons.shopping_basket_outlined,
            PedidosPendientesView(),
          ),
        if (p.tiene(PermisosMovil.ventasHistorial))
          const _SeccionVentas(
            'Historial',
            Icons.receipt_long_outlined,
            VentasRealizadasView(),
          ),
      ];
      _cargado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) {
      return const Scaffold(
        backgroundColor: AppColores.fondo,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_secciones.isEmpty) {
      return Scaffold(
        backgroundColor: AppColores.fondo,
        appBar: AppBar(title: const Text('Ventas')),
        body: const EstadoVacio(
          icono: Icons.lock_outline,
          mensaje: 'Tu rol no tiene acceso a las ventas de la app',
        ),
      );
    }

    final indice = _seccion.clamp(0, _secciones.length - 1);
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Ventas')),
      body: Column(
        children: [
          // Con un solo permiso no hace falta selector: se muestra directo.
          if (_secciones.length > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                  AppEspaciado.md, AppEspaciado.md, AppEspaciado.sm),
              child: SegmentedButton<int>(
                segments: [
                  for (var i = 0; i < _secciones.length; i++)
                    ButtonSegment(
                      value: i,
                      label: Text(
                        _secciones[i].titulo,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      icon: Icon(_secciones[i].icono, size: 17),
                    ),
                ],
                selected: {indice},
                onSelectionChanged: (s) => setState(() => _seccion = s.first),
                // Sin el check de "seleccionado" queda más aire para el texto.
                showSelectedIcon: false,
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? AppColores.primario
                        : AppColores.superficie,
                  ),
                  foregroundColor: WidgetStateProperty.resolveWith(
                    (states) => states.contains(WidgetState.selected)
                        ? Colors.white
                        : AppColores.textoSecundario,
                  ),
                  textStyle: const WidgetStatePropertyAll(
                    TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  padding: const WidgetStatePropertyAll(
                    EdgeInsets.symmetric(horizontal: AppEspaciado.sm),
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ),
          Expanded(
            // IndexedStack para no perder el carrito armado al mirar los
            // pedidos y volver al punto de venta.
            child: IndexedStack(
              index: indice,
              children: [for (final s in _secciones) s.vista],
            ),
          ),
        ],
      ),
    );
  }
}

class _SeccionVentas {
  final String titulo;
  final IconData icono;
  final Widget vista;
  const _SeccionVentas(this.titulo, this.icono, this.vista);
}
