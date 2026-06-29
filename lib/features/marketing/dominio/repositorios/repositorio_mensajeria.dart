import 'package:xnox_app/features/marketing/dominio/entidades/campania.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/cliente_destinatario.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/plantilla_mensaje.dart';

abstract class RepositorioMensajeria {
  // Plantillas
  Future<List<PlantillaMensaje>> listarPlantillas();
  Future<bool> guardarPlantilla(PlantillaMensaje plantilla);
  Future<bool> eliminarPlantilla(int id);

  // Clientes destinatarios de un grupo de estado:
  // 0 = activos/deudores/sin contrato (excluye vencidos), 7 = vencidos.
  Future<List<ClienteDestinatario>> buscarClientes({int estado});

  // Campañas / historial
  Future<bool> registrarCampania({
    int? plantillaId,
    required String plantillaNombre,
    required String filtro,
    required int totalClientes,
    required String estado,
  });
  Future<List<Campania>> listarCampanias();
}
