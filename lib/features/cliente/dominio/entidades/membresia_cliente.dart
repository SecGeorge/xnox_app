import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';

/// Membresía del cliente (socio) que ve su propia información.
class MembresiaCliente {
  final String nombre;
  final String plan;
  final EstadoMiembro estado;
  final DateTime fechaInicio;
  final DateTime fechaVencimiento;
  final double saldoPendiente;

  /// Código que se codifica en el QR de ingreso.
  final String codigoQr;

  MembresiaCliente({
    required this.nombre,
    required this.plan,
    required this.estado,
    required this.fechaInicio,
    required this.fechaVencimiento,
    required this.saldoPendiente,
    required this.codigoQr,
  });

  /// Días restantes hasta el vencimiento (negativo si ya venció).
  int get diasRestantes {
    final hoy = DateTime.now();
    final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
    return fechaVencimiento.difference(hoySinHora).inDays;
  }

  bool get tieneDeuda => saldoPendiente > 0;

  /// Datos de prueba para ver el diseño antes de conectar la base de datos.
  factory MembresiaCliente.demo() {
    final hoy = DateTime.now();
    return MembresiaCliente(
      nombre: 'Carlos Ramírez',
      plan: 'Premium Anual',
      estado: EstadoMiembro.activo,
      fechaInicio: DateTime(hoy.year, hoy.month - 2, 5),
      fechaVencimiento: hoy.add(const Duration(days: 18)),
      saldoPendiente: 0,
      codigoQr: 'XNOX-CLI-000123',
    );
  }
}
