import 'package:flutter/material.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
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
          const _SeccionVentas('Vender', Icons.point_of_sale, _Vista.vender),
        if (p.tiene(PermisosMovil.pedidos))
          const _SeccionVentas(
            'Pedidos',
            Icons.shopping_basket_outlined,
            _Vista.pedidos,
          ),
        if (p.tiene(PermisosMovil.ventasHistorial))
          const _SeccionVentas(
            'Historial',
            Icons.receipt_long_outlined,
            _Vista.historial,
          ),
      ];
      _cargado = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!_cargado) {
      return Scaffold(
        backgroundColor: AppColores.fondo,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_secciones.isEmpty) {
      return Scaffold(
        backgroundColor: AppColores.fondo,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppEspaciado.md),
            child: Column(
              children: [
                CabeceraApp(titulo: 'Ventas'),
                SizedBox(height: AppEspaciado.lg),
                VacioApp(
                  icono: Icons.lock_outline_rounded,
                  titulo: 'Sin acceso a las ventas',
                  texto: 'Tu rol no tiene acceso a las ventas de la app.',
                ),
              ],
            ),
          ),
        ),
      );
    }

    final indice = _seccion.clamp(0, _secciones.length - 1);
    // La cabecera va dentro del desplazamiento de cada vista, como en la
    // tienda del socio: al bajar se va y deja todo el alto a los productos.
    final cabecera = Column(
      children: [
        const CabeceraApp(
          titulo: 'Ventas',
          subtitulo: 'Punto de venta y pedidos de la app',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        // Con un solo permiso no hace falta selector.
        if (_secciones.length > 1) ...[
          const SizedBox(height: AppEspaciado.sm),
          PestanasApp(
            textos: [for (final s in _secciones) s.titulo],
            activa: indice,
            onCambio: (i) => setState(() => _seccion = i),
          ),
        ],
      ],
    );
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        // IndexedStack para no perder el carrito armado al mirar los pedidos
        // y volver al punto de venta.
        child: IndexedStack(
          index: indice,
          children: [
            for (final (i, s) in _secciones.indexed)
              switch (s.vista) {
                _Vista.vender => PuntoVentaView(
                  cabecera: cabecera,
                  activa: i == indice,
                ),
                _Vista.pedidos => PedidosPendientesView(
                  cabecera: cabecera,
                  activa: i == indice,
                ),
                _Vista.historial => VentasRealizadasView(
                  cabecera: cabecera,
                  activa: i == indice,
                ),
              },
          ],
        ),
      ),
    );
  }
}

enum _Vista { vender, pedidos, historial }

class _SeccionVentas {
  final String titulo;
  final IconData icono;
  final _Vista vista;
  const _SeccionVentas(this.titulo, this.icono, this.vista);
}
