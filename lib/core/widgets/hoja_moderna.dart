import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Abre una hoja inferior con el estilo común de la app (esquinas amplias,
/// fondo de superficie, ocupa hasta [alturaMaxima] de la pantalla).
Future<T?> mostrarHojaModerna<T>(
  BuildContext context, {
  required WidgetBuilder builder,
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: AppColores.superficie,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: builder,
  );
}

/// Estructura de una hoja moderna: asa, encabezado (ícono en recuadro de
/// marca, título, subtítulo y una acción opcional), contenido desplazable y
/// un pie fijo para los botones.
class HojaModerna extends StatelessWidget {
  final IconData? icono;

  /// Reemplaza al recuadro del ícono (p. ej. el avatar del socio).
  final Widget? cabecera;
  final String titulo;
  final String? subtitulo;
  final Widget? accion;
  final Widget child;
  final Widget? pie;
  final double alturaMaxima;

  /// Sin relleno lateral en el contenido (p. ej. una imagen a todo el ancho).
  final bool contenidoSinMargen;

  const HojaModerna({
    super.key,
    this.icono,
    this.cabecera,
    required this.titulo,
    this.subtitulo,
    this.accion,
    required this.child,
    this.pie,
    this.alturaMaxima = 0.88,
    this.contenidoSinMargen = false,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return ConstrainedBox(
      constraints:
          BoxConstraints(maxHeight: media.size.height * alturaMaxima),
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColores.borde,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppEspaciado.lg, AppEspaciado.md, AppEspaciado.md, 0),
              child: Row(
                children: [
                  if (cabecera != null) ...[
                    cabecera!,
                    const SizedBox(width: 12),
                  ] else if (icono != null) ...[
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        gradient: AppColores.degradadoRelleno,
                        border: AppColores.bordeCabecera,
                        borderRadius:
                            BorderRadius.circular(AppEspaciado.radioSm),
                      ),
                      child: Icon(icono, color: AppColores.sobreRelleno),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          titulo,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 19,
                            height: 1.2,
                            fontWeight: FontWeight.w800,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        if (subtitulo != null)
                          Text(
                            subtitulo!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                      ],
                    ),
                  ),
                  ?accion,
                ],
              ),
            ),
            const SizedBox(height: AppEspaciado.md),
            Flexible(
              child: SingleChildScrollView(
                padding: contenidoSinMargen
                    ? EdgeInsets.zero
                    : const EdgeInsets.symmetric(horizontal: AppEspaciado.lg),
                child: child,
              ),
            ),
            if (pie != null)
              Container(
                padding: EdgeInsets.fromLTRB(AppEspaciado.lg, AppEspaciado.md,
                    AppEspaciado.lg, AppEspaciado.md + media.padding.bottom),
                decoration: BoxDecoration(
                  color: AppColores.superficie,
                  border: Border(top: BorderSide(color: AppColores.borde)),
                ),
                child: pie,
              )
            else
              SizedBox(height: AppEspaciado.lg + media.padding.bottom),
          ],
        ),
      ),
    );
  }
}

/// Botón principal a lo ancho para el pie de una hoja.
class BotonHoja extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool cargando;

  const BotonHoja({
    super.key,
    required this.texto,
    this.icono,
    this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton(
        onPressed: cargando ? null : onPressed,
        style: ElevatedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppEspaciado.radio),
          ),
        ),
        child: cargando
            ? SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: AppColores.sobreRelleno),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icono != null) ...[
                    Icon(icono, size: 20),
                    const SizedBox(width: 8),
                  ],
                  Text(texto),
                ],
              ),
      ),
    );
  }
}
