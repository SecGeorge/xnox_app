import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';

/// Puente con el servicio nativo `YapeListenerService` (Android).
///
/// El servicio nativo corre en segundo plano y reenvía las notificaciones de
/// pago al backend. Esta clase solo: (1) sincroniza la configuración hacia el
/// lado nativo vía SharedPreferences, (2) consulta si el permiso de "Acceso a
/// notificaciones" está concedido y (3) abre la pantalla del sistema para
/// concederlo.
class LectorPagosChannel {
  LectorPagosChannel._();

  static const MethodChannel _canal =
      MethodChannel('com.example.xnox_app/lector_pagos');

  /// Escribe en SharedPreferences el endpoint al que el servicio nativo debe
  /// enviar los pagos. Lo deriva de [HttpService.RUTA_GLOBAL] para que dev/prod
  /// queden siempre sincronizados con el resto de la app.
  static Future<void> sincronizarConfig() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'lector_endpoint',
      '${HttpService.RUTA_GLOBAL}recibir_notificacion.php',
    );
  }

  /// `true` si el usuario ya concedió "Acceso a notificaciones" a la app.
  static Future<bool> estaActivo() async {
    try {
      return await _canal.invokeMethod<bool>('estaActivo') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre la pantalla del sistema de "Acceso a notificaciones" para que el
  /// usuario active el lector de XNOX.
  static Future<void> abrirAjustes() async {
    try {
      await _canal.invokeMethod('abrirAjustes');
    } on PlatformException {
      // Silencioso: la pantalla de activación ya muestra el estado al volver.
    }
  }
}
