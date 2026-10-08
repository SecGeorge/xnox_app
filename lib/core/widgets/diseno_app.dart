import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';

/// Piezas del diseño de la app (cabecera grande, portada con foto, títulos de
/// sección, chips, buscador…), para que todas las pantallas se vean igual que
/// el inicio, la tienda o la membresía.

const _fotos = 'assets/imagenes';

/// Fotos de portada disponibles (assets, sin red).
class FotosApp {
  FotosApp._();
  static const inicio = '$_fotos/inicio/rutina_hoy.jpg';
  static const membresia = '$_fotos/inicio/membresia.jpg';
  static const motivacion = '$_fotos/inicio/motivacion.jpg';
  static const progreso = '$_fotos/inicio/progreso.jpg';
  static const rutinas = '$_fotos/inicio/rutinas.jpg';
  static const tienda = '$_fotos/inicio/tienda.jpg';
  static const piernas = '$_fotos/sesiones/piernas.jpg';
  static const pecho = '$_fotos/sesiones/pecho.jpg';
  static const espalda = '$_fotos/sesiones/espalda.jpg';
  static const hombros = '$_fotos/sesiones/hombros.jpg';
  static const brazos = '$_fotos/sesiones/brazos.jpg';
  static const gluteos = '$_fotos/sesiones/gluteos.jpg';
  static const core = '$_fotos/sesiones/core.jpg';
  static const descanso = '$_fotos/sesiones/descanso.jpg';
}

/// Cabecera grande de pantalla: botón atrás (si se puede volver), título,
/// subtítulo y acciones redondas a la derecha.
class CabeceraApp extends StatelessWidget {
  final String titulo;
  final String? subtitulo;
  final List<Widget> acciones;

  /// null = automático (solo si la ruta puede volver).
  final bool? atras;

  const CabeceraApp({
    super.key,
    required this.titulo,
    this.subtitulo,
    this.acciones = const [],
    this.atras,
  });

  @override
  Widget build(BuildContext context) {
    final conAtras = atras ?? Navigator.of(context).canPop();
    return Row(
      children: [
        if (conAtras) ...[
          BotonRedondo(
            icono: Icons.arrow_back_rounded,
            onTap: () => Navigator.of(context).maybePop(),
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
                  fontSize: conAtras ? 24 : 27,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
              if (subtitulo != null) ...[
                const SizedBox(height: 2),
                Text(
                  subtitulo!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ],
          ),
        ),
        for (final a in acciones) ...[const SizedBox(width: 8), a],
      ],
    );
  }
}

/// Botón redondo blanco con borde, como los de la cabecera del inicio.
class BotonRedondo extends StatelessWidget {
  final IconData icono;
  final VoidCallback? onTap;
  final String? tooltip;

  /// Número en el globo (0 = sin globo).
  final int contador;
  final Color? colorContador;

  const BotonRedondo({
    super.key,
    required this.icono,
    this.onTap,
    this.tooltip,
    this.contador = 0,
    this.colorContador,
  });

  @override
  Widget build(BuildContext context) {
    final boton = Material(
      color: AppColores.superficie,
      shape: CircleBorder(side: BorderSide(color: AppColores.borde)),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 46,
          height: 46,
          child: Center(
            child: Badge(
              isLabelVisible: contador > 0,
              label: Text('$contador'),
              backgroundColor: colorContador ?? AppColores.moroso,
              child: Icon(icono, color: AppColores.primario),
            ),
          ),
        ),
      ),
    );
    return tooltip == null ? boton : Tooltip(message: tooltip!, child: boton);
  }
}

/// Portada con foto: etiqueta pequeña en el color destacado, un valor o
/// título grande y un texto, sobre la foto oscurecida con el color de la marca.
class PortadaFoto extends StatelessWidget {
  final String foto;
  final String etiqueta;
  final String titulo;
  final String? texto;
  final Alignment alineacion;
  final double altura;
  final VoidCallback? onTap;

  /// Contenido extra al pie (datos, un botón…).
  final Widget? pie;

  const PortadaFoto({
    super.key,
    required this.foto,
    required this.etiqueta,
    required this.titulo,
    this.texto,
    this.alineacion = const Alignment(0.4, -0.2),
    this.altura = 150,
    this.onTap,
    this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: altura,
      child: FotoTarjeta(
        foto: foto,
        alineacion: alineacion,
        radio: AppEspaciado.radio + 6,
        degradadoHorizontal: true,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: pie == null
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            children: [
              Text(
                etiqueta.toUpperCase(),
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColores.destacado,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                titulo,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 27,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              if (texto != null) ...[
                const SizedBox(height: 4),
                SizedBox(
                  width: 240,
                  child: Text(
                    texto!,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.35,
                      color: Colors.white.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ],
              if (pie != null) ...[const Spacer(), pie!],
            ],
          ),
        ),
      ),
    );
  }
}

/// Dato chico para el pie de una [PortadaFoto]: ícono en círculo + valor.
class DatoPortada extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String pie;

  const DatoPortada({
    super.key,
    required this.icono,
    required this.valor,
    required this.pie,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 17, color: AppColores.destacado),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: const TextStyle(
                fontSize: 15,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              pie,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Título de sección con ícono y una acción opcional a la derecha.
class TituloSeccion extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? accion;
  final VoidCallback? onAccion;

  /// Texto gris a la derecha (p. ej. "4 productos") cuando no hay acción.
  final String? detalle;

  const TituloSeccion({
    super.key,
    required this.icono,
    required this.titulo,
    this.accion,
    this.onAccion,
    this.detalle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: Row(
        children: [
          Icon(icono, color: AppColores.primario, size: 24),
          const SizedBox(width: AppEspaciado.sm),
          Expanded(
            child: Text(
              titulo,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          if (accion != null)
            InkWell(
              onTap: onAccion,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Row(
                  children: [
                    Text(
                      accion!,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColores.primario,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 18,
                      color: AppColores.primario,
                    ),
                  ],
                ),
              ),
            )
          else if (detalle != null)
            Text(
              detalle!,
              style: const TextStyle(
                fontSize: 13,
                color: AppColores.textoSecundario,
              ),
            ),
        ],
      ),
    );
  }
}

/// Tarjeta plana (superficie, borde fino, esquinas amplias).
class TarjetaPlana extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? colorBorde;

  const TarjetaPlana({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppEspaciado.md),
    this.onTap,
    this.color,
    this.colorBorde,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Material(
      color: color ?? AppColores.superficie,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Ink(
          padding: padding,
          decoration: BoxDecoration(
            borderRadius: radio,
            border: Border.all(color: colorBorde ?? AppColores.borde),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Ícono en un recuadro suave del color dado.
class IconoSuave extends StatelessWidget {
  final IconData icono;
  final Color? color;
  final double tamano;
  final bool circular;

  const IconoSuave(
    this.icono, {
    super.key,
    this.color,
    this.tamano = 44,
    this.circular = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppColores.primario;
    return Container(
      width: tamano,
      height: tamano,
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        shape: circular ? BoxShape.circle : BoxShape.rectangle,
        borderRadius: circular
            ? null
            : BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Icon(icono, color: c, size: tamano * 0.5),
    );
  }
}

/// Fila de lista: ícono, título, subtítulo y algo a la derecha.
class FilaApp extends StatelessWidget {
  final Widget inicio;
  final String titulo;
  final String? subtitulo;
  final Widget? fin;
  final VoidCallback? onTap;

  const FilaApp({
    super.key,
    required this.inicio,
    required this.titulo,
    this.subtitulo,
    this.fin,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            inicio,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  if (subtitulo != null && subtitulo!.isNotEmpty)
                    Text(
                      subtitulo!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                ],
              ),
            ),
            if (fin != null) ...[const SizedBox(width: 8), fin!],
          ],
        ),
      ),
    );
  }
}

/// Agrupa filas en una sola tarjeta con separadores finos.
class GrupoFilas extends StatelessWidget {
  final List<Widget> filas;

  const GrupoFilas({super.key, required this.filas});

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
        border: Border.all(color: AppColores.borde),
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          children: [
            for (var i = 0; i < filas.length; i++) ...[
              if (i > 0) Divider(height: 1, indent: 70, color: AppColores.borde),
              filas[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Chip de filtro en forma de píldora; activo va relleno con la tinta.
class ChipApp extends StatelessWidget {
  final String texto;
  final bool activo;
  final VoidCallback? onTap;
  final int? contador;
  final IconData? icono;

  const ChipApp({
    super.key,
    required this.texto,
    required this.activo,
    this.onTap,
    this.contador,
    this.icono,
  });

  @override
  Widget build(BuildContext context) {
    final color = activo ? Colors.white : AppColores.textoPrincipal;
    return Material(
      color: activo ? AppColores.primario : AppColores.superficie,
      shape: StadiumBorder(
        side: BorderSide(
          color: activo ? AppColores.primario : AppColores.borde,
        ),
      ),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icono != null) ...[
                Icon(icono, size: 16, color: color),
                const SizedBox(width: 6),
              ],
              Text(
                texto,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
              if (contador != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                  decoration: BoxDecoration(
                    color: activo
                        ? Colors.white.withValues(alpha: 0.22)
                        : AppColores.primario.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$contador',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: activo ? Colors.white : AppColores.primario,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila horizontal desplazable de [ChipApp].
class FilaChips extends StatelessWidget {
  final List<Widget> chips;
  final EdgeInsetsGeometry padding;

  const FilaChips({
    super.key,
    required this.chips,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: padding,
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, i) => chips[i],
      ),
    );
  }
}

/// Buscador redondeado blanco.
class BuscadorApp extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  final TextEditingController? controller;

  const BuscadorApp({
    super.key,
    required this.hint,
    required this.onChanged,
    this.controller,
  });

  @override
  Widget build(BuildContext context) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(30),
      borderSide: BorderSide(color: AppColores.borde),
    );
    return TextField(
      controller: controller,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded),
        filled: true,
        fillColor: AppColores.superficie,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: borde,
        enabledBorder: borde,
        focusedBorder: borde.copyWith(
          borderSide: BorderSide(color: AppColores.primario, width: 1.4),
        ),
      ),
    );
  }
}

/// Estado vacío con ícono en círculo, título y texto.
class VacioApp extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? texto;
  final Widget? accion;

  const VacioApp({
    super.key,
    required this.icono,
    required this.titulo,
    this.texto,
    this.accion,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaPlana(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icono, size: 30, color: AppColores.primario),
          ),
          const SizedBox(height: 12),
          Text(
            titulo,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          if (texto != null) ...[
            const SizedBox(height: 4),
            Text(
              texto!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppColores.textoSecundario,
              ),
            ),
          ],
          if (accion != null) ...[const SizedBox(height: 14), accion!],
        ],
      ),
    );
  }
}

/// Pantalla estándar: fondo, área segura, desplazable con "jalar para
/// recargar" y relleno lateral. [encima] queda fijo arriba (p. ej. cabecera).
class PantallaApp extends StatelessWidget {
  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final Widget? botonFlotante;
  final Widget? pie;
  final double espacioAbajo;

  const PantallaApp({
    super.key,
    required this.children,
    this.onRefresh,
    this.botonFlotante,
    this.pie,
    // Deja aire para botones flotantes (el menú del admin, "Nueva"…).
    this.espacioAbajo = 100,
  });

  @override
  Widget build(BuildContext context) {
    Widget lista = ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppEspaciado.md,
        AppEspaciado.md,
        AppEspaciado.md,
        espacioAbajo,
      ),
      children: children,
    );
    if (onRefresh != null) {
      lista = RefreshIndicator(onRefresh: onRefresh!, child: lista);
    }
    return Scaffold(
      backgroundColor: AppColores.fondo,
      floatingActionButton: botonFlotante,
      bottomNavigationBar: pie,
      body: SafeArea(bottom: pie == null, child: lista),
    );
  }
}

/// Pie fijo con un botón principal a lo ancho (formularios).
class PieBoton extends StatelessWidget {
  final String texto;
  final IconData? icono;
  final VoidCallback? onPressed;
  final bool cargando;

  const PieBoton({
    super.key,
    required this.texto,
    this.icono,
    this.onPressed,
    this.cargando = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        AppEspaciado.md,
        AppEspaciado.sm + 4,
        AppEspaciado.md,
        AppEspaciado.sm + 4 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        border: Border(top: BorderSide(color: AppColores.borde)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 52,
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
                    strokeWidth: 2.4,
                    color: AppColores.sobreRelleno,
                  ),
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
      ),
    );
  }
}

/// Pestañas de texto con una línea animada bajo la activa (como en Rutinas).
class PestanasApp extends StatelessWidget {
  final List<String> textos;
  final int activa;
  final ValueChanged<int> onCambio;

  const PestanasApp({
    super.key,
    required this.textos,
    required this.activa,
    required this.onCambio,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, restr) {
        final ancho = restr.maxWidth / textos.length;
        return SizedBox(
          height: 46,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(height: 1, color: AppColores.borde),
              ),
              AnimatedPositioned(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                left: ancho * activa + ancho * 0.2,
                width: ancho * 0.6,
                bottom: 0,
                child: Container(
                  height: 3,
                  decoration: BoxDecoration(
                    color: AppColores.primario,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < textos.length; i++)
                    Expanded(
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () => onCambio(i),
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontFamily: 'Roboto',
                              fontSize: 15,
                              fontWeight: i == activa
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: i == activa
                                  ? AppColores.primario
                                  : AppColores.textoSecundario,
                            ),
                            child: Text(textos[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
