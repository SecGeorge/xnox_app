import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/ejercicios/dominio/entidades/ejercicio_catalogo.dart';

/// Catálogo de ejercicios del backend: buscar para autocompletar y dar de alta
/// el que no existe.
///
/// Un ejercicio creado desde la app nace PRIVADO del cliente (se manda su
/// `miembro_id`): no ensucia el catálogo general, que solo arma el admin desde
/// el sistema web.
class RepositorioEjercicios {
  final HttpService _http;

  RepositorioEjercicios([HttpService? http]) : _http = http ?? HttpService();

  Future<int> _miembroId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('miembroId') ?? '') ?? 0;
  }

  /// Arma la URL absoluta de un archivo del backend a partir de su ruta
  /// relativa (ej. "./imagenes/ejercicios/ej_x.png" o
  /// "./videos/ejercicios/ejv_x.mp4").
  ///
  /// Usa `rutaActual` y NO una constante: la app es multi-empresa y cada una
  /// vive en su propio servidor.
  String? _urlImagen(dynamic ruta) {
    final r = ruta?.toString().trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    final limpia = r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '');
    return '${_http.rutaActual}$limpia';
  }

  EjercicioCatalogo _aEjercicio(Map<String, dynamic> j) {
    final miembro = _entero(j['miembro_id']);
    return EjercicioCatalogo(
      id: _entero(j['id']),
      nombre: j['nombre']?.toString() ?? '',
      descripcion: _textoNullable(j['descripcion']),
      grupoMuscular: _textoNullable(j['grupo_muscular']),
      miembroId: miembro == 0 ? null : miembro,
      imagenUrl: _urlImagen(j['imagen']),
      videoUrl: _urlImagen(j['video']),
    );
  }

  List<EjercicioCatalogo> _mapear(dynamic response) {
    if (response is Map && response['resultado'] == true) {
      final data = response['datos'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map((e) => _aEjercicio(Map<String, dynamic>.from(e)))
            .toList();
      }
    }
    return [];
  }

  /// Sugerencias para el autocompletado: catálogo general + los suyos.
  /// Lista vacía si no hay conexión, para no bloquear el alta a mano.
  Future<List<EjercicioCatalogo>> buscar(String termino) async {
    try {
      final response = await _http.obtenerConDatos(
        {
          'metodo': 'buscar',
          'termino': termino,
          'miembro_id': await _miembroId(),
        },
        'ejercicios.php',
      );
      return _mapear(response);
    } catch (_) {
      return [];
    }
  }

  /// Ejercicio del catálogo con su GALERÍA COMPLETA.
  ///
  /// `buscar` y `listar` traen solo la portada (el SP la corta con LIMIT 1), así
  /// que para ver las demás fotos hay que pedir el ejercicio por id. Devuelve
  /// null si no se pudo (sin conexión o ejercicio inexistente).
  Future<EjercicioCatalogo?> obtener(int id) async {
    try {
      final response = await _http.obtenerConDatos(
        {'metodo': 'obtener', 'id': id},
        'ejercicios.php',
      );

      if (response is Map && response['resultado'] == true) {
        final datos = response['datos'];
        if (datos is Map) {
          final m = Map<String, dynamic>.from(datos);
          // Vienen como filas de ejercicio_imagen, ya ordenadas por el SP.
          final imagenes = <String>[];
          if (m['imagenes'] is List) {
            for (final img in m['imagenes'] as List) {
              final url = _urlImagen(img is Map ? img['imagen'] : img);
              if (url != null) imagenes.add(url);
            }
          }
          final miembro = _entero(m['miembro_id']);
          return EjercicioCatalogo(
            id: _entero(m['id']),
            nombre: m['nombre']?.toString() ?? '',
            descripcion: _textoNullable(m['descripcion']),
            grupoMuscular: _textoNullable(m['grupo_muscular']),
            miembroId: miembro == 0 ? null : miembro,
            imagenUrl: imagenes.isNotEmpty ? imagenes.first : null,
            videoUrl: _urlImagen(m['video']),
            imagenes: imagenes,
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Da de alta un ejercicio propio del cliente con sus imágenes (base64).
  /// Devuelve null si no se pudo (sin conexión, por ejemplo).
  Future<EjercicioCatalogo?> crear({
    required String nombre,
    String? descripcion,
    String? grupoMuscular,
    List<String> imagenesBase64 = const [],
  }) async {
    try {
      final miembroId = await _miembroId();
      final response = await _http.registrar(
        {
          'metodo': 'guardar',
          'ejercicio': {
            'nombre': nombre,
            'descripcion': descripcion,
            'grupo_muscular': grupoMuscular,
            // Sin miembro el ejercicio entraría al catálogo de todos.
            'miembro_id': miembroId,
            'imagenes': imagenesBase64,
          },
        },
        'ejercicios.php',
      );

      if (response is Map && response['resultado'] == true) {
        final datos = response['datos'];
        if (datos is Map) {
          final m = Map<String, dynamic>.from(datos);
          // El guardado devuelve la galería completa; la portada es la primera.
          final imagenes = (m['imagenes'] is List) ? m['imagenes'] as List : const [];
          final portada = imagenes.isNotEmpty && imagenes.first is Map
              ? (imagenes.first as Map)['imagen']
              : null;
          return EjercicioCatalogo(
            id: _entero(m['id']),
            nombre: m['nombre']?.toString() ?? nombre,
            descripcion: _textoNullable(m['descripcion']),
            grupoMuscular: _textoNullable(m['grupo_muscular']),
            miembroId: miembroId == 0 ? null : miembroId,
            imagenUrl: _urlImagen(portada),
            videoUrl: _urlImagen(m['video']),
          );
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Sube el video de ejecución de un ejercicio del catálogo.
  ///
  /// Va por multipart y no en el JSON: un video en base64 reventaría el
  /// `post_max_size` del servidor. Los topes (30 s y 25 MB) los vuelve a
  /// validar el backend, que devuelve el motivo si rechaza el archivo.
  ///
  /// Devuelve null si se subió bien, o el mensaje de error para mostrarlo.
  Future<String?> subirVideo(int ejercicioId, File video) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final formData = FormData.fromMap({
        'payload': jsonEncode({
          'metodo': 'subir_video',
          'ejercicio_id': ejercicioId,
          'usuario_id': prefs.getString('idUsuario'),
        }),
        'video': await MultipartFile.fromFile(
          video.path,
          filename: video.path.split('/').last,
        ),
      });

      final respuesta = await _http.subirArchivo(formData, 'ejercicios.php');
      if (respuesta is Map && respuesta['resultado'] == true) return null;
      return (respuesta is Map)
          ? (respuesta['error']?.toString() ??
              respuesta['mensaje']?.toString() ??
              'No se pudo subir el video')
          : 'No se pudo subir el video';
    } catch (_) {
      return 'No se pudo subir el video. Revisa tu conexión.';
    }
  }

  int _entero(dynamic v) =>
      v == null ? 0 : (v is int ? v : int.tryParse(v.toString()) ?? 0);

  String? _textoNullable(dynamic v) {
    final s = v?.toString().trim() ?? '';
    return s.isEmpty ? null : s;
  }
}
