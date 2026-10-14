import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';

/// Fotos de portada de Nutrición (Unsplash, licencia libre).
/// Créditos en assets/imagenes/nutricion/CREDITOS.txt (Unsplash y Wikimedia
/// Commons).
class FotosNutricion {
  FotosNutricion._();
  static const _ruta = 'assets/imagenes/nutricion';
  static const plato = '$_ruta/plato.jpg';
  static const mesa = '$_ruta/mesa.jpg';
  static const desayuno = '$_ruta/desayuno.jpg';
  static const almuerzo = '$_ruta/almuerzo.jpg';
  static const cena = '$_ruta/cena.jpg';
  static const aperitivo = '$_ruta/aperitivo.jpg';
  static const metas = '$_ruta/metas.jpg';
  static const diario = '$_ruta/diario.jpg';

  /// Foto de cada comida del día.
  static String de(String tiempo) => switch (tiempo) {
    'desayuno' => desayuno,
    'almuerzo' => almuerzo,
    'cena' => cena,
    _ => aperitivo,
  };
}

/// Portada con foto al estilo de Rutinas: chip con ícono arriba, título
/// grande, detalle, un botón opcional y, si se da [total], una barra por
/// segmentos con cuántos van hechos.
class PortadaNutricion extends StatelessWidget {
  final String foto;
  final IconData icono;
  final String chip;
  final String titulo;
  final String? detalle;
  final Widget? accion;

  /// Datos al pie (p. ej. racha y récord). Pasan a otra línea si no caben.
  final List<Widget> pie;
  final int? hechos;
  final int? total;
  final double alto;
  final Alignment alineacion;
  final VoidCallback? onTap;

  const PortadaNutricion({
    super.key,
    required this.foto,
    required this.icono,
    required this.chip,
    required this.titulo,
    this.detalle,
    this.accion,
    this.pie = const [],
    this.hechos,
    this.total,
    this.alto = 150,
    this.alineacion = Alignment.center,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = total ?? 0;
    final h = hechos ?? 0;
    // [alto] es el mínimo. El contenido se mide tal cual (sin calcular la
    // altura por adelantado, que en algunos teléfonos se quedaba corta y
    // desbordaba): si el título ocupa dos líneas o la letra es grande, la
    // portada crece. Con espacio de sobra, el chip queda arriba y lo demás
    // abajo (spaceBetween reparte el alto mínimo).
    return FotoTarjeta(
      foto: foto,
      alineacion: alineacion,
      radio: AppEspaciado.radio + 6,
      degradadoHorizontal: true,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(AppEspaciado.md),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: alto - AppEspaciado.md * 2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChipFoto(icono, chip),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    titulo,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 23,
                      height: 1.1,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                      color: Colors.white,
                    ),
                  ),
                  if (detalle != null) ...[
                    const SizedBox(height: 3),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 260),
                      child: Text(
                        detalle!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.3,
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ),
                  ],
                  if (t > 0) ...[
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        for (var i = 0; i < t; i++) ...[
                          if (i > 0) const SizedBox(width: 4),
                          Expanded(
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: i < h
                                    ? AppColores.destacado
                                    : Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (pie.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 18, runSpacing: 8, children: pie),
                  ],
                  if (accion != null) ...[const SizedBox(height: 10), accion!],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dato del pie de una [PortadaNutricion]: ícono en círculo, valor y texto.
/// Como `DatoPortada`, pero el texto se parte si no cabe (letra grande).
class DatoPie extends StatelessWidget {
  final IconData icono;
  final String valor;
  final String pie;

  const DatoPie({
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
        Flexible(
          child: Column(
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
        ),
      ],
    );
  }
}

/// Chip sobre una foto: ícono y texto en el color destacado (como Rutinas).
class ChipFoto extends StatelessWidget {
  final IconData icono;
  final String texto;

  const ChipFoto(this.icono, this.texto, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 4, 11, 4),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColores.destacado.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 16, color: AppColores.destacado),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              texto.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 0.8,
                fontWeight: FontWeight.w800,
                color: AppColores.destacado,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón sobre una foto (relleno con el color destacado), como "Ver detalles"
/// en Rutinas.
class BotonFoto extends StatelessWidget {
  final String texto;
  final IconData icono;
  final VoidCallback onTap;

  const BotonFoto(
    this.texto, {
    super.key,
    this.icono = Icons.add_rounded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final claro = AppColores.bordeRelleno != null;
    final fondo = claro ? AppColores.relleno : AppColores.destacado;
    final tinta = claro
        ? AppColores.sobreRelleno
        : AppColores.destacado.computeLuminance() > 0.45
        ? const Color(0xFF0E1A12)
        : Colors.white;
    final radio = BorderRadius.circular(AppEspaciado.radioSm);
    return Material(
      color: fondo,
      borderRadius: radio,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icono, size: 19, color: tinta),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  texto,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: tinta,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acceso con foto (como los del inicio): ícono en círculo, título y detalle.
class AccesoFoto extends StatelessWidget {
  final String foto;
  final IconData icono;
  final String titulo;
  final String detalle;
  final VoidCallback onTap;

  const AccesoFoto({
    super.key,
    required this.foto,
    required this.icono,
    required this.titulo,
    required this.detalle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return FotoTarjeta(
      foto: foto,
      radio: AppEspaciado.radio + 2,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 150 - 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.35),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColores.destacado.withValues(alpha: 0.6),
                  ),
                ),
                child: Icon(icono, size: 21, color: AppColores.destacado),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 8),
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    detalle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.25,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Colores de los gráficos: uno por medida (cada gráfico tiene una sola
/// serie). Los mismos tonos que Seguimiento en el web, aptos para daltonismo.
class ColoresNutricion {
  ColoresNutricion._();
  static const proteina = Color(0xFF2A78D6);
  static const grasa = Color(0xFFEB6834);
  static const carbohidrato = Color(0xFF7C5CFC);
  static const kcal = Color(0xFF22A06B);
  static const meta = Color(0xFF64748B);

  static Color de(String clave) => switch (clave) {
    'proteina' => proteina,
    'grasa' => grasa,
    'carbohidrato' => carbohidrato,
    _ => kcal,
  };
}

/// Chips "Alto en …" de un alimento.
class EtiquetasAlimento extends StatelessWidget {
  final List<String> claves;
  final bool compactas;

  const EtiquetasAlimento(this.claves, {super.key, this.compactas = true});

  @override
  Widget build(BuildContext context) {
    if (claves.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final clave in claves)
          Builder(
            builder: (_) {
              final e = EtiquetaNutricional.de(clave);
              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: compactas ? 7 : 9,
                  vertical: compactas ? 1.5 : 3,
                ),
                decoration: BoxDecoration(
                  color: e.color.withValues(alpha: 0.08),
                  border: Border.all(color: e.color.withValues(alpha: 0.35)),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      e.advertencia
                          ? Icons.warning_amber_rounded
                          : Icons.thumb_up_alt_rounded,
                      size: compactas ? 10 : 12,
                      color: e.color,
                    ),
                    const SizedBox(width: 3),
                    // Flexible: si la tarjeta es angosta o la letra grande,
                    // la etiqueta pasa a dos líneas en vez de desbordarse.
                    Flexible(
                      child: Text(
                        e.nombre,
                        style: TextStyle(
                          fontSize: compactas ? 10.5 : 12,
                          fontWeight: FontWeight.w700,
                          color: e.color,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Barra de avance de un nutriente contra su meta, con el estado en texto e
/// ícono (no solo en color).
class BarraMeta extends StatelessWidget {
  final Nutriente nutriente;
  final double valor;
  final MetaNutricion? meta;

  const BarraMeta({
    super.key,
    required this.nutriente,
    required this.valor,
    this.meta,
  });

  @override
  Widget build(BuildContext context) {
    final m = meta;
    final color = ColoresNutricion.de(nutriente.clave);
    final avance = m == null || m.cantidad <= 0
        ? 0.0
        : (valor / m.cantidad).clamp(0.0, 1.0);
    final cumple = m?.cumple(valor);
    final pasado = m != null && m.regla == 'maximo' && valor > m.cantidad;

    final (IconData icono, String estado, Color colorEstado) = switch (m) {
      null => (Icons.remove_rounded, 'Sin meta', AppColores.textoSecundario),
      _ when pasado => (Icons.error_rounded, 'Te pasaste', AppColores.error),
      _ when cumple == true => (
        Icons.check_circle_rounded,
        'Cumplido',
        AppColores.exito,
      ),
      _ when m.regla == 'minimo' => (
        Icons.trending_up_rounded,
        'Faltan ${nutriente.formato(m.cantidad - valor)}',
        AppColores.textoSecundario,
      ),
      _ when m.regla == 'maximo' => (
        Icons.check_circle_outline_rounded,
        'Quedan ${nutriente.formato(m.cantidad - valor)}',
        AppColores.textoSecundario,
      ),
      _ => (
        valor < m.cantidad
            ? Icons.trending_up_rounded
            : Icons.error_outline_rounded,
        valor < m.cantidad
            ? 'Faltan ${nutriente.formato(m.cantidad - valor)}'
            : 'Te pasaste ${nutriente.formato(valor - m.cantidad)}',
        valor < m.cantidad
            ? AppColores.textoSecundario
            : AppColores.advertencia,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                nutriente.nombre,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text.rich(
                textAlign: TextAlign.end,
                TextSpan(
                  children: [
                    TextSpan(
                      text: nutriente.formato(valor),
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    if (m != null)
                      TextSpan(
                        text: ' / ${nutriente.formato(m.cantidad)}',
                        style: const TextStyle(
                          color: AppColores.textoSecundario,
                        ),
                      ),
                  ],
                ),
                style: const TextStyle(fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: m == null ? 0 : avance,
            minHeight: 8,
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation(
              pasado ? AppColores.error : color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(icono, size: 14, color: colorEstado),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                m == null ? estado : '$estado · ${m.reglaTexto}',
                style: TextStyle(fontSize: 11.5, color: colorEstado),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Gráfico de barras por día de un nutriente con la meta como línea
/// discontinua. Tocar una barra muestra el valor de ese día.
class GraficoDiasNutriente extends StatefulWidget {
  final Nutriente nutriente;
  final List<DateTime> fechas;
  final Map<String, DiaNutricion> porFecha;
  final MetaNutricion? meta;

  const GraficoDiasNutriente({
    super.key,
    required this.nutriente,
    required this.fechas,
    required this.porFecha,
    this.meta,
  });

  @override
  State<GraficoDiasNutriente> createState() => _GraficoDiasNutrienteState();
}

class _GraficoDiasNutrienteState extends State<GraficoDiasNutriente> {
  int? _elegido;

  double _valor(int i) =>
      widget.porFecha[isoFecha(widget.fechas[i])]?.totales[widget
          .nutriente
          .clave] ??
      0;

  @override
  Widget build(BuildContext context) {
    final n = widget.nutriente;
    final color = ColoresNutricion.de(n.clave);
    final i = _elegido ?? widget.fechas.length - 1;
    final dia = widget.porFecha[isoFecha(widget.fechas[i])];
    final cumple = dia?.cumple[n.clave];
    final f = widget.fechas[i];

    return TarjetaPlana(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${n.nombre} por día',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              if (widget.meta != null)
                Row(
                  children: [
                    Container(
                      width: 14,
                      height: 2,
                      color: ColoresNutricion.meta,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Meta ${n.formato(widget.meta!.cantidad)}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 4),
          // Lectura del día tocado (por defecto, el último).
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${f.day}/${f.month}: '),
                TextSpan(
                  text: dia == null ? 'sin registro' : n.formato(_valor(i)),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                if (cumple != null)
                  TextSpan(
                    text: cumple ? '  ✓ cumplió' : '  ✗ no cumplió',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: cumple ? AppColores.exito : AppColores.error,
                    ),
                  ),
              ],
            ),
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 130,
            child: LayoutBuilder(
              builder: (context, restr) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) {
                  final ancho = restr.maxWidth / widget.fechas.length;
                  setState(
                    () => _elegido = (d.localPosition.dx / ancho).floor().clamp(
                      0,
                      widget.fechas.length - 1,
                    ),
                  );
                },
                child: CustomPaint(
                  size: Size(restr.maxWidth, 130),
                  painter: _PintorBarras(
                    valores: [
                      for (var k = 0; k < widget.fechas.length; k++) _valor(k),
                    ],
                    meta: widget.meta?.cantidad,
                    color: color,
                    elegido: i,
                    colorEje: AppColores.borde,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${widget.fechas.first.day}/${widget.fechas.first.month}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColores.textoSecundario,
                ),
              ),
              const Spacer(),
              const Text(
                'Hoy',
                style: TextStyle(
                  fontSize: 11,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PintorBarras extends CustomPainter {
  final List<double> valores;
  final double? meta;
  final Color color;
  final int elegido;
  final Color colorEje;

  _PintorBarras({
    required this.valores,
    required this.meta,
    required this.color,
    required this.elegido,
    required this.colorEje,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final maximo =
        [...valores, meta ?? 0, 1.0].reduce((a, b) => a > b ? a : b) * 1.15;
    final ancho = size.width / valores.length;
    final barra = (ancho * 0.55).clamp(3.0, 18.0);

    canvas.drawLine(
      Offset(0, size.height),
      Offset(size.width, size.height),
      Paint()
        ..color = colorEje
        ..strokeWidth = 1,
    );

    for (var i = 0; i < valores.length; i++) {
      final v = valores[i];
      if (v <= 0) continue;
      final alto = (v / maximo) * size.height;
      final x = ancho * i + (ancho - barra) / 2;
      final rect = RRect.fromRectAndCorners(
        Rect.fromLTWH(x, size.height - alto, barra, alto),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(
        rect,
        Paint()..color = i == elegido ? color : color.withValues(alpha: 0.55),
      );
    }

    final m = meta;
    if (m != null && m > 0) {
      final y = size.height - (m / maximo) * size.height;
      final pintura = Paint()
        ..color = ColoresNutricion.meta
        ..strokeWidth = 2;
      for (double x = 0; x < size.width; x += 9) {
        canvas.drawLine(
          Offset(x, y),
          Offset((x + 5).clamp(0, size.width), y),
          pintura,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PintorBarras old) =>
      old.valores != valores || old.meta != meta || old.elegido != elegido;
}

/// Foto del alimento. Todas tienen una: la del catálogo (Wikimedia Commons),
/// la del producto (Open Food Facts) o la genérica; si no carga, se usa la
/// genérica del teléfono. Se guarda en caché para no bajarla cada vez.
class FotoAlimento extends StatelessWidget {
  final Alimento alimento;
  final double tamano;

  /// Alto distinto del ancho (p. ej. una portada a lo ancho).
  final double? alto;
  final double? radio;

  const FotoAlimento(
    this.alimento, {
    super.key,
    this.tamano = 44,
    this.alto,
    this.radio,
  });

  /// URL absoluta: las rutas del backend se arman con el servidor de la
  /// empresa activa (`rutaActual`), nunca con la constante de desarrollo.
  static String? url(String? ruta) {
    final r = ruta?.trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    return '${HttpService().rutaActual}${r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '')}';
  }

  @override
  Widget build(BuildContext context) {
    final ancho = tamano;
    final altura = alto ?? tamano;
    final generica = Image.asset(
      FotosNutricion.plato,
      width: ancho,
      height: altura,
      fit: BoxFit.cover,
    );
    final u = url(alimento.imagenUrl);
    return ClipRRect(
      borderRadius: BorderRadius.circular(radio ?? AppEspaciado.radioSm),
      child: u == null
          ? generica
          : CachedNetworkImage(
              imageUrl: u,
              width: ancho,
              height: altura,
              fit: BoxFit.cover,
              memCacheWidth: ancho.isFinite ? (ancho * 3).round() : null,
              placeholder: (_, _) => Container(
                width: ancho,
                height: altura,
                color: AppColores.borde.withValues(alpha: 0.5),
              ),
              errorWidget: (_, _, _) => generica,
            ),
    );
  }
}
