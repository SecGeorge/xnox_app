import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/firebase_options.dart';

/// Atiende los mensajes que llegan con la app en segundo plano o cerrada.
///
/// FCM lo ejecuta en un isolate aparte, así que tiene que ser una función de
/// nivel superior (no un método) y volver a inicializar Firebase: ese isolate
/// no comparte nada con el de la app. El `@pragma` evita que el compilador la
/// elimine al construir en release, porque nadie la llama desde Dart.
@pragma('vm:entry-point')
Future<void> _mensajeEnSegundoPlano(RemoteMessage mensaje) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Android ya pinta solo la notificación cuando el mensaje trae bloque
  // `notification`; aquí únicamente dejamos rastro para depurar.
  debugPrint('[FCM] mensaje en segundo plano: ${mensaje.messageId}');
}

/// Punto único de contacto con Firebase Cloud Messaging.
///
/// Cubre el arranque (permiso, canal de Android, token) y el registro del
/// token en el backend, que es lo que permite al servidor saber a qué teléfono
/// mandar cada aviso. El reparto por público no se hace aquí: el backend lo
/// resuelve con el `tipo_envio` de cada notificación y la tabla
/// `dispositivos_fcm`.
class ServicioNotificaciones {
  static final ServicioNotificaciones _instancia = ServicioNotificaciones._();
  factory ServicioNotificaciones() => _instancia;
  ServicioNotificaciones._();

  /// Canal de Android por el que salen los avisos. Debe coincidir con el
  /// `default_notification_channel_id` declarado en el AndroidManifest: es el
  /// que usa FCM cuando llega un mensaje y la app no está abierta.
  ///
  /// OJO al cambiar esto: Android congela los ajustes de un canal cuando se
  /// crea, y a partir de ahí manda el usuario. Modificar sonido o vibración
  /// aquí NO afecta a quien ya tenga la app instalada; hay que estrenar un
  /// identificador (por eso el sufijo `_v2`) o desinstalar la app.
  static const AndroidNotificationChannel canal = AndroidNotificationChannel(
    'xnox_avisos_v2',
    'Avisos XNOX',
    description: 'Membresías, pagos y anuncios del gimnasio.',
    importance: Importance.high,
    playSound: true,
    enableVibration: true,
  );

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  String? _token;

  /// Token del dispositivo en FCM. Es la dirección a la que el backend enviará
  /// las notificaciones dirigidas a este teléfono en concreto.
  String? get token => _token;

  bool _iniciado = false;

  /// Prepara Firebase y deja el token disponible.
  ///
  /// Se lanza desde `main()` SIN esperarlo: `_pedirPermiso()` no vuelve hasta
  /// que el usuario responde el diálogo del sistema, y si se aguardara antes
  /// de `runApp` la app se quedaría en blanco mientras tanto.
  ///
  /// Nunca propaga el error: las notificaciones son un extra y un fallo aquí
  /// (dispositivo sin Google Play, proyecto mal configurado) no debe impedir
  /// que la app arranque.
  Future<void> init() async {
    if (_iniciado) return;

    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      FirebaseMessaging.onBackgroundMessage(_mensajeEnSegundoPlano);

      await _prepararCanal();
      await _pedirPermiso();
      await _obtenerToken();
      // Si ya había sesión abierta no se pasa por el login, así que el token
      // se refresca aquí (no hace nada si nadie ha iniciado sesión).
      await registrarEnBackend();

      // Con la app abierta, Android NO muestra nada por su cuenta: el mensaje
      // llega a `onMessage` y somos nosotros quienes lo pintamos.
      FirebaseMessaging.onMessage.listen(_mostrarEnPrimerPlano);

      _iniciado = true;
    } catch (e) {
      debugPrint('[FCM] no se pudo inicializar: $e');
    }
  }

  /// Crea el canal en Android y arranca el plugin de notificaciones locales.
  Future<void> _prepararCanal() async {
    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(canal);
  }

  /// Pide el permiso de notificaciones. En Android 13+ es obligatorio y sin él
  /// no llega nada, sin ningún error visible.
  Future<void> _pedirPermiso() async {
    final ajustes = await FirebaseMessaging.instance.requestPermission();
    debugPrint('[FCM] permiso: ${ajustes.authorizationStatus}');
  }

  /// Obtiene el token y se queda escuchando su rotación: Firebase lo cambia
  /// solo (reinstalación, limpieza de datos, restauración), y si el backend se
  /// queda con el viejo el dispositivo deja de recibir avisos en silencio.
  Future<void> _obtenerToken() async {
    try {
      _token = await FirebaseMessaging.instance.getToken();
      debugPrint('[FCM] token: $_token');
    } catch (e) {
      // Sin Google Play Services (emuladores sin Play Store) no hay token.
      debugPrint('[FCM] no se pudo obtener el token: $e');
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((nuevo) {
      _token = nuevo;
      debugPrint('[FCM] token renovado: $nuevo');
      registrarEnBackend();
    });
  }

  /// Envía el token al backend de la empresa activa junto con el dueño de la
  /// sesión, para que el servidor sepa a qué teléfono mandar cada aviso.
  ///
  /// Se llama tras iniciar sesión y cada vez que Firebase rota el token. Es
  /// idempotente: el backend hace upsert por token.
  Future<void> registrarEnBackend() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      // Sin sesión no hay a quién asociar el token; se registrará al entrar.
      final idUsuario = prefs.getString('idUsuario');
      if (idUsuario == null || idUsuario.isEmpty) return;

      await HttpService().registrar({
        'metodo': 'registrar',
        'token': token,
        'usuario_id': idUsuario,
        'miembro_id': prefs.getString('miembroId') ?? '',
        'sucursal_id': prefs.getString('idSucursal') ?? '',
        'tipo_usuario': prefs.getString('tipoUsuario') ?? '',
        'plataforma': Platform.isIOS ? 'ios' : 'android',
      }, 'dispositivos.php');
    } catch (e) {
      // Un fallo aquí solo significa que el teléfono no recibirá avisos hasta
      // el próximo arranque; no debe interrumpir el uso de la app.
      debugPrint('[FCM] no se pudo registrar el token: $e');
    }
  }

  /// Da de baja el token al cerrar sesión, para que el teléfono no siga
  /// recibiendo avisos de una cuenta de la que el usuario ya salió.
  Future<void> darDeBajaEnBackend() async {
    final token = _token;
    if (token == null || token.isEmpty) return;

    try {
      await HttpService().registrar({
        'metodo': 'baja',
        'token': token,
      }, 'dispositivos.php');
    } catch (e) {
      debugPrint('[FCM] no se pudo dar de baja el token: $e');
    }
  }

  /// Pinta la notificación cuando la app está abierta.
  Future<void> _mostrarEnPrimerPlano(RemoteMessage mensaje) async {
    final aviso = mensaje.notification;
    if (aviso == null) return;

    await _local.show(
      id: mensaje.hashCode,
      title: aviso.title,
      body: aviso.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          canal.id,
          canal.name,
          channelDescription: canal.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
          playSound: true,
          enableVibration: true,
        ),
      ),
    );
  }
}
