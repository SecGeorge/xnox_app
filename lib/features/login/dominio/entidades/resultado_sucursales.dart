import 'package:xnox_app/features/login/dominio/entidades/sucursal.dart';

/// Cómo terminó la consulta de sucursales de un gimnasio.
enum EstadoSucursales {
  /// El servidor respondió su lista de sucursales (puede venir vacía si ese
  /// código no es el suyo).
  ok,

  /// No hubo respuesta: red caída, timeout o servidor inalcanzable. No dice
  /// nada del código, solo que no se pudo preguntar.
  sinConexion,

  /// El servidor respondió, pero no con la lista (error interno, ruta que no
  /// es nuestra API…).
  errorServidor,
}

/// Resultado de pedir las sucursales de un gimnasio. Existe para no confundir
/// "el servidor dice que no hay ninguna" con "no se pudo consultar": antes
/// ambos casos llegaban como lista vacía a la pantalla de registro y esta
/// mostraba "No hay sucursales disponibles" aunque el problema fuera la red.
class ResultadoSucursales {
  final EstadoSucursales estado;
  final List<Sucursal> sucursales;

  /// Código de gimnasio con el que se hizo la consulta.
  final String codigo;

  /// Mensaje para el usuario cuando no se pudo consultar.
  final String? mensaje;

  const ResultadoSucursales({
    required this.estado,
    this.sucursales = const [],
    this.codigo = '',
    this.mensaje,
  });

  factory ResultadoSucursales.ok(List<Sucursal> sucursales, String codigo) =>
      ResultadoSucursales(
        estado: EstadoSucursales.ok,
        sucursales: sucursales,
        codigo: codigo,
      );

  factory ResultadoSucursales.sinConexion(String codigo, [String? mensaje]) =>
      ResultadoSucursales(
        estado: EstadoSucursales.sinConexion,
        codigo: codigo,
        mensaje: mensaje ??
            'Sin conexión con el gimnasio. Verifica tu red e inténtalo de nuevo.',
      );

  factory ResultadoSucursales.errorServidor(String codigo, [String? mensaje]) =>
      ResultadoSucursales(
        estado: EstadoSucursales.errorServidor,
        codigo: codigo,
        mensaje: mensaje ?? 'No se pudieron cargar las sucursales.',
      );

  bool get consultado => estado == EstadoSucursales.ok;
  bool get hayDatos => consultado && sucursales.isNotEmpty;
}
