import 'dart:convert';
import 'dart:math';

import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';

/// Error de nutrición con un mensaje listo para mostrar.
class ErrorNutricion implements Exception {
  final String mensaje;
  const ErrorNutricion(this.mensaje);

  @override
  String toString() => mensaje;
}

/// Habla con `nutricion.php`. No guarda nada en el teléfono: buscar
/// alimentos ya necesita internet (catálogo del gimnasio + Open Food Facts),
/// así que todo va directo al servidor. Cada comida lleva un `uid` propio para
/// que un reintento no la duplique.
///
/// El socio usa los métodos sin [miembroId] (el backend lo toma de su
/// sesión); el personal pasa el socio que está viendo.
class RepositorioNutricion {
  static const _ruta = 'nutricion.php';
  final _http = HttpService();
  final _azar = Random.secure();

  String nuevoUid() =>
      '${DateTime.now().microsecondsSinceEpoch}-${_azar.nextInt(1 << 32)}';

  Future<Map<String, dynamic>> _pedir(Map<String, dynamic> datos) async {
    var resp = await _http.obtenerConDatos(datos, _ruta);
    if (resp is String) {
      try {
        resp = jsonDecode(resp);
      } catch (_) {}
    }
    if (resp is! Map) {
      throw const ErrorNutricion('No se pudo conectar con el gimnasio');
    }
    final mapa = Map<String, dynamic>.from(resp);
    if (mapa['error'] != null && mapa['resultado'] == null) {
      throw ErrorNutricion('${mapa['error']}');
    }
    return mapa;
  }

  /// Para guardar: falla con el mensaje del servidor si no se pudo.
  Future<void> _guardar(Map<String, dynamic> datos) async {
    final r = await _pedir(datos);
    if (r['resultado'] != true) {
      throw ErrorNutricion(
        '${r['mensaje'] ?? r['error'] ?? 'No se pudo guardar'}',
      );
    }
  }

  /// Perfil, metas, plan, comidas y días entre [desde] y [hasta].
  Future<ResumenNutricion> resumen({
    int? miembroId,
    required DateTime desde,
    required DateTime hasta,
  }) async {
    final r = await _pedir({
      'metodo': miembroId == null ? 'mi_resumen' : 'detalle',
      'miembro_id': ?miembroId,
      'desde': isoFecha(desde),
      'hasta': isoFecha(hasta),
    });
    if (r['resultado'] != true) {
      throw ErrorNutricion('${r['error'] ?? 'No se pudo cargar tu nutrición'}');
    }
    return ResumenNutricion.desdeJson(r);
  }

  /// Catálogo del gimnasio y, si hay pocos, Open Food Facts. Un número de 8 a
  /// 14 dígitos se busca como código de barras.
  Future<List<Alimento>> buscar(String texto) async {
    final r = await _pedir({'metodo': 'buscar_alimento', 'texto': texto});
    return [
      for (final a in (r['datos'] as List?) ?? const [])
        Alimento.desdeJson(Map<String, dynamic>.from(a)),
    ];
  }

  Future<Alimento?> porCodigo(String codigo) async {
    final r = await _pedir({'metodo': 'alimento_codigo', 'codigo': codigo});
    return r['alimento'] is Map
        ? Alimento.desdeJson(Map<String, dynamic>.from(r['alimento']))
        : null;
  }

  /// Comida casera o producto que no está en la búsqueda (valores por 100 g).
  Future<Alimento> crearAlimento({
    required String nombre,
    required double porcionG,
    String? porcionNombre,
    required Map<String, double?> por100g,
  }) async {
    final r = await _pedir({
      'metodo': 'crear_alimento',
      'alimento': {
        'nombre': nombre,
        'porcion_g': porcionG,
        'porcion_nombre': porcionNombre ?? '',
        'por_100g': por100g,
      },
    });
    if (r['resultado'] != true || r['alimento'] is! Map) {
      throw ErrorNutricion('${r['mensaje'] ?? 'No se pudo crear el alimento'}');
    }
    return Alimento.desdeJson(Map<String, dynamic>.from(r['alimento']));
  }

  Future<void> guardarPerfil({
    int? miembroId,
    required double alturaCm,
    String? sexo,
    required String objetivo,
    required int actividad,
  }) => _guardar({
    'metodo': miembroId == null ? 'guardar_perfil' : 'guardar_perfil_socio',
    'miembro_id': ?miembroId,
    'perfil': {
      'altura_cm': alturaCm,
      'sexo': sexo ?? '',
      'objetivo': objetivo,
      'actividad': actividad,
    },
  });

  // ---- Socio ---------------------------------------------------------------

  Future<void> guardarConsumo({
    String? uid,
    required DateTime fecha,
    required String tiempo,
    required int alimentoId,
    required double cantidadG,
    int? planItemId,
  }) => _guardar({
    'metodo': 'guardar_consumo',
    'consumo': {
      'uid': uid ?? nuevoUid(),
      'fecha': isoFecha(fecha),
      'tiempo': tiempo,
      'alimento_id': alimentoId,
      'cantidad_g': cantidadG,
      'plan_item_id': ?planItemId,
    },
  });

  Future<void> eliminarConsumo(String uid) =>
      _guardar({'metodo': 'eliminar_consumo', 'uid': uid});

  // ---- Personal ------------------------------------------------------------

  Future<void> guardarPlan({
    required int miembroId,
    required String nombre,
    String? notas,
    required List<ItemPlan> items,
  }) => _guardar({
    'metodo': 'guardar_plan',
    'miembro_id': miembroId,
    'plan': {
      'nombre': nombre,
      'notas': notas ?? '',
      'items': [
        for (final i in items)
          {
            'tiempo': i.tiempo,
            'alimento_id': i.alimento.id,
            'cantidad_g': i.cantidadG,
          },
      ],
    },
  });

  Future<void> eliminarPlan(int miembroId) =>
      _guardar({'metodo': 'eliminar_plan', 'miembro_id': miembroId});

  Future<void> guardarMetas(int miembroId, List<MetaNutricion> metas) =>
      _guardar({
        'metodo': 'guardar_metas',
        'miembro_id': miembroId,
        'metas': [for (final m in metas) m.aJson()],
      });

  Future<void> restablecerMetas(int miembroId) =>
      _guardar({'metodo': 'restablecer_metas', 'miembro_id': miembroId});
}
