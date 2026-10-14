import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/datos_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Las portadas con foto no deben desbordarse aunque el título ocupe dos
/// líneas y el teléfono use letra grande: crecen en vez de cortar.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Future<void> dibujar(WidgetTester tester, Widget hijo) async {
    tester.view.physicalSize = const Size(320 * 3, 900 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: Scaffold(
            body: ListView(padding: const EdgeInsets.all(16), children: [hijo]),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('portada con todo y letra grande no se desborda', (t) async {
    await dibujar(
      t,
      PortadaNutricion(
        foto: FotosNutricion.almuerzo,
        icono: Icons.lunch_dining_rounded,
        chip: 'Almuerzo',
        alto: 140,
        titulo: 'Pechuga de pollo a la plancha con arroz integral y ensalada',
        detalle: '3 alimento(s) · P 62 g · G 12 g · y un detalle bastante largo',
        hechos: 2,
        total: 3,
        accion: BotonFoto('Agregar', onTap: () {}),
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('acceso con foto y letra grande no se desborda', (t) async {
    await dibujar(
      t,
      SizedBox(
        width: 140,
        child: AccesoFoto(
          foto: FotosNutricion.diario,
          icono: Icons.menu_book_rounded,
          titulo: 'Mi progreso',
          detalle: '12 de 30 días cumplidos este mes',
          onTap: () {},
        ),
      ),
    );
    expect(t.takeException(), isNull);
  });

  testWidgets('Tus datos en pantalla angosta con letra grande', (t) async {
    t.view.physicalSize = const Size(320 * 3, 1400 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: DatosNutricionScreen(
            perfil: PerfilNutricion(
              miembroId: 1,
              nombre: 'Socio',
              alturaCm: 168,
              peso: 72.5,
              objetivo: 'ganar',
              actividad: 3,
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(find.text('IMC 25.7'), findsOneWidget);
  });

  testWidgets('calendario del diario se abre y se cierra', (t) async {
    final hoy = DateTime.now();
    DateTime? elegido;
    final resumen = ResumenNutricion(
      desde: isoFecha(hoy),
      hasta: isoFecha(hoy),
      perfil: const PerfilNutricion(miembroId: 1, nombre: 'Socio'),
      metas: const [],
      consumos: const [],
      dias: [
        DiaNutricion(
          fecha: isoFecha(hoy),
          registros: 2,
          totales: const {},
          cumple: const {},
          cumpleDia: true,
        ),
      ],
      racha: const RachaNutricion(),
    );
    await dibujar(
      t,
      CalendarioNutricion(
        resumen: resumen,
        seleccionado: hoy,
        desde: DateTime(hoy.year, hoy.month, hoy.day - 89),
        onElegir: (d) => elegido = d,
      ),
    );
    // Cerrado: solo la barra con el día.
    expect(find.text('L'), findsNothing);
    expect(find.text('Hoy'), findsOneWidget);

    // Al tocarla se abre el mes, sin desbordes con letra grande.
    await t.tap(find.text('Hoy'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('L'), findsOneWidget);

    // Elegir un día lo avisa y cierra el calendario.
    await t.tap(find.text('${hoy.day}').last);
    await t.pumpAndSettle();
    expect(elegido, isNotNull);
    expect(isoFecha(elegido!), isoFecha(hoy));
    expect(find.text('L'), findsNothing);
  });

  testWidgets('portada: alto mínimo con poco texto y crece con mucho', (t) async {
    final llave = GlobalKey();
    Widget portada(bool mucho) => PortadaNutricion(
      key: llave,
      foto: FotosNutricion.desayuno,
      icono: Icons.free_breakfast_rounded,
      chip: 'Desayuno',
      alto: 160,
      titulo: mucho ? '¿Qué comiste? ' * 3 : '¿Qué comiste?',
      detalle: mucho ? 'Escribe arriba o escanea el código del empaque' : null,
      accion: mucho ? BotonFoto('Escanear código', onTap: () {}) : null,
    );

    await dibujar(t, portada(false));
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(llave)).height, closeTo(160, 2.5));

    t.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
          child: Scaffold(
            body: ListView(
              padding: const EdgeInsets.all(16),
              children: [portada(true)],
            ),
          ),
        ),
      ),
    );
    await t.pump();
    expect(t.takeException(), isNull);
    expect(t.getSize(find.byKey(llave)).height, greaterThan(160));
  });
}
