import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/marketing/datos/repositorios/repositorio_mensajeria_impl.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/campania.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/cliente_destinatario.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/plantilla_mensaje.dart';
import 'package:xnox_app/features/marketing/dominio/repositorios/repositorio_mensajeria.dart';

class ControladorMensajeria {
  final RepositorioMensajeria _repositorio;

  ControladorMensajeria._(this._repositorio);

  factory ControladorMensajeria() =>
      ControladorMensajeria._(RepositorioMensajeriaImpl(HttpService()));

  // Plantillas
  Future<List<PlantillaMensaje>> listarPlantillas() =>
      _repositorio.listarPlantillas();
  Future<bool> guardarPlantilla(PlantillaMensaje p) =>
      _repositorio.guardarPlantilla(p);
  Future<bool> eliminarPlantilla(int id) => _repositorio.eliminarPlantilla(id);

  // Clientes (por grupo de estado: 0 = activos, 7 = vencidos)
  Future<List<ClienteDestinatario>> buscarClientes({int estado = 0}) =>
      _repositorio.buscarClientes(estado: estado);

  // Campañas
  Future<bool> registrarCampania({
    int? plantillaId,
    required String plantillaNombre,
    required String filtro,
    required int totalClientes,
    required String estado,
  }) =>
      _repositorio.registrarCampania(
        plantillaId: plantillaId,
        plantillaNombre: plantillaNombre,
        filtro: filtro,
        totalClientes: totalClientes,
        estado: estado,
      );
  Future<List<Campania>> listarCampanias() => _repositorio.listarCampanias();
}
