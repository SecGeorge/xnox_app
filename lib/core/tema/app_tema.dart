import 'package:flutter/material.dart';

import 'package:xnox_app/core/tema/paleta_app.dart';

export 'package:xnox_app/core/tema/paleta_app.dart';

/// Sistema de diseño centralizado de XNOX-SOFT.
/// Todas las pantallas deben consumir estos tokens para mantener
/// una apariencia estandarizada (colores, espaciado, tipografía y sombras).
///
/// Los colores de marca salen de la [PaletaApp] activa (la plantilla que eligió
/// el gimnasio), por eso son getters y no constantes: no pueden ir dentro de un
/// `const`. Los colores semánticos (estados, éxito/error) son iguales para
/// todos los gimnasios y siguen siendo constantes.
class AppColores {
  AppColores._();

  static PaletaApp _paleta = PaletasApp.porDefecto;

  static PaletaApp get paleta => _paleta;

  /// Cambia la paleta en uso. Quien la cambia se encarga de redibujar la app
  /// (ver `ControladorPaleta`).
  static void aplicar(PaletaApp paleta) => _paleta = paleta;

  // Marca: color de "tinta" (íconos, textos destacados, selección).
  static Color get primario => _paleta.primario;
  static Color get primarioClaro => _paleta.primarioClaro;
  static Color get acento => _paleta.acento;

  // Relleno de marca: barra superior, cabeceras con degradado y botones
  // principales. En la mayoría de plantillas es el mismo [primario], pero en
  // XNOX-SOFT es blanco con borde azul.
  static Color get relleno => _paleta.relleno;
  static Color get rellenoClaro => _paleta.rellenoClaro;
  static Color get sobreRelleno => _paleta.sobreRelleno;
  static Color get sobreRellenoSuave => _paleta.sobreRellenoSuave;
  static Color? get bordeRelleno => _paleta.bordeRelleno;

  /// Degradado de las cabeceras de marca (tarjetas de resumen, membresía...).
  static LinearGradient get degradadoRelleno => LinearGradient(
        colors: [relleno, rellenoClaro],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  /// Borde de las cabeceras de marca: solo existe si el relleno es claro.
  static Border? get bordeCabecera => bordeRelleno == null
      ? null
      : Border.all(color: bordeRelleno!, width: 1.4);

  /// Borde de los botones con relleno de marca.
  static BorderSide? get ladoBoton =>
      bordeRelleno == null ? null : BorderSide(color: bordeRelleno!, width: 1.4);

  /// Tono claro de la marca para usar sobre fotos u otros fondos oscuros
  /// (barras de progreso, íconos destacados). Sale del [acento] de la paleta,
  /// aclarado lo justo para que se lea en cualquier plantilla.
  static Color get destacado {
    final hsl = HSLColor.fromColor(_paleta.acento);
    return hsl
        .withLightness(hsl.lightness < 0.62 ? 0.62 : hsl.lightness)
        .withSaturation((hsl.saturation + 0.1).clamp(0.0, 1.0))
        .toColor();
  }

  // Superficies
  static Color get fondo => _paleta.fondo;
  static Color get superficie => _paleta.superficie;
  static Color get borde => _paleta.borde;

  // Texto
  static Color get textoPrincipal => _paleta.textoPrincipal;
  static const Color textoSecundario = Color(0xFF7A869A);

  // Estados de miembros / semántica
  static const Color activo = Color(0xFF22A06B);
  static const Color deudor = Color(0xFFF5A623);
  static const Color moroso = Color(0xFFE5484D);
  static const Color vencido = Color(0xFF8A94A6);

  // Acentos auxiliares
  static const Color azul = Color(0xFF2E7CF6);
  static const Color verde = Color(0xFF22A06B);
  static const Color naranja = Color(0xFFF5A623);
  static const Color morado = Color(0xFF7C5CFC);

  // Semántica de mensajes / notificaciones
  static const Color exito = Color(0xFF22A06B);       // verde  -> éxito
  static const Color error = Color(0xFFE5484D);       // rojo   -> error / validación
  static const Color advertencia = Color(0xFFF5A623); // amarillo -> alerta
}

class AppEspaciado {
  AppEspaciado._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;

  static const double radio = 16;
  static const double radioSm = 12;

  /// Proporción (ancho / alto) del marco de las publicidades. Se usa al recortar
  /// la imagen en el admin y al mostrar la tarjeta al cliente, para que lo que
  /// el usuario encuadra sea exactamente lo que se ve en el marco.
  static const double publicidadRatioX = 5;
  static const double publicidadRatioY = 2;
  static const double publicidadRatio = publicidadRatioX / publicidadRatioY;
}

class AppSombras {
  AppSombras._();

  static List<BoxShadow> get tarjeta => [
        BoxShadow(
          color: AppColores.textoPrincipal.withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Construye el [ThemeData] global de la aplicación con la paleta activa.
ThemeData construirTema() {
  final lado = AppColores.ladoBoton;
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColores.primario,
      primary: AppColores.primario,
      surface: AppColores.superficie,
    ),
    scaffoldBackgroundColor: AppColores.fondo,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: AppColores.relleno,
      foregroundColor: AppColores.sobreRelleno,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      shape: AppColores.bordeRelleno == null
          ? null
          : Border(bottom: BorderSide(color: AppColores.bordeRelleno!)),
      titleTextStyle: TextStyle(
        color: AppColores.sobreRelleno,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColores.superficie,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        side: AppColores.bordeRelleno == null
            ? BorderSide.none
            : BorderSide(color: AppColores.borde),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColores.relleno,
        foregroundColor: AppColores.sobreRelleno,
        elevation: 0,
        side: lado,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColores.relleno,
      foregroundColor: AppColores.sobreRelleno,
      shape: lado == null
          ? null
          : StadiumBorder(side: lado),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: AppColores.primario),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColores.superficie,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        borderSide: BorderSide(color: AppColores.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        borderSide: BorderSide(color: AppColores.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        borderSide: BorderSide(color: AppColores.acento, width: 1.6),
      ),
    ),
  );
}
