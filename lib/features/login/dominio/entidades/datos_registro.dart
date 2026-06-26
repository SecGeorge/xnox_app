/// Datos que ingresa un cliente al crear su cuenta.
class DatosRegistro {
  final String codigoGimnasio;
  final int idSucursal;
  final String documento;
  final String password;

  DatosRegistro({
    required this.codigoGimnasio,
    required this.idSucursal,
    required this.documento,
    required this.password,
  });

  Map<String, dynamic> toJson() => {
        'codigo_gimnasio': codigoGimnasio,
        'sucursal_id': idSucursal,
        // El DNI es el código con el que el cliente figura como miembro
        // y además será su usuario de acceso. El backend toma el nombre y
        // teléfono del miembro ya registrado en el gimnasio.
        'codigo': documento,
        'password': password,
      };
}
