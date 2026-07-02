import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/pago_yape/dominio/config_pago_yape.dart';

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
}
