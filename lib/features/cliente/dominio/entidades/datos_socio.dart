/// Datos que el socio llena desde la app, muchas veces porque el gimnasio no
/// los pidió al registrarlo. Son las mismas columnas de `miembros` que ve la
/// web en la ficha del miembro.
class DatosSocio {
  final DateTime? fechaNacimiento;
  final String direccion;
  final bool sufreEnfermedad;
  final String enfermedad;
  final bool tieneSeguro;
  final String institucion;
  final String nombreContacto;
  final String telefonoContacto;

  const DatosSocio({
    this.fechaNacimiento,
    this.direccion = '',
    this.sufreEnfermedad = false,
    this.enfermedad = '',
    this.tieneSeguro = false,
    this.institucion = '',
    this.nombreContacto = '',
    this.telefonoContacto = '',
  });

  factory DatosSocio.fromJson(Map<String, dynamic> j) {
    String texto(dynamic v) => (v ?? '').toString().trim();
    bool verdad(dynamic v) => v == true || v == 1 || v == '1';
    return DatosSocio(
      fechaNacimiento: DateTime.tryParse(texto(j['fecha_nacimiento'])),
      direccion: texto(j['direccion']),
      sufreEnfermedad: verdad(j['sufreEnfermedad']),
      enfermedad: texto(j['enfermedad']),
      tieneSeguro: verdad(j['tieneSeguro']),
      institucion: texto(j['institucion']),
      nombreContacto: texto(j['nombreContacto']),
      telefonoContacto: texto(j['telefonoContacto']),
    );
  }

  Map<String, dynamic> toJson() {
    final f = fechaNacimiento;
    return {
      'fecha_nacimiento': f == null
          ? ''
          : '${f.year.toString().padLeft(4, '0')}-'
                '${f.month.toString().padLeft(2, '0')}-'
                '${f.day.toString().padLeft(2, '0')}',
      'direccion': direccion,
      'sufreEnfermedad': sufreEnfermedad,
      'enfermedad': enfermedad,
      'tieneSeguro': tieneSeguro,
      'institucion': institucion,
      'nombreContacto': nombreContacto,
      'telefonoContacto': telefonoContacto,
    };
  }
}
