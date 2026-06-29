import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Tipos/categorías de plantilla de mensaje (debe coincidir con el backend).
const List<String> kTiposPlantilla = [
  'Recordatorio',
  'Promoción',
  'Bienvenida',
  'Otro',
];

/// Variables que se reemplazan por los datos de cada cliente al enviar.
class VariablePlantilla {
  final String etiqueta;
  final String valor;
  const VariablePlantilla(this.etiqueta, this.valor);
}

const List<VariablePlantilla> kVariablesPlantilla = [
  VariablePlantilla('Nombre', '{nombre}'),
  VariablePlantilla('Membresía', '{membresia}'),
  VariablePlantilla('Deuda', '{deuda}'),
  VariablePlantilla('Vencimiento', '{fecha_vencimiento}'),
  VariablePlantilla('Matrícula', '{matricula}'),
];

/// Color de cada tipo (paleta del sistema).
Color colorTipoPlantilla(String tipo) {
  switch (tipo) {
    case 'Promoción':
      return AppColores.acento;
    case 'Bienvenida':
      return AppColores.morado;
    case 'Otro':
      return AppColores.vencido;
    default:
      return AppColores.primario; // Recordatorio
  }
}

class PlantillaMensaje {
  final int? id;
  final String nombre;
  final String contenido;
  final String tipo;

  PlantillaMensaje({
    this.id,
    required this.nombre,
    required this.contenido,
    this.tipo = 'Recordatorio',
  });

  factory PlantillaMensaje.fromJson(Map<String, dynamic> json) {
    final tipo = json['tipo']?.toString() ?? '';
    return PlantillaMensaje(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nombre: json['nombre']?.toString() ?? '',
      contenido: json['contenido']?.toString() ?? '',
      tipo: tipo.isEmpty ? 'Recordatorio' : tipo,
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'nombre': nombre,
        'contenido': contenido,
        'tipo': tipo,
      };

  PlantillaMensaje copyWith({
    int? id,
    String? nombre,
    String? contenido,
    String? tipo,
  }) {
    return PlantillaMensaje(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      contenido: contenido ?? this.contenido,
      tipo: tipo ?? this.tipo,
    );
  }
}
