/// Una unidad de medida vendible de un producto (con su precio y stock).
class UnidadProducto {
  final int unidadMedidaId;
  final String unidadMedida;
  final double precioVenta;
  final double stockActual;

  const UnidadProducto({
    required this.unidadMedidaId,
    required this.unidadMedida,
    required this.precioVenta,
    required this.stockActual,
  });

  factory UnidadProducto.fromJson(Map<String, dynamic> json) {
    double aDouble(dynamic v) => double.tryParse(v?.toString() ?? '0') ?? 0;
    int aInt(dynamic v) => int.tryParse(v?.toString() ?? '0') ?? 0;
    return UnidadProducto(
      unidadMedidaId: aInt(json['unidad_medida_id']),
      unidadMedida: (json['unidad_medida'] ?? '').toString(),
      precioVenta: aDouble(json['precio_venta']),
      stockActual: aDouble(json['stock_actual']),
    );
  }
}

/// Producto del catálogo de la tienda, con sus unidades vendibles.
class ProductoTienda {
  final int id;
  final String codigo;
  final String nombre;
  final String nombreMarca;
  final String nombreCategoria;
  final String imagen;
  final List<UnidadProducto> unidades;

  const ProductoTienda({
    required this.id,
    required this.codigo,
    required this.nombre,
    required this.nombreMarca,
    required this.nombreCategoria,
    required this.imagen,
    required this.unidades,
  });

  /// Primera unidad disponible (la que se usa por defecto en la app).
  UnidadProducto? get unidadPrincipal =>
      unidades.isNotEmpty ? unidades.first : null;

  double get precio => unidadPrincipal?.precioVenta ?? 0;
  double get stock => unidadPrincipal?.stockActual ?? 0;

  /// Solo es comprable si tiene una unidad con stock.
  bool get disponible => unidadPrincipal != null && stock > 0;

  factory ProductoTienda.fromJson(Map<String, dynamic> json) {
    final unidadesRaw = json['unidades'];
    final unidades = (unidadesRaw is List)
        ? unidadesRaw
            .whereType<Map>()
            .map((u) => UnidadProducto.fromJson(Map<String, dynamic>.from(u)))
            .toList()
        : <UnidadProducto>[];

    return ProductoTienda(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      codigo: (json['codigo'] ?? '').toString(),
      nombre: (json['nombre'] ?? '').toString(),
      nombreMarca: (json['nombre_marca'] ?? '').toString(),
      nombreCategoria: (json['nombre_categoria'] ?? '').toString(),
      imagen: (json['imagen'] ?? '').toString(),
      unidades: unidades,
    );
  }
}

/// Resultado de cargar la tienda: el almacén/organizador activo y sus productos.
class CatalogoTienda {
  final int organizadorId;
  final List<ProductoTienda> productos;

  const CatalogoTienda({required this.organizadorId, required this.productos});
}
