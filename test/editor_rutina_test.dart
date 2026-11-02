import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/fuente_rutina.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/form_rutina_admin_screen.dart';

/// Fuente en memoria: el editor se prueba sin servidor ni SQLite.
class _FuenteFalsa implements FuenteRutina {
  final RutinaAdmin inicial;
  RutinaAdmin? guardada;

  _FuenteFalsa(this.inicial);

  @override
  int? get rutinaId => inicial.id;

  @override
  String get descripcion => 'Prueba';

  @override
  Future<RutinaAdmin?> cargar() async => inicial;

  @override
  Future<String?> guardar(RutinaAdmin rutina) async {
    guardada = rutina;
    return null;
  }

  @override
  Future<List<ReglaNivel>> reglas() async => const [];
}

RutinaAdmin _rutinaEjemplo() => RutinaAdmin(
  id: 1,
  nombre: 'Rutina mujeres',
  dias: [
    DiaAdmin(
      diaSemana: 'Lunes',
      ejercicios: [
        EjercicioAdmin(
          nombre: 'Sentadilla hack',
          series: 4,
          repeticiones: 15,
          descansoSeg: 120,
          tempoBajadaSeg: 2,
          tempoSubidaSeg: 1,
          velocidad: 'LENTO',
        ),
      ],
    ),
    DiaAdmin.nuevo('Martes', 'CIRCUITO')
      ..ejercicios.add(EjercicioAdmin(nombre: 'Volteo de neumático', trabajoSeg: 30, descansoSeg: 15)),
  ],
);

Future<void> _abrir(WidgetTester tester, FuenteRutina fuente) async {
  // Ancho de un teléfono como el Z2472 (360 dp) y muy alto, para que la
  // lista dibuje todo el editor y se detecte cualquier desborde.
  tester.view.physicalSize = const Size(720, 9000);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: FormRutinaAdminScreen(fuente: fuente)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('el editor muestra los mismos datos que el web sin desbordarse', (tester) async {
    await _abrir(tester, _FuenteFalsa(_rutinaEjemplo()));
    expect(tester.takeException(), isNull);

    expect(find.text('Datos de la rutina'), findsOneWidget);
    expect(find.text('Semana de entrenamiento'), findsOneWidget);
    for (final n in ['Principiante', 'Intermedio', 'Avanzado']) {
      expect(find.text(n), findsOneWidget);
    }
    // Ejercicio del lunes con grupo, tempo y velocidad a la vista.
    expect(find.text('Sentadilla hack'), findsOneWidget);
    for (final e in ['GRUPO MUSCULAR', 'SERIES', 'REPS', 'PESO', 'DESCANSO', 'TEMPO', 'VELOCIDAD', 'OBSERVACIONES']) {
      expect(find.text(e), findsWidgets, reason: e);
    }
    expect(find.text('Lento'), findsOneWidget);

    // Martes: el circuito muestra sus reglas y "Aplicar a todos".
    await tester.tap(find.text('Mar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Volteo de neumático'), findsOneWidget);
    expect(find.text('Aplicar a todos'), findsOneWidget);
  });

  testWidgets('agrega un bloque HIIT y guarda sin perder el tempo', (tester) async {
    final fuente = _FuenteFalsa(_rutinaEjemplo());
    await _abrir(tester, fuente);

    await tester.tap(find.text('HIIT').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // El bloque nuevo no tiene ejercicio con nombre: al guardar se descarta.
    await tester.tap(find.text('Guardar rutina'));
    await tester.pumpAndSettle();
    final r = fuente.guardada!;
    expect(r.dias.length, 2);
    final hack = r.dias.first.ejercicios.first;
    expect(hack.tempoBajadaSeg, 2);
    expect(hack.velocidad, 'LENTO');
  });
}
