/// Quién mira la tienda de XNOX: cada producto se publica para el personal
/// del gimnasio, para sus socios o para ambos (panel de XNOX → Tienda).
enum PublicoTiendaXnox {
  admin('admin', 'administrador'),
  cliente('cliente', 'socio');

  /// Valor del parámetro `para` de la API.
  final String clave;

  /// Cómo se presenta quien escribe en el mensaje de WhatsApp.
  final String rol;

  const PublicoTiendaXnox(this.clave, this.rol);
}

/// Producto de la tienda de XNOX: no pertenece al gimnasio. Lo sirve la API
/// del sitio de XNOX (`api/tienda.php`), no el backend del gimnasio, y se
/// pide por WhatsApp o por su enlace, no con un pedido de la tienda.
class ProductoXnox {
  final int id;
  final String nombre;
  final String descripcion;
  final String categoria;
  final double precio;

  /// Precio tachado de una oferta, o `null` si no hay.
  final double? precioAntes;
  final String moneda;

  /// Ruta de la foto en el sitio de XNOX (`/uploads/productos/…`), o vacía.
  final String imagen;

  /// Número en formato wa.me (con código de país, sin "+"), o `null`.
  final String? whatsapp;
  final String? enlace;

  const ProductoXnox({
    required this.id,
    required this.nombre,
    required this.descripcion,
    required this.categoria,
    required this.precio,
    required this.precioAntes,
    required this.moneda,
    required this.imagen,
    required this.whatsapp,
    required this.enlace,
  });

  bool get enOferta => precioAntes != null && precioAntes! > precio;

  /// Descuento redondeado de la oferta (p. ej. 15 para "-15%").
  int get descuento =>
      enOferta ? ((1 - precio / precioAntes!) * 100).round() : 0;

  factory ProductoXnox.fromJson(Map<String, dynamic> json) {
    double? aDouble(dynamic v) =>
        v == null ? null : double.tryParse(v.toString());
    String? texto(dynamic v) {
      final t = (v ?? '').toString().trim();
      return t.isEmpty ? null : t;
    }

    return ProductoXnox(
      id: int.tryParse(json['id']?.toString() ?? '') ?? 0,
      nombre: (json['nombre'] ?? '').toString(),
      descripcion: (json['descripcion'] ?? '').toString(),
      categoria: (json['categoria'] ?? '').toString().trim(),
      precio: aDouble(json['precio']) ?? 0,
      precioAntes: aDouble(json['precio_antes']),
      moneda: (json['moneda'] ?? 'PEN').toString(),
      imagen: (json['imagen'] ?? '').toString(),
      whatsapp: texto(json['whatsapp']),
      enlace: texto(json['enlace']),
    );
  }
}
