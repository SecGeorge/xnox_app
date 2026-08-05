/// A quién va dirigida la recomendación. Los valores numéricos son los que
/// guarda la columna `recomendacion.destino` en el backend.
enum DestinoRecomendacion {
  gimnasio(1, 'Gimnasio'),
  app(2, 'App');

  final int valor;
  final String etiqueta;

  const DestinoRecomendacion(this.valor, this.etiqueta);

  static DestinoRecomendacion desdeValor(int valor) =>
      valor == 2 ? DestinoRecomendacion.app : DestinoRecomendacion.gimnasio;
}

/// Una recomendación dejada por un usuario de la app. Cuando es anónima el
/// backend no guarda al autor, así que `autor` llega como "Anónimo".
class Recomendacion {
  final int id;
  final DestinoRecomendacion destino;
  final String mensaje;
  final bool anonimo;
  final bool leido;
  final DateTime? fechaCreacion;
  final String autor;
  final String autorRol;
  final String autorTelefono;

  const Recomendacion({
    required this.id,
    required this.destino,
    required this.mensaje,
    required this.anonimo,
    required this.leido,
    required this.fechaCreacion,
    required this.autor,
    required this.autorRol,
    required this.autorTelefono,
  });

  factory Recomendacion.fromJson(Map<String, dynamic> json) {
    // MySQL devuelve los enteros como String en varios endpoints, así que se
    // normaliza todo a texto antes de interpretarlo.
    int aEntero(dynamic v) => int.tryParse('${v ?? ''}') ?? 0;
    bool aBool(dynamic v) => aEntero(v) == 1;

    return Recomendacion(
      id: aEntero(json['id']),
      destino: DestinoRecomendacion.desdeValor(aEntero(json['destino'])),
      mensaje: '${json['mensaje'] ?? ''}',
      anonimo: aBool(json['anonimo']),
      leido: aBool(json['leido']),
      fechaCreacion: DateTime.tryParse('${json['fecha_creacion'] ?? ''}'),
      autor: '${json['autor'] ?? 'Anónimo'}',
      autorRol: '${json['autor_rol'] ?? ''}',
      autorTelefono: '${json['autor_telefono'] ?? ''}',
    );
  }
}
