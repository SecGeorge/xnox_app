/// Una sucursal (sede) del gimnasio.
class Sucursal {
  final int id;
  final String nombre;

  const Sucursal({required this.id, required this.nombre});

  factory Sucursal.fromJson(Map<String, dynamic> json) {
    return Sucursal(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      nombre: json['nombre']?.toString() ?? '',
    );
  }

  /// Sucursales de prueba mientras no haya backend.
  /// TODO: reemplazar por las sedes que devuelva el código de gimnasio.
  static const List<Sucursal> demo = [
    Sucursal(id: 1, nombre: 'Sede Central'),
    Sucursal(id: 2, nombre: 'Sede Norte'),
    Sucursal(id: 3, nombre: 'Sede Sur'),
  ];
}
