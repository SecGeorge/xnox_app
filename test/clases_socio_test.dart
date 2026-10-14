import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/features/clases/datos/repositorio_clases.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';
import 'package:xnox_app/features/clases/presentacion/screen/clases_screen.dart';

/// Sesión tal como la devuelve clases.php → agenda_socio.
Map<String, dynamic> _json(DateTime fecha, Map<String, dynamic> cambios) => {
  'clase_id': 1,
  'horario_id': 1,
  'fecha': DateFormat('yyyy-MM-dd').format(fecha),
  'hora_inicio': '07:00',
  'hora_fin': '08:00',
  'nombre': 'Zumba',
  'descripcion': 'x',
  'color': '#E11D48',
  'entrenador': null,
  'salon': 'Sala 1',
  'aforo': 10,
  'ocupados': 4,
  'libres': 6,
  'acceso': 2,
  'precio': null,
  'membresias_nombres': '3 meses ',
  'pasada': false,
  'incluida': true,
  'reserva_id': null,
  'reserva_estado': null,
  'reserva_monto': null,
  'puede_cancelar': false,
  'cancelar_horas': 2,
  'motivo': '',
  ...cambios,
};

class _RepoFalso extends RepositorioClases {
  _RepoFalso(this.sesiones);
  List<SesionClase> sesiones;
  int reservas = 0;

  @override
  Future<List<SesionClase>> agenda({DateTime? desde, int dias = 14}) async =>
      sesiones;

  @override
  Future<ResultadoClase> reservar(SesionClase s) async {
    reservas++;
    return const ResultadoClase(true, 'Lugar reservado');
  }
}

void main() {
  setUpAll(() => initializeDateFormatting('es'));

  final manana = DateTime.now().add(const Duration(days: 1));

  test('lee la sesión del backend', () {
    final s = SesionClase.fromJson(
      _json(manana, {
        'reserva_id': 4,
        'reserva_estado': 1,
        'puede_cancelar': true,
      }),
    );
    expect(s.nombre, 'Zumba');
    expect(s.color, const Color(0xFFE11D48));
    expect(s.incluida, isTrue);
    expect(s.reservada, isTrue);
    expect(s.puedeReservar, isFalse);
    expect(s.entrenador, '');
    expect(s.precio, isNull);
    expect(s.inicio.hour, 7);
  });

  test('de pago, llena y con motivo no se puede reservar', () {
    final pago = SesionClase.fromJson(
      _json(manana, {'incluida': false, 'precio': 12.5, 'acceso': 3}),
    );
    expect(pago.puedeReservar, isTrue);
    expect(pago.precio, 12.5);

    final llena = SesionClase.fromJson(
      _json(manana, {'libres': 0, 'ocupados': 10, 'motivo': 'Clase llena'}),
    );
    expect(llena.llena, isTrue);
    expect(llena.puedeReservar, isFalse);
  });

  testWidgets('muestra la clase del día y reserva tras confirmar', (t) async {
    final hoy = DateTime.now();
    // Mañana podría no ser el día abierto: se usa una clase de hoy, más tarde.
    final repo = _RepoFalso([
      SesionClase.fromJson(
        _json(hoy, {
          'hora_inicio': '23:58',
          'hora_fin': '23:59',
          'incluida': false,
          'precio': 15,
          'acceso': 3,
        }),
      ),
    ]);
    await t.pumpWidget(MaterialApp(home: ClasesScreen(repositorio: repo)));
    await t.pumpAndSettle();

    expect(find.text('Zumba'), findsWidgets);
    expect(find.text('6 de 10 cupos libres'), findsOneWidget);
    expect(find.textContaining('15,00'), findsWidgets);

    await t.tap(find.widgetWithText(FilledButton, 'Reservar'));
    await t.pumpAndSettle();
    expect(find.textContaining('no viene en tu membresía'), findsOneWidget);

    await t.tap(find.textContaining('Reservar · pago'));
    await t.pumpAndSettle();
    expect(repo.reservas, 1);
  });
}
