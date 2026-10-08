import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';

/// Foto de perfil del socio. Es la misma `miembros.imagen` que registra la web
/// al dar de alta un miembro: si el socio la cambia aquí, el gimnasio también
/// la ve. Compartida por el avatar del inicio y el menú "Más".
class ControladorFotoPerfil {
  ControladorFotoPerfil._();
  static final instancia = ControladorFotoPerfil._();

  /// URL absoluta de la foto, o null si el socio aún no tiene una.
  final url = ValueNotifier<String?>(null);

  /// Mientras se sube una foto nueva.
  final subiendo = ValueNotifier<bool>(false);

  static const _clave = 'foto_perfil';
  final _http = HttpService();

  /// Carga en curso (o la última), para esperar su resultado.
  Future<void>? _carga;

  /// True si el servidor respondió en la última carga (con o sin foto).
  bool _servidorRespondio = false;

  /// ¿El servidor confirmó que el socio NO tiene foto? Sin red da false: no
  /// se le pide una foto que quizá ya tiene.
  Future<bool> confirmadoSinFoto() async {
    await (_carga ?? cargar());
    return _servidorRespondio && url.value == null;
  }

  /// La ruta que guarda el backend es relativa a la API ("../imagenes/x.png");
  /// la foto genérica de alta no cuenta como foto propia.
  String? _aUrl(String? ruta) {
    if (ruta == null || ruta.isEmpty || ruta.endsWith('usuario.png')) {
      return null;
    }
    if (ruta.startsWith('http')) return ruta;
    return Uri.parse(_http.rutaActual).resolve(ruta).toString();
  }

  /// Muestra al instante la última foto conocida y la revalida con el servidor.
  Future<void> cargar() => _carga = _cargar();

  Future<void> _cargar() async {
    _servidorRespondio = false;
    final prefs = await SharedPreferences.getInstance();
    final miembro = prefs.getString('miembroId') ?? '';
    final guardada = prefs.getString(_clave);
    if (guardada != null && guardada.startsWith('$miembro|')) {
      url.value = _aUrl(guardada.substring(miembro.length + 1));
    } else {
      url.value = null;
    }
    try {
      final r = await _http.obtenerConDatos({
        'metodo': 'mi_foto',
      }, 'miembros.php');
      if (r is Map && r.containsKey('imagen')) {
        final ruta = r['imagen']?.toString() ?? '';
        await prefs.setString(_clave, '$miembro|$ruta');
        url.value = _aUrl(ruta);
        _servidorRespondio = true;
      }
    } catch (_) {
      // Sin conexión: se queda la foto en caché.
    }
  }

  /// Toma o elige una foto y la sube. Devuelve null si se canceló, o el
  /// mensaje de error si falló ('' = todo bien).
  Future<String?> cambiar(ImageSource origen) async {
    final XFile? foto = await ImagePicker().pickImage(
      source: origen,
      maxWidth: 720,
      maxHeight: 720,
      imageQuality: 80,
      preferredCameraDevice: CameraDevice.front,
    );
    if (foto == null) return null;
    final bytes = await File(foto.path).readAsBytes();
    subiendo.value = true;
    try {
      final r = await _http.obtenerConDatos({
        'metodo': 'actualizar_foto',
        'imagen': 'data:image/jpeg;base64,${base64Encode(bytes)}',
      }, 'miembros.php');
      if (r is Map && r['voit_exito'].toString() == '1') {
        final ruta = r['imagen']?.toString() ?? '';
        final prefs = await SharedPreferences.getInstance();
        final miembro = prefs.getString('miembroId') ?? '';
        await prefs.setString(_clave, '$miembro|$ruta');
        url.value = _aUrl(ruta);
        return '';
      }
      if (r is Map) {
        return (r['voit_message'] ?? r['error'] ?? 'No se pudo guardar la foto')
            .toString();
      }
      return 'No se pudo guardar la foto';
    } catch (_) {
      return 'No se pudo subir la foto. Revisa tu conexión.';
    } finally {
      subiendo.value = false;
    }
  }
}
