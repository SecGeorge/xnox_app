import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/pago_yape/dominio/config_pago_yape.dart';

/// Resultado de intentar validar un pago por Yape con el código de seguridad.
class ResultadoPagoYape {
  final bool ok;
  final String mensaje;

  const ResultadoPagoYape({required this.ok, required this.mensaje});
}

/// Acceso a la configuración de cobro por Yape del negocio y al reporte de
/// pago de un pedido por parte del cliente.
class RepositorioPagoYape {
  final HttpService _httpService;

  RepositorioPagoYape([HttpService? http]) : _httpService = http ?? HttpService();

  /// Convierte la ruta relativa que guarda el backend (ej. "imagenes/yape/x.png")
  /// en una URL absoluta para `Image.network`.
  String? _url(dynamic ruta) {
    final r = ruta?.toString().trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    final limpia = r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '');
    return '${HttpService.RUTA_GLOBAL}$limpia';
  }

  /// Obtiene el número, titular y QR de Yape del negocio (tabla `ajustes`).
  Future<ConfigPagoYape> obtenerConfig() async {
    final resp = await _httpService.obtenerConDatos(
      {'metodo': 'obtener'},
      'ajustes.php',
    );
    if (resp is! Map) {
      return const ConfigPagoYape(numero: '', titular: '');
    }
    final json = Map<String, dynamic>.from(resp);
    return ConfigPagoYape(
      numero: json['yape_numero']?.toString() ?? '',
      titular: json['yape_titular']?.toString() ?? '',
      qrUrl: _url(json['yape_qr']),
    );
  }

  /// El cliente reporta que ya pagó su pedido por Yape. Devuelve `null` si todo
  /// salió bien, o un mensaje de error legible.
  Future<String?> reportarPagoPedido(int pedidoId) async {
    final resp = await _httpService.registrar(
      {'metodo': 'reportar_pago', 'pedido_id': pedidoId},
      'pedidos.php',
    );
    if (resp is Map) {
      if (resp['success'] == true) return null;
      return resp['mensaje']?.toString() ??
          resp['error']?.toString() ??
          'No se pudo reportar el pago';
    }
    return 'No se pudo reportar el pago';
  }

  /// Valida el código de seguridad del pago Yape de un PEDIDO. Si el pago
  /// existe y es igual o mayor al total, el pedido se confirma automáticamente.
  Future<ResultadoPagoYape> validarPagoPedido(int pedidoId, String codigo) async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = int.tryParse(prefs.getString('idUsuario') ?? '');
    final resp = await _httpService.registrar(
      {
        'metodo': 'validar_pago_yape',
        'pedido_id': pedidoId,
        'codigo': codigo.trim(),
        'usuario_creacion': usuarioId,
      },
      'pedidos.php',
    );
    return _interpretar(resp);
  }

  /// Valida el código de seguridad del pago Yape de la deuda de MEMBRESÍA. Si el
  /// pago existe y cubre la deuda, se registra el pago del contrato (Yape).
  Future<ResultadoPagoYape> validarPagoMembresia(
    int contratoId,
    double monto,
    String codigo,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = int.tryParse(prefs.getString('idUsuario') ?? '');
    final sucursalId = int.tryParse(prefs.getString('idSucursal') ?? '');
    final resp = await _httpService.registrar(
      {
        'metodo': 'validar_pago_yape',
        'contrato_id': contratoId,
        'monto': monto,
        'sucursal_id': sucursalId,
        'usuario_creacion': usuarioId,
        'codigo': codigo.trim(),
      },
      'pagos.php',
    );
    return _interpretar(resp);
  }

  /// Traduce la respuesta del backend a un [ResultadoPagoYape].
  ResultadoPagoYape _interpretar(dynamic resp) {
    if (resp is Map) {
      if (resp['success'] == true) {
        return ResultadoPagoYape(
          ok: true,
          mensaje:
              resp['mensaje']?.toString() ?? '¡Pago verificado! Compra confirmada.',
        );
      }
      return ResultadoPagoYape(
        ok: false,
        mensaje: resp['mensaje']?.toString() ??
            resp['error']?.toString() ??
            'No se pudo verificar el pago',
      );
    }
    return const ResultadoPagoYape(
      ok: false,
      mensaje: 'No se pudo verificar el pago. Revisa tu conexión.',
    );
  }
}
