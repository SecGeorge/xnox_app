import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:xnox_app/features/cliente/datos/repositorio_datos_socio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/datos_socio.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/mis_datos_screen.dart';

class _RepoFalso extends RepositorioDatosSocio {
  _RepoFalso({this.datos = const DatosSocio(), this.error, this.falla = false});

  final DatosSocio datos;
  final String? error;
  final bool falla;
  DatosSocio? guardado;

  @override
  Future<DatosSocio> obtener() async {
    if (falla) throw Exception('sin red');
    return datos;
  }

  @override
  Future<String?> guardar(DatosSocio d) async {
    guardado = d;
    return error;
  }
}

Future<void> _abrir(WidgetTester tester, RepositorioDatosSocio repo) async {
  tester.view.physicalSize = const Size(720, 2400);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: MisDatosScreen(repositorio: repo)));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  group('DatosSocio', () {
    test('lee la respuesta del backend, con vacíos y nulos', () {
      final d = DatosSocio.fromJson({
        'fecha_nacimiento': null,
        'direccion': null,
        'sufreEnfermedad': '1',
        'enfermedad': ' Asma ',
        'tieneSeguro': 0,
        'institucion': '',
        'nombreContacto': 'Ana',
        'telefonoContacto': null,
      });
      expect(d.fechaNacimiento, isNull);
      expect(d.direccion, '');
      expect(d.sufreEnfermedad, isTrue);
      expect(d.enfermedad, 'Asma');
      expect(d.tieneSeguro, isFalse);
      expect(d.telefonoContacto, '');
    });

    test('envía la fecha como la espera el backend', () {
      expect(
        DatosSocio(fechaNacimiento: DateTime(1996, 5, 2))
            .toJson()['fecha_nacimiento'],
        '1996-05-02',
      );
      expect(const DatosSocio().toJson()['fecha_nacimiento'], '');
    });
  });

  testWidgets('muestra lo guardado y lo que cambia el socio', (tester) async {
    final repo = _RepoFalso(
      datos: DatosSocio(
        fechaNacimiento: DateTime(1996, 5, 20),
        direccion: 'Av. Sol 123',
        nombreContacto: 'Ana',
      ),
    );
    await _abrir(tester, repo);
    expect(find.text('20 de mayo de 1996'), findsOneWidget);
    expect(find.text('Av. Sol 123'), findsOneWidget);
    expect(find.text('¿Cuál o cuáles?'), findsNothing);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, '¿Cuál o cuáles?'),
      ' Asma ',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Teléfono'),
      '987654321',
    );
    await tester.tap(find.text('Guardar mis datos'));
    await tester.pump();

    final g = repo.guardado!;
    expect(g.sufreEnfermedad, isTrue);
    expect(g.enfermedad, 'Asma');
    expect(g.telefonoContacto, '987654321');
    expect(g.direccion, 'Av. Sol 123');
    expect(g.fechaNacimiento, DateTime(1996, 5, 20));
    expect(find.text('Tus datos se guardaron'), findsOneWidget);
  });

  testWidgets('se puede quitar la fecha', (tester) async {
    final repo = _RepoFalso(datos: DatosSocio(fechaNacimiento: DateTime(1996)));
    await _abrir(tester, repo);
    await tester.tap(find.byTooltip('Quitar fecha'));
    await tester.pump();
    await tester.tap(find.text('Guardar mis datos'));
    await tester.pump();
    expect(repo.guardado!.fechaNacimiento, isNull);
  });

  testWidgets('avisa el error del servidor', (tester) async {
    await _abrir(tester, _RepoFalso(error: 'Escribe tu seguro'));
    await tester.tap(find.text('Guardar mis datos'));
    await tester.pump();
    expect(find.text('Escribe tu seguro'), findsOneWidget);
  });

  testWidgets('sin datos no deja guardar', (tester) async {
    await _abrir(tester, _RepoFalso(falla: true));
    expect(find.text('No se pudieron cargar tus datos'), findsOneWidget);
    expect(find.text('Guardar mis datos'), findsNothing);
  });
}
