import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';

/// Provee la membresía (contrato actual) del cliente desde el backend.
class ControladorMembresia {
  final HttpService _httpService = HttpService();

  Future<MembresiaCliente?> obtenerMembresia() async {
    final prefs = await SharedPreferences.getInstance();
    final miembroId = int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;
    final codigo = prefs.getString('usuarioNombre') ?? '';

    if (miembroId == 0) return null;

    Map<String, dynamic>? contrato;
    try {
      final resp = await _httpService.obtenerConDatos(
        {'metodo': 'obtener_contrato_por_miembro_id', 'miembro_id': miembroId},
        'contratos.php',
      );
      if (resp is List && resp.isNotEmpty) {
        contrato = Map<String, dynamic>.from(resp.first as Map);
      }
    } catch (_) {
      // Sin red: devolvemos un mínimo para que el QR siga funcionando.
    }

    final qr = codigo.isEmpty ? 'CLI-$miembroId' : codigo;

    if (contrato == null) {
      // Cliente sin contrato: igual mostramos su QR de ingreso.
      return MembresiaCliente(
        nombre: '',
        plan: 'Sin membresía activa',
        estado: EstadoMiembro.vencido,
        fechaInicio: DateTime.now(),
        fechaVencimiento: DateTime.now(),
        saldoPendiente: 0,
        codigoQr: qr,
      );
    }

    final deuda = double.tryParse(contrato['deuda']?.toString() ?? '0') ?? 0;
    final est = int.tryParse(contrato['estado']?.toString() ?? '0') ?? 0;

    return MembresiaCliente(
      nombre: contrato['nombre_completo']?.toString() ?? '',
      plan: contrato['membresia']?.toString() ?? 'Sin membresía',
      estado: _estado(est, deuda),
      fechaInicio:
          DateTime.tryParse(contrato['fecha_inicio']?.toString() ?? '') ??
              DateTime.now(),
      fechaVencimiento:
          DateTime.tryParse(contrato['fecha_fin']?.toString() ?? '') ??
              DateTime.now(),
      saldoPendiente: deuda,
      codigoQr: qr,
    );
  }

  /// Misma lógica de estado que el panel: 5 activo, 6 deudor, 7 vencido/moroso.
  EstadoMiembro _estado(int est, double deuda) {
    if (est == 5) return EstadoMiembro.activo;
    if (est == 6) return EstadoMiembro.deudor;
    if (est == 7) return deuda > 0 ? EstadoMiembro.moroso : EstadoMiembro.vencido;
    return EstadoMiembro.vencido;
  }
}
