package com.example.xnox_app

import android.app.Notification
import android.content.Context
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.nio.charset.StandardCharsets

/**
 * Servicio en segundo plano que escucha las notificaciones del sistema y, cuando
 * detecta un pago entrante de Yape/Plin/banca, lo reenvía al backend de XNOX.
 *
 * El servicio sigue vivo aunque la app Flutter esté cerrada: lee su configuración
 * (endpoint y sucursal/usuario activos) directamente del SharedPreferences que
 * comparte con Flutter, de modo que dev/prod nunca quedan desincronizados.
 */
class YapeListenerService : NotificationListenerService() {

    private val TAG = "XNOX_YapeListener"

    // Paquetes de las apps de pago a vigilar. Se hace match por "contiene" para
    // tolerar variantes regionales del package. Yape real: com.bcp.innovacxion.yapeapp
    private val paquetesPago = listOf(
        "yape",            // Yape (BCP)
        "innovacxion",     // Yape (package real)
        "plin",            // Plin
        "interbank",       // Interbank / Plin
        "bcp",             // BCP
        "bbva",            // BBVA / Plin
        "scotiabank",      // Scotiabank / Plin
    )

    override fun onNotificationPosted(sbn: StatusBarNotification) {
        val packageName = sbn.packageName ?: return
        if (paquetesPago.none { packageName.lowercase().contains(it) }) return

        val extras = sbn.notification?.extras ?: return
        val title = extras.getCharSequence(Notification.EXTRA_TITLE)?.toString().orEmpty()
        val text = extras.getCharSequence(Notification.EXTRA_TEXT)?.toString().orEmpty()
        val bigText = extras.getCharSequence(Notification.EXTRA_BIG_TEXT)?.toString().orEmpty()
        // El cuerpo "grande" suele traer el monto completo; preferirlo si existe.
        val cuerpo = bigText.ifBlank { text }

        if (title.isBlank() && cuerpo.isBlank()) return

        Log.i(TAG, "Pago detectado de $packageName -> $title | $cuerpo")
        enviarAlBackend(packageName, title, cuerpo, sbn.postTime)
    }

    private fun enviarAlBackend(appName: String, title: String, text: String, postTime: Long) {
        val sp = applicationContext.getSharedPreferences(
            "FlutterSharedPreferences", Context.MODE_PRIVATE
        )
        // Flutter guarda las claves con el prefijo "flutter.".
        val endpoint = sp.getString("flutter.lector_endpoint", DEFAULT_URL) ?: DEFAULT_URL
        val sucursal = sp.getString("flutter.idSucursal", "").orEmpty()
        val usuario = sp.getString("flutter.idUsuario", "").orEmpty()

        Thread {
            var conn: HttpURLConnection? = null
            try {
                conn = (URL(endpoint).openConnection() as HttpURLConnection).apply {
                    requestMethod = "POST"
                    setRequestProperty("Content-Type", "application/json; charset=utf-8")
                    setRequestProperty("Accept", "application/json")
                    connectTimeout = 10_000
                    readTimeout = 10_000
                    doOutput = true
                }

                val payload = JSONObject().apply {
                    put("metodo", "procesar_push")
                    put("appName", appName)
                    put("title", title)
                    put("text", text)
                    put("sucursal_id", sucursal)
                    put("idUsuario", usuario)
                    put("timestamp", postTime)
                }

                conn.outputStream.use { os ->
                    os.write(payload.toString().toByteArray(StandardCharsets.UTF_8))
                }

                val code = conn.responseCode
                Log.i(TAG, "Backend XNOX respondió HTTP $code")
            } catch (e: Exception) {
                Log.e(TAG, "Error enviando pago al backend: ${e.message}")
            } finally {
                conn?.disconnect()
            }
        }.start()
    }

    companion object {
        // Solo se usa si Flutter aún no ha sincronizado el endpoint en prefs.
        private const val DEFAULT_URL =
            "https://xnonx.xnoxsoft.es/api/recibir_notificacion.php"
    }
}
