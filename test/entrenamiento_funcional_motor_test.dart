import 'package:flutter_test/flutter_test.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

// Mismos casos que tests/rutinas/pruebas_rutinas_funcionales.php del sistema
// web: los tres motores (PHP, JS y Dart) deben dar la misma duración.

PlanEjercicio ej(String n, {int? t, int? d, int r = 0, int s = 0}) =>
    PlanEjercicio(nombre: n, trabajoSeg: t, descansoSeg: d, repeticiones: r, series: s);

final circuitoEjemplo = PlanBloque(
  tipo: 'CIRCUITO',
  diaSemana: 'Lunes',
  nombre: 'Circuito A',
  rondas: 3,
  descansoRondaSeg: 60,
  ejercicios: [
    ej('Sentadillas', t: 30, d: 15),
    ej('Flexiones', t: 30, d: 15),
    ej('Jumping jacks', t: 30, d: 15),
    ej('Plancha abdominal', t: 30),
  ],
);

void main() {
  test('circuito del ejemplo: 4 x 30 s, 15 s, 60 s entre rondas, 3 rondas = 615 s', () {
    final plan = PlanRutina(nombre: 'x', bloques: [circuitoEjemplo]);
    expect(MotorRutina.duracionEstimada(plan), 615);
    final pasos = MotorRutina.expandirDia(plan.bloques);
    // 12 trabajos + 9 descansos + 2 descansos entre rondas
    expect(pasos.length, 23);
    expect(pasos.where((p) => p.fase == FasePaso.descansoRonda).length, 2);
    expect(pasos.last.fase, FasePaso.trabajo); // la última ronda no descansa
  });

  test('varios bloques el mismo día y tipos distintos en la semana', () {
    final plan = PlanRutina(
      nombre: 'Semana',
      bloques: [
        PlanBloque(
          tipo: 'HIIT',
          diaSemana: 'Lunes',
          rondas: 2,
          descansoBloqueSeg: 60,
          ejercicios: [ej('Skipping', t: 20, d: 10), ej('Burpees', t: 20)],
        ),
        circuitoEjemplo,
        PlanBloque(
          diaSemana: 'Martes',
          ejercicios: [ej('Press banca', s: 4, r: 10, d: 90)],
        ),
        PlanBloque(
          tipo: 'AMRAP',
          diaSemana: 'Jueves',
          tiempoLimiteSeg: 600,
          ejercicios: [ej('Pull ups', r: 5)],
        ),
      ],
    );
    expect(plan.tipo, 'MIXTO');
    expect(plan.sesiones.map((s) => s.dia), ['Lunes', 'Martes', 'Jueves']);
    // Lunes: HIIT 100 + 60 de descanso + circuito 615
    expect(plan.sesiones.first.duracion, 775);
    // Martes: 4 x (30 + 90) - 90
    expect(plan.sesiones[1].duracion, 390);
    expect(MotorRutina.duracionEstimada(plan), 775);
    expect(MotorRutina.validar(plan), isNull);
  });

  test('EMOM de 10 minutos turna los ejercicios minuto a minuto', () {
    final plan = PlanRutina(
      nombre: 'x',
      bloques: [
        PlanBloque(
          tipo: 'EMOM',
          tiempoLimiteSeg: 600,
          intervaloSeg: 60,
          ejercicios: [ej('Burpees', r: 10), ej('Swing', r: 15)],
        ),
      ],
    );
    final pasos = MotorRutina.expandirDia(plan.bloques);
    expect(MotorRutina.duracionEstimada(plan), 600);
    expect(pasos.length, 10);
    expect(pasos[1].ejercicio!.nombre, 'Swing');
    expect(pasos[2].ronda, 2);
  });

  test('validaciones como en el backend', () {
    PlanRutina con(PlanBloque b) => PlanRutina(nombre: 'x', bloques: [b]);
    expect(
      MotorRutina.validar(con(PlanBloque(tipo: 'AMRAP', ejercicios: [ej('X', r: 5)]))),
      contains('tiempo límite'),
    );
    expect(
      MotorRutina.validar(con(PlanBloque(tipo: 'HIIT', rondas: 3, ejercicios: [ej('X', r: 5)]))),
      contains('tiempo de trabajo'),
    );
    expect(
      MotorRutina.validar(con(PlanBloque(tipo: 'CIRCUITO', rondas: 3, ejercicios: [ej('X')]))),
      isNotNull,
    );
    expect(
      MotorRutina.validar(
        con(PlanBloque(tipo: 'EMOM', intervaloSeg: 60, ejercicios: [ej('X', t: 90)])),
      ),
      contains('intervalo'),
    );
  });

  test('el JSON del entrenador manda el tipo de cada bloque ordenado por semana', () {
    final r = RutinaAdmin(
      nombre: 'x',
      dias: [
        DiaAdmin.nuevo('Martes', 'MUSCULACION')..ejercicios.add(EjercicioAdmin(nombre: 'Remo', series: 3, repeticiones: 10)),
        DiaAdmin.nuevo('Lunes', 'HIIT')..ejercicios.add(EjercicioAdmin(nombre: 'Burpees', trabajoSeg: 30)),
        DiaAdmin.nuevo('Lunes', 'CIRCUITO')..ejercicios.add(EjercicioAdmin(nombre: 'Sentadillas', trabajoSeg: 30)),
      ],
    );
    final json = r.toJson();
    expect(json['tipo'], 'MIXTO');
    final dias = json['dias'] as List;
    expect([for (final d in dias) '${d['dia_semana']}-${d['tipo']}'], [
      'Lunes-HIIT',
      'Lunes-CIRCUITO',
      'Martes-MUSCULACION',
    ]);
  });
}
