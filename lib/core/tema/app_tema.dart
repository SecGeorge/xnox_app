import 'package:flutter/material.dart';

/// Sistema de diseño centralizado de XNOX-SOFT.
/// Todas las pantallas deben consumir estos tokens para mantener
/// una apariencia estandarizada (colores, espaciado, tipografía y sombras).
class AppColores {
  AppColores._();

  // Marca
  static const Color primario = Color(0xFF1A2B4C);
  static const Color primarioClaro = Color(0xFF2E4475);
  static const Color acento = Color(0xFF2E7CF6);

  // Superficies
  static const Color fondo = Color(0xFFF4F6FB);
  static const Color superficie = Color(0xFFFFFFFF);
  static const Color borde = Color(0xFFE6EAF2);

  // Texto
  static const Color textoPrincipal = Color(0xFF1A2B4C);
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
}

class AppSombras {
  AppSombras._();

  static List<BoxShadow> get tarjeta => [
        BoxShadow(
          color: const Color(0xFF1A2B4C).withValues(alpha: 0.06),
          blurRadius: 16,
          offset: const Offset(0, 6),
        ),
      ];
}

/// Construye el [ThemeData] global de la aplicación.
ThemeData construirTema() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColores.primario,
      primary: AppColores.primario,
    ),
    scaffoldBackgroundColor: AppColores.fondo,
    fontFamily: 'Roboto',
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColores.primario,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: AppColores.superficie,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColores.superficie,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        borderSide: const BorderSide(color: AppColores.borde),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        borderSide: const BorderSide(color: AppColores.borde),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        borderSide: const BorderSide(color: AppColores.acento, width: 1.6),
      ),
    ),
  );
}
