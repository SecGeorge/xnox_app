/// Empresa (tenant) a la que puede apuntar la app. El `rutaGlobal` es la URL
/// base de la API que usa [HttpService] cuando esta empresa está activa.
class Empresa {
  final int id;
  final String codigo;
  final String nombre;
  final String rutaGlobal;

  /// Código que este servidor reconoce dentro de sus peticiones (su constante
  /// `CODIGO_GIMNASIO`). No tiene por qué ser igual a [codigo], que es el que
  /// escribe el usuario: hoy todos los despliegues comparten el mismo valor.
  final String? codigoBackend;

  /// Plantilla de colores elegida (id de `PaletasApp`), o `null` si aún no
  /// eligió ninguna.
  final String? paleta;

  /// Logo y nombre del gimnasio según sus ajustes del backend (copia local).
  final String? logoUrl;
  final String? nombreComercial;
  final bool activa;

  const Empresa({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.rutaGlobal,
    required this.codigoBackend,
    this.paleta,
    this.logoUrl,
    this.nombreComercial,
    required this.activa,
  });

  /// El código a enviar al backend: el que reconoce el servidor si lo sabemos,
  /// y si no el escrito por el usuario.
  String get codigoParaBackend => codigoBackend ?? codigo;

  factory Empresa.desdeMapa(Map<String, dynamic> m) => Empresa(
        id: m['id'] as int,
        codigo: m['codigo'] as String,
        nombre: m['nombre'] as String,
        rutaGlobal: m['ruta_global'] as String,
        codigoBackend: m['codigo_backend'] as String?,
        paleta: m['paleta'] as String?,
        logoUrl: m['logo_url'] as String?,
        nombreComercial: m['nombre_comercial'] as String?,
        activa: (m['activa'] as int? ?? 0) == 1,
      );
}
