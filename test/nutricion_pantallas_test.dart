import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/diario_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/metas_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/plan_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/progreso_nutricion_screen.dart';

/// Las pantallas de Nutrición del socio, con datos reales de ejemplo, no deben
/// desbordarse en teléfonos angostos ni con letra grande.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  Alimento alimento(int id, String nombre, double porcion, String? porcionNombre,
          Map<String, double> por100, [List<String> etiquetas = const []]) =>
      Alimento(
        id: id,
        nombre: nombre,
        porcionG: porcion,
        porcionNombre: porcionNombre,
        etiquetas: etiquetas,
        por100g: por100,
      );

  final pollo = alimento(1, 'Pechuga de pollo a la plancha', 150, '1 filete', {
    'kcal': 165, 'proteina': 31, 'grasa': 3.6, 'grasa_saturada': 1, 'sodio': 74,
  }, ['alto_proteina']);
  final arroz = alimento(2, 'Arroz blanco cocido', 150, '1 taza', {
    'kcal': 130, 'proteina': 2.7, 'carbohidrato': 28.2, 'grasa': 0.3,
  });
  final salchipapa = alimento(3, 'Salchipapa', 300, '1 porción', {
    'kcal': 280, 'proteina': 7, 'carbohidrato': 25, 'grasa': 17,
    'grasa_saturada': 5, 'sodio': 600,
  }, ['alto_sodio', 'alto_grasa_saturada', 'alto_calorias']);

  final hoy = DateTime.now();
  final iso = isoFecha(hoy);
  final ayer = isoFecha(DateTime(hoy.year, hoy.month, hoy.day - 1));

  ResumenNutricion resumen() => ResumenNutricion(
    desde: ayer,
    hasta: iso,
    perfil: const PerfilNutricion(
      miembroId: 1,
      nombre: 'Socio de prueba',
      edad: 24,
      alturaCm: 165,
      sexo: 'F',
      objetivo: 'perder',
      actividad: 3,
      peso: 80.9,
      imc: 29.7,
    ),
    metas: const [
      MetaNutricion(clave: 'kcal', cantidad: 1933, regla: 'rango', origen: 'auto'),
      MetaNutricion(clave: 'proteina', cantidad: 162, regla: 'minimo', origen: 'auto'),
      MetaNutricion(clave: 'grasa', cantidad: 54, regla: 'maximo', origen: 'personal'),
      MetaNutricion(clave: 'carbohidrato', cantidad: 180, regla: 'rango', origen: 'auto'),
    ],
    plan: PlanNutricion(
      nombre: 'Definición con un nombre de plan bastante largo',
      notas: 'Toma 2 litros de agua al día y evita las frituras entre semana.',
      items: [
        for (final (i, t) in ['desayuno', 'almuerzo', 'cena', 'aperitivo'].indexed)
          ItemPlan(id: 10 + i, tiempo: t, cantidadG: 225, alimento: i.isEven ? pollo : arroz),
      ],
    ),
    consumos: [
      Consumo(uid: 'a', fecha: iso, tiempo: 'desayuno', cantidadG: 300, planItemId: 10, alimento: pollo),
      Consumo(uid: 'b', fecha: iso, tiempo: 'almuerzo', cantidadG: 300, alimento: salchipapa),
      Consumo(uid: 'c', fecha: ayer, tiempo: 'cena', cantidadG: 150, alimento: arroz),
    ],
    dias: [
      DiaNutricion(
        fecha: ayer,
        registros: 1,
        totales: const {'kcal': 1890, 'proteina': 170, 'grasa': 40, 'carbohidrato': 170},
        cumple: const {'proteina': true, 'grasa': true, 'kcal': true},
        cumpleDia: true,
      ),
      DiaNutricion(
        fecha: iso,
        registros: 2,
        totales: const {'kcal': 1335, 'proteina': 114, 'grasa': 61, 'carbohidrato': 75},
        cumple: const {'proteina': false, 'grasa': false},
        cumpleDia: false,
      ),
    ],
    racha: const RachaNutricion(actual: 1, mejor: 6, diasCumplidos: 12, diasConRegistro: 20),
  );

  final pantallas = <String, Widget Function(ControladorNutricion)>{
    'Mi diario': (c) => DiarioNutricionScreen(controlador: c),
    'Mi plan': (c) => PlanNutricionScreen(controlador: c),
    'Mis metas': (c) => MetasNutricionScreen(controlador: c),
    'Mi progreso': (c) => ProgresoNutricionScreen(controlador: c),
  };

  for (final MapEntry(key: nombre, value: crear) in pantallas.entries) {
    for (final ancho in [320.0, 360.0]) {
      for (final escala in [1.0, 1.3, 1.5]) {
        testWidgets('$nombre · $ancho px · letra $escala', (t) async {
          t.view.physicalSize = Size(ancho * 3, 4000 * 3);
          t.view.devicePixelRatio = 3;
          addTearDown(t.view.reset);
          final c = ControladorNutricion()..resumen = resumen();
          addTearDown(c.dispose);
          await t.pumpWidget(
            MaterialApp(
              home: MediaQuery(
                data: MediaQueryData(
                  size: Size(ancho, 4000),
                  textScaler: TextScaler.linear(escala),
                ),
                child: crear(c),
              ),
            ),
          );
          await t.pump();
          expect(t.takeException(), isNull);
        });
      }
    }
  }
}
