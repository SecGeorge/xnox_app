import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';

/// Logo del gimnasio al que apunta la app (el que subió en sus ajustes). Si no
/// tiene logo o no carga, muestra la inicial de su nombre con el color de marca.
///
/// Muchos gimnasios suben el logo en blanco sobre transparente: sobre un fondo
/// blanco desaparecería. Por eso se mide qué tan claro es el logo y se pinta
/// el recuadro con el color de marca cuando el logo es claro.
class LogoGimnasio extends StatelessWidget {
  final double tamano;

  /// Muestra el nombre del gimnasio al lado del logo.
  final bool conNombre;
  final Color? colorNombre;

  const LogoGimnasio({
    super.key,
    this.tamano = 40,
    this.conNombre = false,
    this.colorNombre,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MarcaGimnasio>(
      valueListenable: ControladorMarca.instancia.marca,
      builder: (context, marca, _) {
        final logo = _Logo(marca: marca, tamano: tamano);
        if (!conNombre || (marca.nombre ?? '').isEmpty) return logo;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            logo,
            const SizedBox(width: AppEspaciado.sm + 2),
            Flexible(
              child: Text(
                marca.nombre!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: tamano * 0.42,
                  fontWeight: FontWeight.w700,
                  color: colorNombre ?? AppColores.textoPrincipal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Logo extends StatefulWidget {
  final MarcaGimnasio marca;
  final double tamano;

  const _Logo({required this.marca, required this.tamano});

  @override
  State<_Logo> createState() => _LogoState();
}

class _LogoState extends State<_Logo> {
  /// URL → el logo es claro. Se mide una vez por logo.
  static final Map<String, bool> _claridad = {};

  @override
  void initState() {
    super.initState();
    _medir();
  }

  @override
  void didUpdateWidget(_Logo anterior) {
    super.didUpdateWidget(anterior);
    if (anterior.marca.logoUrl != widget.marca.logoUrl) _medir();
  }

  Future<void> _medir() async {
    final url = widget.marca.logoUrl;
    if (url == null || url.isEmpty || _claridad.containsKey(url)) return;
    final claro = await _esClaro(NetworkImage(url));
    if (claro == null) return;
    _claridad[url] = claro;
    if (mounted) setState(() {});
  }

  /// Luminancia media de los píxeles visibles del logo (> 0.7 = claro).
  static Future<bool?> _esClaro(ImageProvider proveedor) async {
    final completer = Completer<ui.Image?>();
    final flujo = proveedor.resolve(ImageConfiguration.empty);
    late final ImageStreamListener oyente;
    oyente = ImageStreamListener((info, _) {
      if (!completer.isCompleted) completer.complete(info.image.clone());
      flujo.removeListener(oyente);
    }, onError: (_, _) {
      if (!completer.isCompleted) completer.complete(null);
      flujo.removeListener(oyente);
    });
    flujo.addListener(oyente);
    final imagen = await completer.future;
    if (imagen == null) return null;
    try {
      final datos = await imagen.toByteData(format: ui.ImageByteFormat.rawRgba);
      if (datos == null) return null;
      final total = datos.lengthInBytes ~/ 4;
      final paso = (total / 4000).ceil().clamp(1, total);
      var suma = 0.0;
      var peso = 0.0;
      for (var i = 0; i < total; i += paso) {
        final o = i * 4;
        final a = datos.getUint8(o + 3) / 255;
        if (a < 0.1) continue;
        final lum = (0.2126 * datos.getUint8(o) +
                0.7152 * datos.getUint8(o + 1) +
                0.0722 * datos.getUint8(o + 2)) /
            255;
        suma += lum * a;
        peso += a;
      }
      if (peso == 0) return null;
      return suma / peso > 0.7;
    } finally {
      imagen.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final marca = widget.marca;
    final tamano = widget.tamano;
    final radio = BorderRadius.circular(tamano * 0.28);
    final nombre = marca.nombre ?? '';
    final inicial = Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColores.primario.withValues(alpha: 0.10),
        borderRadius: radio,
      ),
      child: Text(
        nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
        style: TextStyle(
          fontSize: tamano * 0.45,
          fontWeight: FontWeight.w800,
          color: AppColores.primario,
        ),
      ),
    );
    final url = marca.logoUrl;
    if (url == null || url.isEmpty) {
      return nombre.isEmpty ? const SizedBox.shrink() : inicial;
    }
    final claro = _claridad[url] ?? false;
    return Container(
      width: tamano,
      height: tamano,
      padding: EdgeInsets.all(tamano * 0.12),
      decoration: BoxDecoration(
        color: claro ? AppColores.primario : Colors.white,
        borderRadius: radio,
        border: claro ? null : Border.all(color: AppColores.borde),
      ),
      child: Image.network(
        url,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => inicial,
      ),
    );
  }
}
