import 'package:intl/intl.dart';

/// Filtros de selección de clientes para una campaña.
enum FiltroCampania {
  todos,
  conDeuda,
  venceHoy,
  venceManana,
  vence3,
  vence7,
  vencidos,
  sinContrato;

  String get etiqueta {
    switch (this) {
      case FiltroCampania.todos:
        return 'Todos';
      case FiltroCampania.conDeuda:
        return 'Con deuda';
      case FiltroCampania.venceHoy:
        return 'Vence hoy';
      case FiltroCampania.venceManana:
        return 'Vence mañana';
      case FiltroCampania.vence3:
        return 'Vence en 3 días';
      case FiltroCampania.vence7:
        return 'Vence en 7 días';
      case FiltroCampania.vencidos:
        return 'Vencidos (recuperar)';
      case FiltroCampania.sinContrato:
        return 'Sin contrato';
    }
  }
}

/// Cliente destinatario de una campaña de WhatsApp.
/// Incluye los datos necesarios para filtrar y para reemplazar variables.
class ClienteDestinatario {
  final int? id;
  final String nombre; // nombre completo
  final String telefono;
  final String membresia;
  final double debe;
  final int estadoMembresia; // 5=activo, 6=deudor, 7=vencido, 0=sin contrato
  final DateTime? fechaFin;
  final String matricula;

  ClienteDestinatario({
    this.id,
    required this.nombre,
    required this.telefono,
    required this.membresia,
    required this.debe,
    required this.estadoMembresia,
    this.fechaFin,
    required this.matricula,
  });

  factory ClienteDestinatario.fromJson(Map<String, dynamic> json) {
    final nombreCompleto = [
      json['nombre'],
      json['apellidoPaterno'],
      json['apellidoMaterno'],
    ]
        .where((e) => e != null && e.toString().trim().isNotEmpty)
        .map((e) => e.toString().trim())
        .join(' ')
        .trim();

    final membresia = json['membresia']?.toString().trim() ?? '';

    return ClienteDestinatario(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      nombre: nombreCompleto.isEmpty ? 'Sin nombre' : nombreCompleto,
      telefono: json['telefono']?.toString().trim() ?? '',
      membresia: (membresia.isEmpty || membresia == 'SIN CONTRATO') ? '' : membresia,
      debe: double.tryParse(json['debe']?.toString() ?? '0') ?? 0,
      estadoMembresia:
          int.tryParse(json['estado_membresia']?.toString() ?? '0') ?? 0,
      fechaFin: DateTime.tryParse(json['fecha_fin']?.toString() ?? ''),
      matricula: json['matricula']?.toString() ?? '',
    );
  }

  /// Teléfono solo dígitos, anteponiendo 51 (Perú) si tiene 9 dígitos.
  String get telefonoWhatsApp {
    var tel = telefono.replaceAll(RegExp(r'\D'), '');
    if (tel.length == 9) tel = '51$tel';
    return tel;
  }

  bool get tieneTelefono => telefono.replaceAll(RegExp(r'\D'), '').isNotEmpty;

  String get iniciales {
    final n = nombre.trim();
    return n.isEmpty ? '?' : n[0].toUpperCase();
  }

  /// Días para vencer respecto a [hoy] (null si no hay fecha).
  int? diasParaVencer(DateTime hoy) {
    if (fechaFin == null) return null;
    final f = DateTime(fechaFin!.year, fechaFin!.month, fechaFin!.day);
    return f.difference(hoy).inDays;
  }

  /// ¿Coincide con el filtro indicado?
  bool coincideFiltro(FiltroCampania filtro, DateTime hoy) {
    final dias = diasParaVencer(hoy);
    switch (filtro) {
      case FiltroCampania.conDeuda:
        return debe > 0;
      case FiltroCampania.venceHoy:
        return dias == 0;
      case FiltroCampania.venceManana:
        return dias == 1;
      case FiltroCampania.vence3:
        return dias != null && dias >= 0 && dias <= 3;
      case FiltroCampania.vence7:
        return dias != null && dias >= 0 && dias <= 7;
      case FiltroCampania.vencidos:
        return estadoMembresia == 7;
      case FiltroCampania.sinContrato:
        return estadoMembresia == 0;
      case FiltroCampania.todos:
        return true;
    }
  }

  /// Reemplaza las variables de la plantilla con los datos de este cliente.
  String generarMensaje(String base) {
    final fecha = fechaFin != null ? DateFormat('dd/MM/yyyy').format(fechaFin!) : '';
    return base
        .replaceAll('{nombre}', nombre)
        .replaceAll('{membresia}', membresia)
        .replaceAll('{deuda}', debe.toStringAsFixed(2))
        .replaceAll('{fecha_vencimiento}', fecha)
        .replaceAll('{matricula}', matricula);
  }
}
