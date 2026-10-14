import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/buscar_alimento_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Agregar alimentos (desayuno, almuerzo, cena, aperitivos) no debe
/// desbordarse en un teléfono angosto con letra grande.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  const alimento = Alimento(
    id: 1,
    nombre: 'Pechuga de pollo a la plancha con especias y limón',
    porcionG: 150,
    porcionNombre: '1 filete',
    etiquetas: ['alto_proteina', 'alto_sodio', 'alto_grasa_saturada'],
    por100g: {
      'kcal': 165,
      'proteina': 31,
      'carbohidrato': 0,
      'grasa': 3.6,
      'grasa_saturada': 1,
      'sodio': 74,
    },
  );

  Future<void> telefono(WidgetTester t, Widget pantalla) async {
    t.view.physicalSize = const Size(320 * 3, 760 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(1.3)),
          child: pantalla,
        ),
      ),
    );
    await t.pump();
  }

  testWidgets('comidas del día con "Agregar" y alimentos', (t) async {
    await telefono(
      t,
      Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            ComidasDelDia(
              consumos: [
                for (final tiempo in ['desayuno', 'almuerzo', 'cena'])
                  Consumo(
                    uid: tiempo,
                    fecha: '2026-10-13',
                    tiempo: tiempo,
                    cantidadG: 300,
                    planItemId: 5,
                    alimento: alimento,
                  ),
              ],
              onAgregar: (_) {},
              onEditar: (_) {},
              onEliminar: (_) {},
            ),
          ],
        ),
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Agregar'), findsWidgets);
  });

  testWidgets('buscador vacío (portada, sugerencias y crear)', (t) async {
    for (final tiempo in ['desayuno', 'almuerzo', 'cena', 'aperitivo']) {
      await telefono(t, BuscarAlimentoScreen(tiempo: tiempo));
      expect(t.takeException(), isNull, reason: tiempo);
    }
  });

  testWidgets('hoja de cantidad y comida del día', (t) async {
    await telefono(
      t,
      Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () => elegirCantidad(context, alimento),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('abrir'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
    expect(find.text('¿EN QUÉ COMIDA?'), findsOneWidget);

    // Elegir otra porción no debe desbordar (cambian los textos).
    await t.tap(find.textContaining('2 filetes'));
    await t.pumpAndSettle();
    expect(t.takeException(), isNull);
  });
}
