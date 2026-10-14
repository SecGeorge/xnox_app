import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/tienda_xnox/datos/repositorio_tienda_xnox.dart';
import 'package:xnox_app/features/tienda_xnox/dominio/producto_xnox.dart';

/// Piezas comunes de la tienda de XNOX: la tarjeta del producto, su ficha y
/// el pedido por WhatsApp. Las usan la sección de la tienda del socio y la
/// pantalla "Tienda XNOX" del personal.

const _simbolos = {'PEN': 'S/', 'USD': r'$', 'EUR': '€'};

String precioXnox(double valor, String moneda) =>
    '${_simbolos[moneda] ?? moneda} '
    '${NumberFormat('#,##0.00', 'es').format(valor)}';

/// Foto del producto con el ícono de respaldo si no tiene o no carga.
class FotoProductoXnox extends StatelessWidget {
  final String ruta;
  final double tamanoIcono;

  const FotoProductoXnox(this.ruta, {super.key, this.tamanoIcono = 36});

  @override
  Widget build(BuildContext context) {
    final vacio = Container(
      color: AppColores.primario.withValues(alpha: 0.06),
      alignment: Alignment.center,
      child: Icon(
        Icons.shopping_bag_outlined,
        size: tamanoIcono,
        color: AppColores.primario.withValues(alpha: 0.4),
      ),
    );
    final url = RepositorioTiendaXnox.urlImagen(ruta);
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

/// Distintivo "XNOX" para que se note que el producto no es del gimnasio.
class SelloXnox extends StatelessWidget {
  const SelloXnox({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFF151E38),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'XNOX',
        style: TextStyle(
          fontSize: 10,
          letterSpacing: 0.8,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Tarjeta del producto (cuadrícula o carrusel). Al tocarla abre la ficha.
class TarjetaProductoXnox extends StatelessWidget {
  final ProductoXnox producto;
  final VoidCallback onTap;

  const TarjetaProductoXnox({
    super.key,
    required this.producto,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = producto;
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Material(
      color: AppColores.superficie,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(color: AppColores.borde),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(AppEspaciado.radio - 2),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        FotoProductoXnox(p.imagen),
                        const Positioned(left: 6, top: 6, child: SelloXnox()),
                        if (p.enOferta)
                          Positioned(
                            right: 6,
                            top: 6,
                            child: _Etiqueta(
                              '-${p.descuento}%',
                              AppColores.naranja,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.categoria.isNotEmpty)
                      Text(
                        p.categoria.toUpperCase(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 10.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    Text(
                      p.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.25,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      precioXnox(p.precio, p.moneda),
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w800,
                        color: AppColores.primario,
                      ),
                    ),
                    if (p.enOferta)
                      Text(
                        precioXnox(p.precioAntes!, p.moneda),
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColores.textoSecundario,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Etiqueta extends StatelessWidget {
  final String texto;
  final Color color;

  const _Etiqueta(this.texto, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: Colors.white,
        ),
      ),
    );
  }
}

/// Ficha del producto: foto, precio, descripción y cómo pedirlo.
Future<void> mostrarFichaProductoXnox(
  BuildContext context,
  ProductoXnox p,
  PublicoTiendaXnox publico,
) {
  return mostrarHojaModerna<void>(
    context,
    builder: (ctx) => HojaModerna(
      titulo: p.nombre,
      subtitulo: [
        'Tienda XNOX',
        if (p.categoria.isNotEmpty) p.categoria,
      ].join(' · '),
      accion: IconButton(
        onPressed: () => Navigator.pop(ctx),
        icon: const Icon(
          Icons.close_rounded,
          color: AppColores.textoSecundario,
        ),
      ),
      pie: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (p.whatsapp != null)
            BotonHoja(
              texto: 'Pedir por WhatsApp',
              icono: Icons.chat_rounded,
              onPressed: () => _pedirPorWhatsApp(ctx, p, publico),
            ),
          if (p.enlace != null) ...[
            if (p.whatsapp != null) const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: () => _abrir(ctx, Uri.parse(p.enlace!)),
                icon: const Icon(Icons.open_in_new_rounded),
                label: Text(p.whatsapp == null ? 'Ver y pedir' : 'Ver más'),
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppEspaciado.radio),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
            child: AspectRatio(
              aspectRatio: 1.3,
              child: FotoProductoXnox(p.imagen, tamanoIcono: 64),
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                precioXnox(p.precio, p.moneda),
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColores.primario,
                ),
              ),
              if (p.enOferta) ...[
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 5),
                  child: Text(
                    precioXnox(p.precioAntes!, p.moneda),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColores.textoSecundario,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                ),
                const Spacer(),
                _Etiqueta('-${p.descuento}%', AppColores.naranja),
              ],
            ],
          ),
          if (p.descripcion.trim().isNotEmpty) ...[
            const SizedBox(height: AppEspaciado.sm + 4),
            Text(
              p.descripcion.trim(),
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: AppColores.textoPrincipal,
              ),
            ),
          ],
          const SizedBox(height: AppEspaciado.sm + 4),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppColores.primario),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Lo vende XNOX, no tu gimnasio: el pedido y el pago se '
                    'coordinan directamente con XNOX.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
        ],
      ),
    ),
  );
}

/// Abre WhatsApp con el producto, el gimnasio y quién pide ya escritos.
Future<void> _pedirPorWhatsApp(
  BuildContext context,
  ProductoXnox p,
  PublicoTiendaXnox publico,
) async {
  final prefs = await SharedPreferences.getInstance();
  final nombre = (prefs.getString('nombreCliente') ?? '').trim();
  final gimnasio = (ControladorMarca.instancia.marca.value.nombre ?? '').trim();
  final mensaje = [
    '¡Hola XNOX! 👋',
    'Me interesa *${p.nombre}* (${precioXnox(p.precio, p.moneda)}), '
        'que vi en la tienda de la app.',
    '',
    if (nombre.isNotEmpty) '• Nombre: $nombre',
    if (gimnasio.isNotEmpty) '• Gimnasio: $gimnasio',
    '• Soy ${publico.rol} del gimnasio',
  ].join('\n');
  if (!context.mounted) return;
  await _abrir(
    context,
    Uri.parse(
      'https://wa.me/${p.whatsapp}?text=${Uri.encodeComponent(mensaje)}',
    ),
  );
}

Future<void> _abrir(BuildContext context, Uri url) async {
  var ok = false;
  try {
    ok = await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {}
  if (!ok && context.mounted) {
    mostrarMensaje(
      context,
      'No se pudo abrir el enlace',
      tipo: TipoMensaje.error,
    );
  }
}
