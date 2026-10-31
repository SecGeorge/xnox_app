import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/carrusel_banners.dart';
import 'package:xnox_app/core/widgets/fondo_xnet.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';
import 'package:xnox_app/features/ventas/presentacion/widget/piezas_ventas.dart';

/// Banners por carrusel en el inicio del socio.
const maximoBanners = 5;

/// Franja baja, como la tarjeta de la rutina de hoy.
const _altoBanner = 104.0;

/// Las próximas clases, sin repetir mientras haya otras: si no, un gimnasio
/// con zumba todos los días llenaría el carrusel solo con zumba.
List<SesionClase> clasesParaBanner(List<SesionClase> sesiones, DateTime ahora) {
  final proximas =
      sesiones.where((s) => !s.pasada && s.inicio.isAfter(ahora)).toList()
        ..sort((a, b) => a.inicio.compareTo(b.inicio));
  final vistas = <int>{};
  final primeras = proximas.where((s) => vistas.add(s.claseId)).toList();
  final repetidas = proximas.where((s) => !primeras.contains(s));
  return [...primeras, ...repetidas].take(maximoBanners).toList();
}

/// Productos con stock, primero los que tienen foto. Se barajan para que no
/// salgan siempre los mismos del catálogo.
List<ProductoTienda> productosParaBanner(List<ProductoTienda> productos) {
  final disponibles = productos.where((p) => p.disponible).toList()..shuffle();
  return [
    ...disponibles.where((p) => p.imagen.isNotEmpty),
    ...disponibles.where((p) => p.imagen.isEmpty),
  ].take(maximoBanners).toList();
}

/// Carrusel de las próximas clases del gimnasio.
class BannersClases extends StatelessWidget {
  final List<SesionClase> sesiones;
  final bool activo;
  final VoidCallback onTap;

  const BannersClases({
    super.key,
    required this.sesiones,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CarruselBanners(
      cantidad: sesiones.length,
      alto: _altoBanner,
      activo: activo,
      constructor: (_, i) => _BannerClase(sesion: sesiones[i], onTap: onTap),
    );
  }
}

class _BannerClase extends StatelessWidget {
  final SesionClase sesion;
  final VoidCallback onTap;

  const _BannerClase({required this.sesion, required this.onTap});

  String get _cuando {
    final hoy = DateTime.now();
    final inicio = sesion.inicio;
    final dif = DateTime(
      inicio.year,
      inicio.month,
      inicio.day,
    ).difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final dia = dif == 0
        ? 'HOY'
        : dif == 1
        ? 'MAÑANA'
        : DateFormat('EEE d MMM', 'es').format(inicio).toUpperCase();
    return '$dia · ${DateFormat('HH:mm').format(inicio)}';
  }

  String get _estado {
    if (sesion.reservada) return 'Ya tienes tu cupo';
    if (sesion.llena) return 'Sin cupos';
    final cupos = sesion.libres == 1
        ? 'Queda 1 cupo'
        : 'Quedan ${sesion.libres} cupos';
    final precio = sesion.precio;
    return !sesion.incluida && precio != null
        ? '${soles(precio)} · $cupos'
        : cupos;
  }

  /// Cupos primero: es lo que decide si reserva. Con quién y dónde, si entra.
  String get _detalle => [
    _estado,
    if (sesion.entrenador.isNotEmpty) 'Con ${sesion.entrenador}',
    if (sesion.salon.isNotEmpty) sesion.salon,
  ].join(' · ');

  @override
  Widget build(BuildContext context) {
    return FotoTarjeta(
      foto: 'assets/imagenes/inicio/motivacion.jpg',
      alineacion: const Alignment(0.3, -0.2),
      radio: AppEspaciado.radio + 2,
      degradadoHorizontal: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md - 2,
          vertical: AppEspaciado.sm + 4,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // El color que el gimnasio le puso a la clase en su calendario.
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: sesion.color,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: AppEspaciado.sm + 4),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _cuando,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 0.8,
                      fontWeight: FontWeight.w800,
                      color: Colors.white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    sesion.nombre.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tituloXnet.copyWith(fontSize: 19),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _detalle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppEspaciado.sm),
            Center(child: _Accion(sesion.puedeReservar ? 'Reservar' : 'Ver')),
          ],
        ),
      ),
    );
  }
}

/// Carrusel de productos de la tienda del gimnasio.
class BannersProductos extends StatelessWidget {
  final List<ProductoTienda> productos;
  final bool activo;
  final VoidCallback onTap;

  const BannersProductos({
    super.key,
    required this.productos,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return CarruselBanners(
      cantidad: productos.length,
      alto: _altoBanner,
      activo: activo,
      constructor: (_, i) =>
          _BannerProducto(producto: productos[i], onTap: onTap),
    );
  }
}

class _BannerProducto extends StatelessWidget {
  final ProductoTienda producto;
  final VoidCallback onTap;

  const _BannerProducto({required this.producto, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FondoXnet(
      radio: AppEspaciado.radio + 2,
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Las fotos del catálogo vienen casi siempre sobre blanco.
          SizedBox(
            width: _altoBanner,
            child: ColoredBox(
              color: Colors.white,
              child: FotoProducto(producto.imagen),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppEspaciado.sm + 4,
                vertical: AppEspaciado.sm + 2,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (producto.nombreMarca.isNotEmpty) ...[
                    Text(
                      producto.nombreMarca.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white.withValues(alpha: 0.75),
                      ),
                    ),
                    const SizedBox(height: 2),
                  ],
                  Text(
                    producto.nombre.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tituloXnet.copyWith(fontSize: 14.5),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          soles(producto.precio),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppEspaciado.xs),
                      const _Accion('Ver'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora blanca con la acción del banner: el toque lo recibe todo el banner.
class _Accion extends StatelessWidget {
  final String texto;

  const _Accion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            texto,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: Color(0xFF111111),
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: Color(0xFF111111),
          ),
        ],
      ),
    );
  }
}
