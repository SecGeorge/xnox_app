import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';

/// Provee la membresía del cliente.
///
/// TODO: reemplazar el dato demo por la respuesta del backend.
class ControladorMembresia {
  Future<MembresiaCliente> obtenerMembresia() async {
    return MembresiaCliente.demo();
  }
}
