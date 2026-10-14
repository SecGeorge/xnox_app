import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/composicion_corporal.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/composicion_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/medidas_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/seguimiento/dominio/seguimiento.dart';
import 'package:xnox_app/features/seguimiento/presentacion/screen/ejercicio_socio_screen.dart';
import 'package:xnox_app/features/seguimiento/presentacion/screen/entrenamiento_socio_screen.dart';

/// IMC, peso ideal y la ficha del socio que ve el personal.
void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('IMC', () {
    test('clasifica en los 6 niveles de la OMS', () {
      expect(NivelImc.de(17), NivelImc.bajoPeso);
      expect(NivelImc.de(18.5), NivelImc.normal);
      expect(NivelImc.de(24.9), NivelImc.normal);
      expect(NivelImc.de(25), NivelImc.sobrepeso);
      expect(NivelImc.de(30), NivelImc.obesidad1);
      expect(NivelImc.de(35.2), NivelImc.obesidad2);
      expect(NivelImc.de(41), NivelImc.obesidad3);
    });

    test('IMC, peso ideal y kilos para el rango saludable', () {
      final c = ComposicionCorporal.calcular(pesoKg: 90, alturaCm: 170)!;
      expect(c.imc, 31.1);
      expect(c.nivel, NivelImc.obesidad1);
      expect(c.pesoIdeal, 63.6);
      expect(c.pesoMinSaludable, 53.5);
      expect(c.pesoMaxSaludable, 72);
      expect(c.kilosParaSaludable, -18);
      expect(c.consejoPeso(), 'Te sobran 18 kg para un peso saludable');
      expect(c.consejoPeso(propio: false), startsWith('Le sobran'));
      expect(c.puedeEstimarMusculo, isFalse);
      expect(c.grasaPct, isNull);
    });

    test('masa muscular con edad y sexo', () {
      final c = ComposicionCorporal.calcular(
        pesoKg: 75,
        alturaCm: 175,
        edad: 30,
        sexo: 'M',
      )!;
      // Deurenberg: 1.2 × 24.49 + 0.23 × 30 − 10.8 − 5.4 = 20.1 %.
      expect(c.grasaPct, 20.1);
      expect(c.masaMagraKg, 59.9);
      expect(c.indiceMasaMuscular, 19.6);
      expect(c.nivelMusculo!.nombre, 'Normal');
    });

    test('sin altura o sin peso no calcula', () {
      expect(ComposicionCorporal.calcular(pesoKg: 70), isNull);
      expect(ComposicionCorporal.calcular(alturaCm: 170), isNull);
    });
  });

  final ahora = DateTime.now();
  final socio = SeguimientoSocio.desdeJson({
    'socio': {
      'miembro_id': 7,
      'nombre': 'María Fernanda Quispe Huamán',
      'codigo': 'S-0007',
      'fecha_nacimiento': '1995-04-02',
    },
    'sesiones': [
      for (var i = 0; i < 6; i++)
        {
          'uid': 's$i',
          'fecha': ahora.subtract(Duration(days: i * 3)).toIso8601String(),
          'rutina_nombre': 'Rutina de hipertrofia de tren superior',
          'ejercicio_nombre': i.isEven
              ? 'Press de banca con barra'
              : 'Sentadilla libre',
          'peso': 40,
          'repeticiones': 30,
          'series': [
            {'numero': 1, 'repeticiones': 12, 'peso': 40 - i * 2},
            {'numero': 2, 'repeticiones': 10, 'peso': 45 - i * 2},
            {
              'numero': 3,
              'repeticiones': 16,
              'peso': 50 - i * 2,
              'reps_izq': 8,
              'reps_der': 8,
            },
          ],
        },
    ],
    'medidas': [
      {'zona': 'peso', 'valor': 80, 'fecha': '2026-08-01 08:00:00'},
      {'zona': 'peso', 'valor': 76.5, 'fecha': '2026-10-01 08:00:00'},
      {'zona': 'biceps_der', 'valor': 33, 'fecha': '2026-08-01 08:00:00'},
      {'zona': 'biceps_der', 'valor': 35, 'fecha': '2026-10-01 08:00:00'},
      {'zona': 'cintura', 'valor': 90, 'fecha': '2026-08-01 08:00:00'},
      {'zona': 'cintura', 'valor': 86, 'fecha': '2026-10-01 08:00:00'},
    ],
  });

  group('Seguimiento', () {
    test('agrupa ejercicios y calcula mejoras', () {
      final e = socio.ejercicios;
      expect(e.length, 2);
      final banca = e.firstWhere((x) => x.nombre.startsWith('Press'));
      expect(banca.sesiones.length, 3);
      expect(banca.mejorPeso, 50);
      expect(banca.mejora, 8); // 42 → 50
      expect(socio.pesoActual, 76.5);
      expect(socio.cambiosMedidas.length, 3);
      expect(socio.edad, isNotNull);
      expect(socio.sesiones.first.seriesTexto, contains('I8/D8'));
    });
  });

  Future<void> dibujar(WidgetTester t, Widget pantalla) async {
    t.view.physicalSize = const Size(320 * 3, 1800 * 3);
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
    await t.pump(const Duration(seconds: 1));
  }

  testWidgets('IMC en pantalla angosta con letra grande', (t) async {
    await dibujar(
      t,
      ComposicionScreen(
        composicion: ComposicionCorporal.calcular(
          pesoKg: 98,
          alturaCm: 165,
          edad: 34,
          sexo: 'F',
        )!,
        pesos: [
          PuntoEvolucion(DateTime(2026, 8, 1), 101),
          PuntoEvolucion(DateTime(2026, 9, 1), 98),
        ],
        propio: false,
        nombre: 'María Fernanda',
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.textContaining('Obesidad II'), findsWidgets);
  });

  testWidgets('IMC sin sexo pide completar datos', (t) async {
    await dibujar(
      t,
      ComposicionScreen(
        composicion: ComposicionCorporal.calcular(pesoKg: 60, alturaCm: 170)!,
        onCompletarDatos: () {},
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Completar datos'), findsOneWidget);
  });

  testWidgets('entrenamiento del socio en ambas pestañas', (t) async {
    await dibujar(t, EntrenamientoSocioScreen(socio: socio));
    expect(t.takeException(), isNull);
    expect(find.text('Press de banca con barra'), findsOneWidget);
    await t.tap(find.text('Por día'));
    await t.pump(const Duration(seconds: 1));
    expect(t.takeException(), isNull);
  });

  testWidgets('detalle de un ejercicio con sus series', (t) async {
    await dibujar(
      t,
      EjercicioSocioScreen(
        ejercicio: socio.ejercicios.first,
        nombreSocio: socio.nombre,
      ),
    );
    expect(t.takeException(), isNull);
    expect(find.text('I8/D8 reps'), findsWidgets);
  });

  testWidgets('medidas del socio en solo lectura', (t) async {
    await dibujar(
      t,
      MedidasScreen(medidas: socio.medidas, nombre: socio.nombre),
    );
    expect(t.takeException(), isNull);
    expect(find.text('Sus músculos'), findsOneWidget);
  });
}
