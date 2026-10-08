import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Piezas comunes de las vistas de Ventas (vender, pedidos e historial), con
/// el mismo estilo de la tienda del socio.

/// Nombre del cliente; las ventas de mostrador sin cliente llegan como
/// "- - -" o vacías.
String nombreCliente(String nombre) {
  final limpio = nombre.replaceAll(RegExp(r'[-\s]'), '');
  return limpio.isEmpty ? 'Cliente varios' : nombre.trim();
}

String soles(double v) => 'S/ ${NumberFormat('#,##0.00', 'es').format(v)}';

String fechaCorta(String valor) {
  final f = DateTime.tryParse(valor);
  return f == null ? valor : DateFormat("d MMM yyyy", 'es').format(f);
}

/// URL de la foto de un producto en el servidor de la empresa activa.
String urlProducto(String img) {
  if (img.isEmpty) return '';
  final limpio = img.startsWith('./') ? img.substring(2) : img;
  return '${HttpService().rutaActual}$limpio';
}

/// Foto del producto o, si no tiene, una caja sobre el tinte de la marca.
class FotoProducto extends StatelessWidget {
  final String imagen;
  final double tamanoIcono;

  const FotoProducto(this.imagen, {super.key, this.tamanoIcono = 36});

  @override
  Widget build(BuildContext context) {
    final url = urlProducto(imagen);
    final vacio = Container(
      color: AppColores.primario.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.inventory_2_outlined,
        size: tamanoIcono,
        color: AppColores.primario.withValues(alpha: 0.4),
      ),
    );
    if (url.isEmpty) return vacio;
    return Container(
      color: Colors.white,
      child: Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: 600,
        errorBuilder: (_, _, _) => vacio,
      ),
    );
  }
}

/// Inicial del cliente en un círculo con el degradado de la marca.
class AvatarInicial extends StatelessWidget {
  final String inicial;
  final double tamano;

  const AvatarInicial(this.inicial, {super.key, this.tamano = 46});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        shape: BoxShape.circle,
      ),
      child: Text(
        inicial,
        style: TextStyle(
          fontSize: tamano * 0.4,
          fontWeight: FontWeight.w800,
          color: AppColores.sobreRelleno,
        ),
      ),
    );
  }
}

/// Píldora de color sólido (estado, stock, puntos).
class PildoraVenta extends StatelessWidget {
  final String texto;
  final Color color;
  final IconData? icono;

  /// Suave: fondo tenue y texto en color (sobre tarjetas blancas).
  final bool suave;

  const PildoraVenta(
    this.texto,
    this.color, {
    super.key,
    this.icono,
    this.suave = false,
  });

  @override
  Widget build(BuildContext context) {
    final tinta = suave ? color : Colors.white;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: suave ? color.withValues(alpha: 0.12) : color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icono != null) ...[
            Icon(icono, size: 12, color: tinta),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              texto,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: tinta,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Renglón de producto dentro de una hoja de detalle: cantidad en recuadro,
/// nombre, precio unitario y total.
class FilaDetalleVenta extends StatelessWidget {
  final String nombre;
  final double cantidad;
  final double precio;
  final String unidad;
  final double total;

  const FilaDetalleVenta({
    super.key,
    required this.nombre,
    required this.cantidad,
    required this.precio,
    required this.unidad,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.sm + 2),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Text(
              '${cantidad.toStringAsFixed(0)}x',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColores.primario,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  unidad.isEmpty
                      ? '${soles(precio)} c/u'
                      : '${soles(precio)} · ${unidad.toLowerCase()}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Text(
            soles(total),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Total ........ S/ 00.00" para el pie de las hojas.
class TotalVenta extends StatelessWidget {
  final double total;
  final String etiqueta;

  const TotalVenta(this.total, {super.key, this.etiqueta = 'Total'});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 15,
            color: AppColores.textoSecundario,
          ),
        ),
        const Spacer(),
        Text(
          soles(total),
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            color: AppColores.textoPrincipal,
          ),
        ),
      ],
    );
  }
}

/// Mensaje centrado cuando una hoja no tiene productos.
class SinProductosHoja extends StatelessWidget {
  const SinProductosHoja({super.key});

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          'Sin productos',
          style: TextStyle(color: AppColores.textoSecundario),
        ),
      ),
    );
  }
}
