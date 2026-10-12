import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:xnox_app/core/tema/app_tema.dart';

/// Alarma del fin del descanso entre series cuando el socio NO está mirando la
/// app: pantalla bloqueada, app en segundo plano o cerrada.
///
/// Al arrancar el descanso se programa una notificación del sistema a la hora
/// exacta en que termina. Sale por el canal de ALARMA (suena aunque el teléfono
/// esté en silencio) y con la bandera *insistent* de Android, que repite el
/// sonido sin parar hasta que el socio toca "Silenciar", abre la notificación
/// o la descarta. Con la app abierta la alarma se cancela y suena la de la app.
class ServicioAlarmaDescanso {
  static final ServicioAlarmaDescanso _instancia = ServicioAlarmaDescanso._();
  factory ServicioAlarmaDescanso() => _instancia;
  ServicioAlarmaDescanso._();

  /// Un solo descanso a la vez: programar uno nuevo reemplaza al anterior.
  static const int _id = 7301;

  /// Canal propio. Android congela sonido e importancia de un canal al crearlo:
  /// para cambiarlos hay que estrenar otro id (sufijo `_v1` → `_v2`).
  static const AndroidNotificationChannel _canal = AndroidNotificationChannel(
    'xnox_descanso_v1',
    'Fin del descanso',
    description: 'Avisa que terminó el descanso entre series.',
    importance: Importance.max,
    playSound: true,
    sound: RawResourceAndroidNotificationSound('descanso_fin'),
    enableVibration: true,
    audioAttributesUsage: AudioAttributesUsage.alarm,
  );

  /// Repite sonido y vibración hasta que se atiende (Notification.FLAG_INSISTENT).
  static const int _flagInsistent = 4;

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _preparando;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Arranca el plugin y crea el canal. No depende de que Firebase haya
  /// arrancado bien: el temporizador funciona aunque falten los avisos push.
  Future<void> _preparar() => _preparando ??= () async {
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    await _android?.createNotificationChannel(_canal);
  }();

  /// Programa la alarma para dentro de [segundos]. Devuelve false si Android
  /// no deja programarla a la hora exacta (falta el permiso de "Alarmas y
  /// recordatorios"); en ese caso igual queda programada, pero Android puede
  /// retrasarla unos minutos.
  Future<bool> programar(int segundos) async {
    if (!Platform.isAndroid) return true;
    try {
      await _preparar();
      final exacta = await puedeSerExacta();
      await _plugin.zonedSchedule(
        id: _id,
        title: '¡Descanso terminado!',
        body: 'Toca para volver: es hora de la siguiente serie.',
        scheduledDate: tz.TZDateTime.now(tz.UTC)
            .add(Duration(seconds: segundos)),
        androidScheduleMode: exacta
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            _canal.id,
            _canal.name,
            channelDescription: _canal.description,
            importance: Importance.max,
            priority: Priority.max,
            category: AndroidNotificationCategory.alarm,
            icon: '@drawable/ic_notification',
            color: AppColores.primario,
            playSound: true,
            sound: _canal.sound,
            audioAttributesUsage: AudioAttributesUsage.alarm,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 600, 400, 600]),
            additionalFlags: Int32List.fromList([_flagInsistent]),
            visibility: NotificationVisibility.public,
            autoCancel: true,
            actions: const [
              // cancelNotification la quita en nativo: calla el sonido sin
              // tener que despertar la app.
              AndroidNotificationAction(
                'silenciar',
                'Silenciar',
                cancelNotification: true,
              ),
            ],
          ),
        ),
      );
      return exacta;
    } catch (e) {
      debugPrint('[DESCANSO] no se pudo programar la alarma: $e');
      return true; // nada que pedirle al socio: queda el aviso de la app
    }
  }

  /// Quita la alarma: la programada que aún no sonó o la que está sonando.
  Future<void> cancelar() async {
    if (!Platform.isAndroid) return;
    try {
      await _preparar();
      await _plugin.cancel(id: _id);
    } catch (e) {
      debugPrint('[DESCANSO] no se pudo cancelar la alarma: $e');
    }
  }

  /// True si la notificación de fin de descanso está en la barra (sonando).
  Future<bool> estaSonando() async {
    if (!Platform.isAndroid) return false;
    try {
      await _preparar();
      final activas = await _android?.getActiveNotifications() ?? const [];
      return activas.any((n) => n.id == _id);
    } catch (_) {
      return false;
    }
  }

  /// Android 12+ exige permiso para alarmas exactas (en 14+ viene negado).
  Future<bool> puedeSerExacta() async {
    if (!Platform.isAndroid) return true;
    try {
      await _preparar();
      return await _android?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  /// Abre el ajuste del sistema "Alarmas y recordatorios" de la app.
  Future<void> pedirPermisoExacta() async {
    try {
      await _preparar();
      await _android?.requestExactAlarmsPermission();
    } catch (e) {
      debugPrint('[DESCANSO] no se pudo pedir el permiso: $e');
    }
  }
}
