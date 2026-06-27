package com.example.xnox_app

import android.content.Intent
import android.provider.Settings
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val canal = "com.example.xnox_app/lector_pagos"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, canal)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    // ¿El usuario ya concedió "Acceso a notificaciones" a la app?
                    "estaActivo" -> {
                        val activos = NotificationManagerCompat
                            .getEnabledListenerPackages(this)
                        result.success(activos.contains(packageName))
                    }
                    // Abre la pantalla del sistema de "Acceso a notificaciones".
                    "abrirAjustes" -> {
                        startActivity(
                            Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
                        )
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
