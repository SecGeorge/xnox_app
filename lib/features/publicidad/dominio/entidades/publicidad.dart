import 'package:flutter/widgets.dart';

class Publicidad {
  final int? id;
  final String titulo;
  final String descripcion;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String? imagenUrl;

  /// Posición del encuadre elegida por el admin, en formato "ax,ay" con valores
  /// de -1 a 1 (equivale a un [Alignment] de Flutter). Indica qué parte de la
  /// imagen COMPLETA se muestra en el marco de la tarjeta. La imagen no se
  /// recorta: solo se guarda esta posición para mostrar la parte elegida.
  final String encuadre;

  Publicidad({
    this.id,
    required this.titulo,
    required this.descripcion,
    required this.fechaInicio,
    required this.fechaFin,
    this.imagenUrl,
    this.encuadre = '0,0',
  });

  /// Convierte el string "ax,ay" en un [Alignment] para pintar la imagen.
  Alignment get alineacion => alineacionDesde(encuadre);

  /// Parsea un texto "ax,ay" (-1..1) a [Alignment]. Ante cualquier valor
  /// inválido cae a [Alignment.center].
  static Alignment alineacionDesde(String? texto) {
    if (texto == null || texto.trim().isEmpty) return Alignment.center;
    final partes = texto.split(',');
    if (partes.length != 2) return Alignment.center;
    final x = double.tryParse(partes[0].trim());
    final y = double.tryParse(partes[1].trim());
    if (x == null || y == null) return Alignment.center;
    return Alignment(x.clamp(-1.0, 1.0), y.clamp(-1.0, 1.0));
  }

  factory Publicidad.fromJson(Map<String, dynamic> json) {
    return Publicidad(
      id: json['id'] != null ? int.parse(json['id'].toString()) : null,
      titulo: json['titulo'] ?? '',
      descripcion: json['descripcion'] ?? '',
      fechaInicio: DateTime.parse(json['fecha_inicio'] ?? DateTime.now().toIso8601String()),
      fechaFin: DateTime.parse(json['fecha_fin'] ?? DateTime.now().toIso8601String()),
      imagenUrl: json['imagen_url'],
      encuadre: (json['encuadre']?.toString().isNotEmpty ?? false) ? json['encuadre'].toString() : '0,0',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'titulo': titulo,
      'descripcion': descripcion,
      'encuadre': encuadre,
      'fecha_inicio': fechaInicio.toIso8601String().split('T')[0],
      'fecha_fin': fechaFin.toIso8601String().split('T')[0],
    };
  }
}
