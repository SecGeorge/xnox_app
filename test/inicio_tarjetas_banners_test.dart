import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/core/widgets/carrusel_banners.dart';
import 'package:xnox_app/core/widgets/tarjeta_giratoria.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/banners_inicio.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/cabecera_inicio.dart';
import 'package:xnox_app/features/tienda/dominio/entidades/producto_tienda.dart';

SesionClase _sesion(
  int claseId,
  DateTime fecha, {
  String hora = '07:00',
  bool pasada = false,
  int libres = 6,
}) => SesionClase.fromJson({
  'clase_id': claseId,
  'horario_id': claseId,
  'fecha': fecha.toIso8601String().substring(0, 10),
  'hora_inicio': hora,
  'hora_fin': '08:00',
  'nombre': 'Clase $claseId',
  'color': '#E11D48',
  'entrenador': 'Ana',
  'salon': 'Sala 1',
  'libres': libres,
  'pasada': pasada,
  'incluida': true,
  'motivo': '',
});

ProductoTienda _producto(int id, {double stock = 3, String imagen = 'p.jpg'}) =>
    ProductoTienda(
      id: id,
      codigo: '$id',
      nombre: 'Producto $id',
      nombreMarca: 'Marca',
      nombreCategoria: '',
      imagen: imagen,
      unidades: [
        UnidadProducto(
          unidadMedidaId: 1,
          unidadMedida: 'UND',
          precioVenta: 90,
          stockActual: stock,
        ),
      ],
    );

Widget _app(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

CarasTarjeta _caras(int i) =>
    CarasTarjeta(frente: Text('frente $i'), reverso: Text('reverso $i'));

/// Cara que se está viendo de la tarjeta [i]: la otra sigue montada debajo.
int _caraVisible(WidgetTester tester, int i) => tester
    .widget<IndexedStack>(
      find
          .descendant(
            of: find.byType(TarjetaGiratoria).at(i),
            matching: find.byType(IndexedStack),
          )
          .first,
    )
    .index!;

void main() {
  final ahora = DateTime(2026, 10, 30, 12);

  setUpAll(() => initializeDateFormatting('es'));

  group('clasesParaBanner', () {
    test('quita las que ya pasaron y ordena por hora', () {
      final lista = clasesParaBanner([
        _sesion(1, ahora.add(const Duration(days: 2))),
        _sesion(2, ahora, hora: '09:00'),
        _sesion(3, ahora.add(const Duration(days: 1))),
        _sesion(4, ahora.add(const Duration(days: 1)), pasada: true),
      ], ahora);
      expect(lista.map((s) => s.claseId), [3, 1]);
    });

    test('prefiere clases distintas y no pasa de cinco', () {
      final lista = clasesParaBanner([
        for (var d = 1; d <= 7; d++) _sesion(1, ahora.add(Duration(days: d))),
        _sesion(2, ahora.add(const Duration(days: 6))),
      ], ahora);
      expect(lista, hasLength(maximoBanners));
      expect(lista.take(2).map((s) => s.claseId), [1, 2]);
    });
  });

  group('productosParaBanner', () {
    test('sin agotados, con foto primero y no pasa de cinco', () {
      final lista = productosParaBanner([
        _producto(1, imagen: ''),
        _producto(2, stock: 0),
        for (var i = 3; i < 12; i++) _producto(i),
      ]);
      expect(lista, hasLength(maximoBanners));
      expect(lista.every((p) => p.disponible && p.imagen.isNotEmpty), isTrue);
    });

    test('con pocos productos usa también los que no tienen foto', () {
      final lista = productosParaBanner([
        _producto(1, imagen: ''),
        _producto(2),
      ]);
      expect(lista.map((p) => p.id), [2, 1]);
    });
  });

  group('CuadriculaGiratoria', () {
    // Largo a propósito: que el giro termine antes del turno siguiente.
    const intervalo = Duration(seconds: 5);

    testWidgets('gira de una en una y siempre deja una de espaldas', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          CuadriculaGiratoria(
            tarjetas: [for (var i = 0; i < 3; i++) _caras(i)],
            alto: 100,
            separacion: 8,
            intervalo: intervalo,
          ),
        ),
      );
      expect(_caraVisible(tester, 0), 0);

      await tester.pump(intervalo);
      await tester.pumpAndSettle();
      expect(_caraVisible(tester, 0), 1);
      expect(_caraVisible(tester, 1), 0);

      await tester.pump(intervalo);
      await tester.pumpAndSettle();
      expect(_caraVisible(tester, 0), 0);
      expect(_caraVisible(tester, 1), 1);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no gira si no está activa', (tester) async {
      await tester.pumpWidget(
        _app(
          CuadriculaGiratoria(
            tarjetas: [_caras(0), _caras(1)],
            alto: 100,
            separacion: 8,
            activa: false,
            intervalo: intervalo,
          ),
        ),
      );
      await tester.pump(intervalo * 3);
      await tester.pumpAndSettle();
      expect(_caraVisible(tester, 0), 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no gira si el teléfono desactivó las animaciones', (
      tester,
    ) async {
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: _app(
            CuadriculaGiratoria(
              tarjetas: [_caras(0), _caras(1)],
              alto: 100,
              separacion: 8,
              intervalo: intervalo,
            ),
          ),
        ),
      );
      await tester.pump(intervalo * 3);
      await tester.pumpAndSettle();
      expect(_caraVisible(tester, 0), 0);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('la cara de atrás recibe el toque', (tester) async {
      var toques = 0;
      await tester.pumpWidget(
        _app(
          SizedBox(
            width: 300,
            child: CuadriculaGiratoria(
              tarjetas: [
                CarasTarjeta(
                  frente: const Text('frente'),
                  reverso: TextButton(
                    onPressed: () => toques++,
                    child: const Text('reverso'),
                  ),
                ),
              ],
              alto: 100,
              separacion: 8,
              intervalo: intervalo,
            ),
          ),
        ),
      );
      await tester.pump(intervalo);
      await tester.pumpAndSettle();
      await tester.tap(find.text('reverso'));
      expect(toques, 1);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('CarruselBanners', () {
    testWidgets('pasa solo y vuelve a empezar', (tester) async {
      await tester.pumpWidget(
        _app(
          CarruselBanners(
            cantidad: 2,
            alto: 100,
            intervalo: const Duration(seconds: 1),
            constructor: (_, i) => Text('banner $i'),
          ),
        ),
      );
      expect(find.text('banner 0'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      final indicador = tester
          .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
          .map((c) => c.constraints?.maxWidth)
          .toList();
      expect(indicador, [10, 22]);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(
        tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .map((c) => c.constraints?.maxWidth),
        [22, 10],
      );
      await tester.pumpWidget(const SizedBox());
    });

    // Con un carrusel "infinito" (arrancando en una página muy alta) esto
    // rompía el layout a 360 de ancho: los banners salían en blanco.
    testWidgets('se dibuja al ancho de un teléfono de 360', (tester) async {
      tester.view.physicalSize = const Size(720, 1600);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _app(
          SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: CarruselBanners(
              cantidad: 5,
              alto: 100,
              intervalo: const Duration(seconds: 1),
              constructor: (_, i) => Text('banner $i'),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('banner 0'), findsOneWidget);

      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(seconds: 1));
        await tester.pumpAndSettle();
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('con un solo banner no hay carrusel', (tester) async {
      await tester.pumpWidget(
        _app(
          CarruselBanners(
            cantidad: 1,
            alto: 100,
            constructor: (_, i) => Text('banner $i'),
          ),
        ),
      );
      expect(find.byType(PageView), findsNothing);
      expect(find.text('banner 0'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('cabecera', () {
    test('el saludo depende de la hora', () {
      String a(int hora) => saludoPorHora(DateTime(2026, 10, 30, hora));
      expect(a(7), 'Buenos días');
      expect(a(12), 'Buenas tardes');
      expect(a(19), 'Buenas noches');
      expect(a(2), 'Buenas noches');
    });

    const intervalo = Duration(seconds: 4);
    final tocados = <String>[];
    final mensajes = [
      MensajeCabecera('1', 'uno', () => tocados.add('uno')),
      MensajeCabecera('2', 'dos', () => tocados.add('dos')),
    ];

    testWidgets('pasa los mensajes y el toque va al que se ve', (tester) async {
      tocados.clear();
      await tester.pumpWidget(
        _app(FranjaMensajes(mensajes: mensajes, intervalo: intervalo)),
      );
      expect(find.text('uno'), findsOneWidget);

      await tester.pump(intervalo);
      await tester.pumpAndSettle();
      expect(find.text('uno'), findsNothing);
      await tester.tap(find.text('dos'));
      expect(tocados, ['dos']);

      await tester.pump(intervalo);
      await tester.pumpAndSettle();
      expect(find.text('uno'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('sigue bien si la lista se acorta', (tester) async {
      await tester.pumpWidget(
        _app(FranjaMensajes(mensajes: mensajes, intervalo: intervalo)),
      );
      await tester.pump(intervalo);
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _app(FranjaMensajes(mensajes: [mensajes.first], intervalo: intervalo)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('uno'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('no pasa si no está activa', (tester) async {
      await tester.pumpWidget(
        _app(
          FranjaMensajes(
            mensajes: mensajes,
            activa: false,
            intervalo: intervalo,
          ),
        ),
      );
      await tester.pump(intervalo * 2);
      await tester.pumpAndSettle();
      expect(find.text('uno'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    });
  });

  testWidgets('los banners caben con textos largos', (tester) async {
    tester.view.physicalSize = const Size(360, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sesion = SesionClase.fromJson({
      'clase_id': 1,
      'horario_id': 1,
      'fecha': ahora
          .add(const Duration(days: 4))
          .toIso8601String()
          .substring(0, 10),
      'hora_inicio': '19:30',
      'nombre': 'Entrenamiento funcional de alta intensidad avanzado',
      'color': '#E11D48',
      'entrenador': 'Maria Fernanda de los Angeles Quispe',
      'salon': 'Salón principal del segundo piso',
      'libres': 1,
      'precio': 25,
      'motivo': '',
    });
    await tester.pumpWidget(
      _app(
        Column(
          children: [
            BannersClases(sesiones: [sesion], activo: false, onTap: () {}),
            BannersProductos(
              productos: [
                ProductoTienda(
                  id: 1,
                  codigo: '1',
                  nombre: 'Proteína whey isolate sabor vainilla francesa 5 lb',
                  nombreMarca: 'Optimum Nutrition Gold Standard',
                  nombreCategoria: '',
                  imagen: '',
                  unidades: const [
                    UnidadProducto(
                      unidadMedidaId: 1,
                      unidadMedida: 'UND',
                      precioVenta: 1299.9,
                      stockActual: 2,
                    ),
                  ],
                ),
              ],
              activo: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
