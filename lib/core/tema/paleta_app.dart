import 'package:flutter/material.dart';

/// Juego de colores de marca de un gimnasio. Cada gimnasio elige una
/// plantilla de [PaletasApp.plantillas] o arma una propia a partir de un
/// color ([PaletaApp.desdeColor]).
///
/// Hay dos familias de tokens:
/// - [primario] es la "tinta" de la marca: íconos, textos destacados, chips y
///   pestañas seleccionadas. Siempre debe leerse bien sobre blanco.
/// - [relleno] pinta las superficies de marca (barra superior, cabeceras con
///   degradado, botones principales) y [sobreRelleno] lo que va encima. Si el
///   relleno es claro (XNOX-SOFT) se dibuja con [bordeRelleno].
class PaletaApp {
  /// Lo que se guarda en la tabla `empresa` (columna `paleta`).
  final String id;
  final String nombre;
  final String descripcion;

  final Color primario;
  final Color primarioClaro;
  final Color acento;

  final Color relleno;
  final Color rellenoClaro;
  final Color sobreRelleno;
  final Color sobreRellenoSuave;
  final Color? bordeRelleno;

  final Color fondo;
  final Color superficie;
  final Color borde;
  final Color textoPrincipal;

  const PaletaApp({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.primario,
    required this.primarioClaro,
    required this.acento,
    required this.relleno,
    required this.rellenoClaro,
    required this.sobreRelleno,
    required this.sobreRellenoSuave,
    this.bordeRelleno,
    required this.fondo,
    required this.superficie,
    required this.borde,
    required this.textoPrincipal,
  });

  static const String prefijoPersonalizada = 'personalizada:';

  /// Paleta armada a partir de un único color de marca: relleno de ese color
  /// con texto blanco, y el resto de tonos derivados de él.
  factory PaletaApp.desdeColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    Color tono(double luz, {double? saturacion}) => hsl
        .withLightness(luz.clamp(0.0, 1.0))
        .withSaturation((saturacion ?? hsl.saturation).clamp(0.0, 1.0))
        .toColor();
    // Un color muy claro no se lee como tinta sobre blanco: se oscurece.
    final tinta = hsl.lightness > 0.45 ? tono(0.40) : color;
    final hex = color.toARGB32().toRadixString(16).padLeft(8, '0').substring(2);
    return PaletaApp(
      id: '$prefijoPersonalizada${hex.toUpperCase()}',
      nombre: 'Personalizada',
      descripcion: 'Tu color de marca',
      primario: tinta,
      primarioClaro: tono(HSLColor.fromColor(tinta).lightness + 0.12),
      acento: tinta,
      relleno: tinta,
      rellenoClaro: tono(HSLColor.fromColor(tinta).lightness + 0.12),
      sobreRelleno: Colors.white,
      sobreRellenoSuave: Colors.white70,
      fondo: tono(0.97, saturacion: hsl.saturation * 0.35),
      superficie: Colors.white,
      borde: tono(0.91, saturacion: hsl.saturation * 0.30),
      textoPrincipal: tono(0.16, saturacion: hsl.saturation * 0.45),
    );
  }

  /// Color con el que se armó una paleta personalizada, o `null` si es una
  /// plantilla.
  static Color? colorDePersonalizada(String id) {
    if (!id.startsWith(prefijoPersonalizada)) return null;
    final valor = int.tryParse(id.substring(prefijoPersonalizada.length), radix: 16);
    return valor == null ? null : Color(0xFF000000 | valor);
  }
}

/// Plantillas de colores que el gimnasio puede elegir.
class PaletasApp {
  PaletasApp._();

  /// Estilo propio de XNOX-SOFT: el blanco es el color principal y el azul
  /// marino de la marca va en los bordes, íconos y textos.
  static const xnoxsoft = PaletaApp(
    id: 'xnoxsoft',
    nombre: 'XNOX-SOFT',
    descripcion: 'Blanco con bordes azul marino',
    primario: Color(0xFF1A2B4C),
    primarioClaro: Color(0xFF2E4475),
    acento: Color(0xFF1A2B4C),
    relleno: Color(0xFFFFFFFF),
    rellenoClaro: Color(0xFFFFFFFF),
    sobreRelleno: Color(0xFF1A2B4C),
    sobreRellenoSuave: Color(0xFF5A6A88),
    bordeRelleno: Color(0xFF1A2B4C),
    fondo: Color(0xFFFFFFFF),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFF8C9AB6),
    textoPrincipal: Color(0xFF1A2B4C),
  );

  /// El azul marino con el que nació la app.
  static const marino = PaletaApp(
    id: 'marino',
    nombre: 'Azul marino',
    descripcion: 'Clásico y sobrio',
    primario: Color(0xFF1A2B4C),
    primarioClaro: Color(0xFF2E4475),
    acento: Color(0xFF2E7CF6),
    relleno: Color(0xFF1A2B4C),
    rellenoClaro: Color(0xFF2E4475),
    sobreRelleno: Colors.white,
    sobreRellenoSuave: Colors.white70,
    fondo: Color(0xFFF4F6FB),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFE6EAF2),
    textoPrincipal: Color(0xFF1A2B4C),
  );

  static const rojo = PaletaApp(
    id: 'rojo',
    nombre: 'Rojo energía',
    descripcion: 'Intenso, para gimnasios de fuerza',
    primario: Color(0xFFC62828),
    primarioClaro: Color(0xFFE53935),
    acento: Color(0xFFE53935),
    relleno: Color(0xFFB71C1C),
    rellenoClaro: Color(0xFFE53935),
    sobreRelleno: Colors.white,
    sobreRellenoSuave: Colors.white70,
    fondo: Color(0xFFFBF4F4),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFF0E0E0),
    textoPrincipal: Color(0xFF2B1515),
  );

  static const verde = PaletaApp(
    id: 'verde',
    nombre: 'Verde fitness',
    descripcion: 'Fresco y saludable',
    primario: Color(0xFF1B7F4E),
    primarioClaro: Color(0xFF26A269),
    acento: Color(0xFF26A269),
    relleno: Color(0xFF166B42),
    rellenoClaro: Color(0xFF26A269),
    sobreRelleno: Colors.white,
    sobreRellenoSuave: Colors.white70,
    fondo: Color(0xFFF2F8F5),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFDDEDE4),
    textoPrincipal: Color(0xFF12301F),
  );

  static const naranja = PaletaApp(
    id: 'naranja',
    nombre: 'Naranja potencia',
    descripcion: 'Vibrante y enérgico',
    primario: Color(0xFFD9480F),
    primarioClaro: Color(0xFFF76707),
    acento: Color(0xFFF76707),
    relleno: Color(0xFFD9480F),
    rellenoClaro: Color(0xFFF76707),
    sobreRelleno: Colors.white,
    sobreRellenoSuave: Colors.white70,
    fondo: Color(0xFFFCF6F2),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFF3E4DA),
    textoPrincipal: Color(0xFF33190C),
  );

  static const morado = PaletaApp(
    id: 'morado',
    nombre: 'Morado',
    descripcion: 'Moderno, para estudios y box',
    primario: Color(0xFF5B34C4),
    primarioClaro: Color(0xFF7C5CFC),
    acento: Color(0xFF7C5CFC),
    relleno: Color(0xFF4C2AA8),
    rellenoClaro: Color(0xFF7C5CFC),
    sobreRelleno: Colors.white,
    sobreRellenoSuave: Colors.white70,
    fondo: Color(0xFFF6F4FC),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFE6E1F5),
    textoPrincipal: Color(0xFF1F1640),
  );

  static const turquesa = PaletaApp(
    id: 'turquesa',
    nombre: 'Turquesa',
    descripcion: 'Calmo, para spa y funcional',
    primario: Color(0xFF0B7A83),
    primarioClaro: Color(0xFF12A1AC),
    acento: Color(0xFF12A1AC),
    relleno: Color(0xFF0B6F77),
    rellenoClaro: Color(0xFF12A1AC),
    sobreRelleno: Colors.white,
    sobreRellenoSuave: Colors.white70,
    fondo: Color(0xFFF1F8F9),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFD9ECEE),
    textoPrincipal: Color(0xFF0F2E31),
  );

  static const grafito = PaletaApp(
    id: 'grafito',
    nombre: 'Negro y dorado',
    descripcion: 'Elegante, estilo premium',
    primario: Color(0xFF1F1F1F),
    primarioClaro: Color(0xFF3A3A3A),
    acento: Color(0xFFC9A227),
    relleno: Color(0xFF151515),
    rellenoClaro: Color(0xFF3A3A3A),
    sobreRelleno: Color(0xFFF2D06B),
    sobreRellenoSuave: Color(0xFFD9CFB0),
    fondo: Color(0xFFF6F5F2),
    superficie: Color(0xFFFFFFFF),
    borde: Color(0xFFE7E3D8),
    textoPrincipal: Color(0xFF1A1A1A),
  );

  static const List<PaletaApp> plantillas = [
    xnoxsoft,
    marino,
    rojo,
    verde,
    naranja,
    morado,
    turquesa,
    grafito,
  ];

  /// Colores para armar una paleta personalizada.
  static const List<Color> coloresPersonalizados = [
    Color(0xFF0D47A1),
    Color(0xFF1565C0),
    Color(0xFF00838F),
    Color(0xFF2E7D32),
    Color(0xFF558B2F),
    Color(0xFFEF6C00),
    Color(0xFFD84315),
    Color(0xFFC2185B),
    Color(0xFFAD1457),
    Color(0xFF6A1B9A),
    Color(0xFF4527A0),
    Color(0xFF37474F),
    Color(0xFF5D4037),
    Color(0xFF212121),
  ];

  /// Paleta cuando aún no hay gimnasio o el guardado no se reconoce.
  static const PaletaApp porDefecto = marino;

  /// Plantilla con la que arranca cada gimnasio hasta que elija otra. Los que
  /// no estén aquí arrancan con [porDefecto].
  static const Map<String, String> _porCodigoGimnasio = {
    'XNONX': 'xnoxsoft',
  };

  static PaletaApp inicialPara(String? codigoGimnasio) =>
      porId(_porCodigoGimnasio[codigoGimnasio?.toUpperCase()]);

  /// Paleta guardada con ese [id] (plantilla o personalizada).
  static PaletaApp porId(String? id) {
    if (id == null) return porDefecto;
    final color = PaletaApp.colorDePersonalizada(id);
    if (color != null) return PaletaApp.desdeColor(color);
    for (final p in plantillas) {
      if (p.id == id) return p;
    }
    return porDefecto;
  }
}
