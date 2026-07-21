/// Empresa (tenant) a la que puede apuntar la app. El `rutaGlobal` es la URL
/// base de la API que usa [HttpService] cuando esta empresa está activa.
class Empresa {
  final int id;
  final String codigo;
  final String nombre;
  final String rutaGlobal;
  final bool activa;

  const Empresa({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.rutaGlobal,
    required this.activa,
  });

  factory Empresa.desdeMapa(Map<String, dynamic> m) => Empresa(
        id: m['id'] as int,
        codigo: m['codigo'] as String,
        nombre: m['nombre'] as String,
        rutaGlobal: m['ruta_global'] as String,
        activa: (m['activa'] as int? ?? 0) == 1,
      );
}
