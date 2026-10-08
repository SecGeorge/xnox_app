import 'package:flutter/material.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';

/// Hacia dónde es "mejor" que se mueva una medida, para pintar el cambio en
/// verde o en rojo. El peso corporal depende del objetivo de cada socio.
enum TendenciaMedida { subir, bajar, neutral }

/// Zona del cuerpo que el socio puede medir, con su foto de referencia.
class ZonaMedida {
  /// Clave guardada en SQLite (no cambiarla: rompería el historial).
  final String clave;
  final String nombre;
  final String unidad;
  final IconData icono;
  final String foto;
  final Alignment alineacion;
  final TendenciaMedida tendencia;

  const ZonaMedida({
    required this.clave,
    required this.nombre,
    required this.foto,
    this.unidad = 'cm',
    this.icono = Icons.straighten_rounded,
    this.alineacion = Alignment.center,
    this.tendencia = TendenciaMedida.subir,
  });

  static const _fotos = 'assets/imagenes/medidas';

  /// Cada zona con una foto donde se vea ESE músculo.
  static const List<ZonaMedida> todas = [
    ZonaMedida(
      clave: 'peso',
      nombre: 'Peso corporal',
      unidad: 'kg',
      icono: Icons.monitor_weight_rounded,
      foto: '$_fotos/cuerpo.jpg',
      alineacion: Alignment(0, -0.35),
      tendencia: TendenciaMedida.neutral,
    ),
    ZonaMedida(
      clave: 'hombros',
      nombre: 'Hombros',
      foto: FotosApp.hombros,
      alineacion: Alignment(0, -0.3),
    ),
    ZonaMedida(clave: 'pecho', nombre: 'Pecho', foto: FotosApp.pecho),
    ZonaMedida(
      clave: 'espalda',
      nombre: 'Espalda',
      foto: FotosApp.espalda,
      alineacion: Alignment(0, -0.4),
    ),
    ZonaMedida(
      clave: 'biceps_der',
      nombre: 'Bíceps derecho',
      foto: FotosApp.brazos,
      alineacion: Alignment(0.3, 0),
    ),
    ZonaMedida(
      clave: 'biceps_izq',
      nombre: 'Bíceps izquierdo',
      foto: FotosApp.brazos,
      alineacion: Alignment(0.3, 0),
    ),
    ZonaMedida(
      clave: 'antebrazo',
      nombre: 'Antebrazo',
      foto: '$_fotos/antebrazo.jpg',
      alineacion: Alignment(0.4, 0.2),
    ),
    ZonaMedida(
      clave: 'cintura',
      nombre: 'Cintura',
      foto: FotosApp.core,
      tendencia: TendenciaMedida.bajar,
    ),
    ZonaMedida(
      clave: 'abdomen',
      nombre: 'Abdomen',
      foto: FotosApp.core,
      alineacion: Alignment(0.3, 0),
      tendencia: TendenciaMedida.bajar,
    ),
    ZonaMedida(clave: 'cadera', nombre: 'Glúteos', foto: FotosApp.gluteos),
    // La clave sigue siendo 'muslo' para no perder el historial ya guardado.
    ZonaMedida(
      clave: 'muslo',
      nombre: 'Cuádriceps',
      foto: '$_fotos/cuadriceps.jpg',
      alineacion: Alignment(0, 0.45),
    ),
    ZonaMedida(
      clave: 'pantorrilla',
      nombre: 'Pantorrilla',
      foto: '$_fotos/pantorrilla.jpg',
      alineacion: Alignment(0, 0.1),
    ),
  ];
}

/// Un registro de medida: cuánto midió una zona en una fecha.
class Medida {
  final int id;
  final String zona;
  final DateTime fecha;
  final double valor;

  const Medida({
    required this.id,
    required this.zona,
    required this.fecha,
    required this.valor,
  });

  factory Medida.desdeMapa(Map<String, Object?> m) => Medida(
    id: m['id'] as int,
    zona: m['zona'] as String,
    fecha: DateTime.parse(m['fecha'] as String),
    valor: (m['valor'] as num).toDouble(),
  );
}

/// 38.0 -> "38", 38.5 -> "38.5".
String numeroMedida(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);
