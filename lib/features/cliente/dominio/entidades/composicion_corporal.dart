import 'package:flutter/material.dart';

/// Clasificación del IMC de la OMS, de menor a mayor.
enum NivelImc {
  bajoPeso('Bajo peso', 0, 18.5, Color(0xFF2E7CF6)),
  normal('Peso normal', 18.5, 25, Color(0xFF22A06B)),
  sobrepeso('Sobrepeso', 25, 30, Color(0xFFF5A623)),
  obesidad1('Obesidad I', 30, 35, Color(0xFFEB6834)),
  obesidad2('Obesidad II', 35, 40, Color(0xFFE5484D)),
  obesidad3('Obesidad III', 40, 99, Color(0xFFA3195B));

  final String nombre;
  final double desde;
  final double hasta;
  final Color color;

  const NivelImc(this.nombre, this.desde, this.hasta, this.color);

  /// "18.5 a 24.9", "40 o más".
  String get rango => switch (this) {
    NivelImc.bajoPeso => 'menos de 18.5',
    NivelImc.obesidad3 => '40 o más',
    _ => '${_txt(desde)} a ${_txt(hasta - 0.1)}',
  };

  static NivelImc de(double imc) =>
      NivelImc.values.firstWhere((n) => imc < n.hasta, orElse: () => obesidad3);
}

/// Nivel de un dato estimado (grasa o masa muscular) con su color.
class NivelEstimado {
  final String nombre;
  final Color color;
  const NivelEstimado(this.nombre, this.color);
}

/// IMC, peso ideal y masa muscular de un socio a partir de su peso, altura y,
/// si se conocen, su edad y sexo.
///
/// - IMC = peso / altura² (OMS).
/// - Peso ideal: el que da un IMC de 22 (mitad del rango saludable 18.5–24.9).
/// - Grasa corporal: fórmula de Deurenberg (IMC, edad y sexo). Es una
///   estimación: en alguien muy musculoso sale más alta de lo real.
/// - Índice de masa muscular: masa libre de grasa / altura² (FFMI).
class ComposicionCorporal {
  final double pesoKg;
  final double alturaCm;
  final int? edad;

  /// 'M' o 'F'.
  final String? sexo;

  const ComposicionCorporal({
    required this.pesoKg,
    required this.alturaCm,
    this.edad,
    this.sexo,
  });

  /// Null si falta el peso o la altura (o no son válidos).
  static ComposicionCorporal? calcular({
    double? pesoKg,
    double? alturaCm,
    int? edad,
    String? sexo,
  }) {
    if (pesoKg == null || alturaCm == null || pesoKg <= 0 || alturaCm < 50) {
      return null;
    }
    return ComposicionCorporal(
      pesoKg: pesoKg,
      alturaCm: alturaCm,
      edad: edad,
      sexo: sexo,
    );
  }

  static const imcIdeal = 22.0;
  static const imcMinSaludable = 18.5;
  static const imcMaxSaludable = 24.9;

  double get _altura2 => (alturaCm / 100) * (alturaCm / 100);

  /// Redondeado a un decimal.
  double get imc => _redondear(imcDe(pesoKg));

  double imcDe(double peso) => peso / _altura2;

  NivelImc get nivel => NivelImc.de(imc);

  double get pesoIdeal => _redondear(imcIdeal * _altura2);
  double get pesoMinSaludable => _redondear(imcMinSaludable * _altura2);
  double get pesoMaxSaludable => _redondear(imcMaxSaludable * _altura2);

  /// Kilos que faltan para entrar al rango saludable: positivo = debe subir,
  /// negativo = debe bajar, 0 = ya está en el rango.
  double get kilosParaSaludable {
    if (pesoKg < pesoMinSaludable) return _redondear(pesoMinSaludable - pesoKg);
    if (pesoKg > pesoMaxSaludable) return _redondear(pesoMaxSaludable - pesoKg);
    return 0;
  }

  /// Frase corta y clara de qué hacer con el peso. [propio] = le habla al
  /// socio ("te faltan"); si no, habla del socio ("le faltan").
  String consejoPeso({bool propio = true}) {
    final k = kilosParaSaludable;
    if (k == 0) {
      return propio
          ? 'Estás en tu peso saludable'
          : 'Está en su peso saludable';
    }
    final a = propio ? 'Te' : 'Le';
    if (k > 0) return '$a faltan ${_txt(k)} kg para un peso saludable';
    return '$a sobran ${_txt(-k)} kg para un peso saludable';
  }

  /// Sin edad y sexo no se puede estimar la grasa ni la masa muscular.
  bool get puedeEstimarMusculo => edad != null && sexo != null;

  double? get grasaPct {
    final e = edad, s = sexo;
    if (e == null || s == null) return null;
    final v = 1.2 * imcDe(pesoKg) + 0.23 * e - 10.8 * (s == 'M' ? 1 : 0) - 5.4;
    return _redondear(v.clamp(3.0, 60.0));
  }

  double? get masaGrasaKg {
    final g = grasaPct;
    return g == null ? null : _redondear(pesoKg * g / 100);
  }

  /// Masa libre de grasa (músculo, huesos, órganos y agua).
  double? get masaMagraKg {
    final g = grasaPct;
    return g == null ? null : _redondear(pesoKg * (1 - g / 100));
  }

  /// Índice de masa muscular (masa libre de grasa / altura²).
  double? get indiceMasaMuscular {
    final m = masaMagraKg;
    return m == null ? null : _redondear(m / _altura2);
  }

  NivelEstimado? get nivelGrasa {
    final g = grasaPct;
    if (g == null) return null;
    final hombre = sexo == 'M';
    if (g < (hombre ? 6 : 14)) {
      return const NivelEstimado('Muy baja', Color(0xFF2E7CF6));
    }
    if (g < (hombre ? 14 : 21)) {
      return const NivelEstimado('Atlética', Color(0xFF22A06B));
    }
    if (g < (hombre ? 18 : 25)) {
      return const NivelEstimado('En forma', Color(0xFF22A06B));
    }
    if (g < (hombre ? 25 : 32)) {
      return const NivelEstimado('Promedio', Color(0xFFF5A623));
    }
    return const NivelEstimado('Alta', Color(0xFFE5484D));
  }

  NivelEstimado? get nivelMusculo {
    final i = indiceMasaMuscular;
    if (i == null) return null;
    final hombre = sexo == 'M';
    if (i < (hombre ? 18 : 15)) {
      return const NivelEstimado('Bajo', Color(0xFFE5484D));
    }
    if (i < (hombre ? 20 : 17)) {
      return const NivelEstimado('Normal', Color(0xFFF5A623));
    }
    if (i < (hombre ? 22 : 19)) {
      return const NivelEstimado('Bueno', Color(0xFF22A06B));
    }
    if (i < (hombre ? 25 : 21.5)) {
      return const NivelEstimado('Muy bueno', Color(0xFF22A06B));
    }
    return const NivelEstimado('Excelente', Color(0xFF2E7CF6));
  }

  static double _redondear(double v) => (v * 10).round() / 10;
}

String _txt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
