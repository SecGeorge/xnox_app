import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Imagen de internet con caché en DISCO: se descarga una vez y al volver a
/// abrir la app sale al instante (`Image.network` solo guarda en memoria y la
/// baja de nuevo en cada arranque).
///
/// Solo para archivos cuyo nombre cambia al reemplazarlos, como los que guarda
/// el backend. Con [cacheWidth] se decodifica a ese ancho y gasta menos RAM.
Image imagenRed(
  String url, {
  double? width,
  double? height,
  BoxFit? fit,
  AlignmentGeometry alignment = Alignment.center,
  int? cacheWidth,
  ImageLoadingBuilder? loadingBuilder,
  ImageErrorWidgetBuilder? errorBuilder,
}) {
  return Image(
    image: ResizeImage.resizeIfNeeded(
      cacheWidth,
      null,
      CachedNetworkImageProvider(url),
    ),
    width: width,
    height: height,
    fit: fit,
    alignment: alignment,
    loadingBuilder: loadingBuilder,
    errorBuilder: errorBuilder,
  );
}
