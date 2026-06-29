import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/campania.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/cliente_destinatario.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/plantilla_mensaje.dart';
import 'package:xnox_app/features/marketing/dominio/repositorios/repositorio_mensajeria.dart';

class RepositorioMensajeriaImpl implements RepositorioMensajeria {
  final HttpService _httpService;

  RepositorioMensajeriaImpl(this._httpService);

  Future<int> _sucursalId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('idSucursal') ?? '') ?? 0;
  }

  Future<String?> _usuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('idUsuario');
  }

  // ---------------------------------------------------------------- Plantillas
  @override
  Future<List<PlantillaMensaje>> listarPlantillas() async {
    final response = await _httpService.obtenerConDatos(
      {'metodo': 'listar_plantillas', 'sucursal_id': await _sucursalId()},
      'mensajeria.php',
    );
    final datos = (response is Map) ? response['datos'] : null;
    if (datos is List) {
      return datos
          .whereType<Map>()
          .map((e) => PlantillaMensaje.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  @override
  Future<bool> guardarPlantilla(PlantillaMensaje plantilla) async {
    final esEdicion = plantilla.id != null;
    final response = await _httpService.registrar(
      {
        'metodo': esEdicion ? 'editar_plantilla' : 'registrar_plantilla',
        'datos': plantilla.toJson(),
        'sucursal_id': await _sucursalId(),
        'usuario_id': await _usuarioId(),
      },
      'mensajeria.php',
    );
    return response is Map && response['resultado'] == true;
  }

  @override
  Future<bool> eliminarPlantilla(int id) async {
    final response = await _httpService.eliminar(
      'mensajeria.php',
      {
        'metodo': 'eliminar_plantilla',
        'id': id,
        'usuario_id': await _usuarioId(),
      },
    );
    return response is Map && response['resultado'] == true;
  }

  // ----------------------------------------------------------------- Clientes
  // Carga bajo demanda por grupo de estado para no traer todo el padrón de golpe:
  // estado 0 (activos/deudores/sin contrato) al inicio; estado 7 (vencidos) solo
  // cuando el usuario elige ese filtro.
  @override
  Future<List<ClienteDestinatario>> buscarClientes({int estado = 0}) async {
    return _buscarPorEstado(await _sucursalId(), estado);
  }

  Future<List<ClienteDestinatario>> _buscarPorEstado(
      int sucursalId, int estado) async {
    final response = await _httpService.obtenerConDatos(
      {
        'metodo': 'buscar',
        'sucursal_id': sucursalId,
        'filtros': {
          'estado': estado,
          'membresia': '',
          'bandera_rostro': 0,
          'fecha_inicio': '',
          'fecha_fin': '',
        },
      },
      'miembros.php',
    );
    if (response is List) {
      return response
          .whereType<Map>()
          .map((e) => ClienteDestinatario.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }

  // ----------------------------------------------------------------- Campañas
  @override
  Future<bool> registrarCampania({
    int? plantillaId,
    required String plantillaNombre,
    required String filtro,
    required int totalClientes,
    required String estado,
  }) async {
    final response = await _httpService.registrar(
      {
        'metodo': 'registrar_campania',
        'datos': {
          'plantilla_id': plantillaId,
          'plantilla_nombre': plantillaNombre,
          'filtro': filtro,
          'total_clientes': totalClientes,
          'estado': estado,
        },
        'sucursal_id': await _sucursalId(),
        'usuario_id': await _usuarioId(),
      },
      'mensajeria.php',
    );
    return response is Map && response['resultado'] == true;
  }

  @override
  Future<List<Campania>> listarCampanias() async {
    final response = await _httpService.obtenerConDatos(
      {'metodo': 'listar_campanias', 'sucursal_id': await _sucursalId()},
      'mensajeria.php',
    );
    final datos = (response is Map) ? response['datos'] : null;
    if (datos is List) {
      return datos
          .whereType<Map>()
          .map((e) => Campania.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }
    return [];
  }
}
