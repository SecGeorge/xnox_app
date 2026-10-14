import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/tienda_xnox/dominio/producto_xnox.dart';
import 'package:xnox_app/features/tienda_xnox/presentacion/widget/piezas_tienda_xnox.dart';

/// Carrusel "Tienda XNOX" dentro de la tienda del socio: productos que no son
/// del gimnasio. Si no hay ninguno no ocupa espacio.
class SeccionTiendaXnox extends StatelessWidget {
  final List<ProductoXnox> productos;

  const SeccionTiendaXnox({super.key, required this.productos});

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.local_mall_rounded, color: AppColores.primario),
            const SizedBox(width: AppEspaciado.sm),
            Expanded(
              child: Text(
                'Tienda XNOX',
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.2,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ),
            const SelloXnox(),
          ],
        ),
        const SizedBox(height: 2),
        const Text(
          'Más productos para ti, aparte de los de tu gimnasio',
          style: TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
        ),
        const SizedBox(height: AppEspaciado.sm + 4),
        SizedBox(
          height: 250,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: productos.length,
            separatorBuilder: (_, _) =>
                const SizedBox(width: AppEspaciado.sm + 6),
            itemBuilder: (_, i) => SizedBox(
              width: 160,
              child: TarjetaProductoXnox(
                producto: productos[i],
                onTap: () => mostrarFichaProductoXnox(
                  context,
                  productos[i],
                  PublicoTiendaXnox.cliente,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
