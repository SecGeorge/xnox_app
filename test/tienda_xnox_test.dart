import 'package:flutter_test/flutter_test.dart';
import 'package:xnox_app/features/tienda_xnox/datos/repositorio_tienda_xnox.dart';
import 'package:xnox_app/features/tienda_xnox/dominio/producto_xnox.dart';

void main() {
  test('lee un producto tal como lo manda api/tienda.php', () {
    final p = ProductoXnox.fromJson({
      'id': 1,
      'nombre': 'Proteína XNOX Whey 2kg',
      'descripcion': 'Prueba',
      'categoria': 'Suplementos',
      'precio': 189.9,
      'precio_antes': 220,
      'moneda': 'PEN',
      'imagen': '/uploads/productos/0f6d4ac611576127.png',
      'whatsapp': '51938197971',
      'enlace': null,
    });

    expect(p.precio, 189.9);
    expect(p.enOferta, isTrue);
    expect(p.descuento, 14);
    expect(p.whatsapp, '51938197971');
    expect(p.enlace, isNull);
    expect(
      RepositorioTiendaXnox.urlImagen(p.imagen),
      'https://www.xnoxsoft.es/uploads/productos/0f6d4ac611576127.png',
    );
  });

  test('sin oferta, sin foto y con campos vacíos', () {
    final p = ProductoXnox.fromJson({
      'id': '2',
      'nombre': 'Lector de huella',
      'precio': '350.00',
      'precio_antes': null,
      'imagen': null,
      'whatsapp': '',
      'enlace': 'https://xnoxsoft.es',
    });

    expect(p.id, 2);
    expect(p.enOferta, isFalse);
    expect(p.descuento, 0);
    expect(p.categoria, '');
    expect(p.whatsapp, isNull);
    expect(p.enlace, 'https://xnoxsoft.es');
    expect(RepositorioTiendaXnox.urlImagen(p.imagen), '');
  });

  test('cada público pide su parámetro', () {
    expect(PublicoTiendaXnox.admin.clave, 'admin');
    expect(PublicoTiendaXnox.cliente.clave, 'cliente');
  });
}
