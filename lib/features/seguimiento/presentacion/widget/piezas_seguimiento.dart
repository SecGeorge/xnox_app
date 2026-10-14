import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/foto_sesion.dart';

/// Miniatura con la foto del grupo muscular de un ejercicio.
class FotoEjercicio extends StatelessWidget {
  final String nombre;
  final double tamano;

  const FotoEjercicio(this.nombre, {super.key, this.tamano = 46});

  @override
  Widget build(BuildContext context) {
    final foto = FotoSesion.deEjercicio(nombre);
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      child: Image.asset(
        foto.ruta,
        width: tamano,
        height: tamano,
        fit: BoxFit.cover,
        alignment: foto.alineacion,
      ),
    );
  }
}

/// Píldora de cambio ("+5 kg", "−2 cm"): verde si es bueno, roja si no y
/// gris si da igual.
class ChipCambio extends StatelessWidget {
  final String texto;
  final bool? bueno;
  final bool sube;

  const ChipCambio({
    super.key,
    required this.texto,
    required this.bueno,
    required this.sube,
  });

  @override
  Widget build(BuildContext context) {
    final color = bueno == null
        ? AppColores.textoSecundario
        : bueno!
        ? AppColores.activo
        : AppColores.moroso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            sube ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 15,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Dato centrado (valor grande, título chico) para filas de 3.
class DatoCentrado extends StatelessWidget {
  final String titulo;
  final String valor;
  final bool destacar;

  const DatoCentrado(
    this.titulo,
    this.valor, {
    super.key,
    this.destacar = false,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            valor,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w800,
              color: destacar ? AppColores.primario : AppColores.textoPrincipal,
            ),
          ),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// "Hoy", "Ayer", "Hace 3 días" o la fecha.
String haceCuanto(DateTime f) {
  final h = DateTime.now();
  final dias = DateTime(
    h.year,
    h.month,
    h.day,
  ).difference(DateTime(f.year, f.month, f.day)).inDays;
  if (dias <= 0) return 'Hoy';
  if (dias == 1) return 'Ayer';
  if (dias < 7) return 'Hace $dias días';
  return DateFormat("d 'de' MMMM", 'es').format(f);
}

/// "Lunes 12 de octubre" (con mayúscula inicial).
String fechaLarga(DateTime f) {
  final t = DateFormat("EEEE d 'de' MMMM", 'es').format(f);
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
}
