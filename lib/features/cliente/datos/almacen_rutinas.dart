import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/marca.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';

/// Almacén en memoria de las rutinas del cliente.
///
/// Mantiene el estado mientras la app está abierta. Sembrado con datos demo.
/// TODO: reemplazar por un repositorio conectado a la base de datos/backend.
class AlmacenRutinas {
  AlmacenRutinas._interno();
  static final AlmacenRutinas instancia = AlmacenRutinas._interno();

  int _siguienteIdRutina = 100;
  int _siguienteIdEjercicio = 1000;

  final List<Rutina> _rutinas = _datosDemo();

  List<Rutina> get rutinas => List.unmodifiable(_rutinas);

  Rutina? buscarRutina(int id) {
    for (final r in _rutinas) {
      if (r.id == id) return r;
    }
    return null;
  }

  Rutina agregarRutina(String nombre, String dia) {
    final rutina = Rutina(id: _siguienteIdRutina++, nombre: nombre, dia: dia);
    _rutinas.add(rutina);
    return rutina;
  }

  void agregarEjercicio(
    int rutinaId,
    String nombre,
    int series,
    int repeticiones,
  ) {
    final rutina = buscarRutina(rutinaId);
    if (rutina == null) return;
    rutina.ejercicios.add(Ejercicio(
      id: _siguienteIdEjercicio++,
      nombre: nombre,
      series: series,
      repeticiones: repeticiones,
    ));
  }

  void agregarMarca(int ejercicioId, double peso, int repeticiones) {
    for (final rutina in _rutinas) {
      for (final ej in rutina.ejercicios) {
        if (ej.id == ejercicioId) {
          ej.marcas.add(Marca(
            fecha: DateTime.now(),
            peso: peso,
            repeticiones: repeticiones,
          ));
          return;
        }
      }
    }
  }

  /// Todos los ejercicios de todas las rutinas (para el reporte).
  List<Ejercicio> get todosLosEjercicios =>
      [for (final r in _rutinas) ...r.ejercicios];

  // -------------------------------------------------------------- Datos demo
  static List<Rutina> _datosDemo() {
    Marca m(int diasAtras, double peso, [int reps = 8]) => Marca(
          fecha: DateTime.now().subtract(Duration(days: diasAtras)),
          peso: peso,
          repeticiones: reps,
        );

    return [
      Rutina(
        id: 1,
        nombre: 'Push',
        dia: 'Lunes — Pecho y tríceps',
        ejercicios: [
          Ejercicio(
            id: 1,
            nombre: 'Press banca',
            series: 4,
            repeticiones: 8,
            marcas: [m(28, 50), m(21, 55), m(14, 57.5), m(7, 60)],
          ),
          Ejercicio(
            id: 2,
            nombre: 'Press inclinado mancuernas',
            series: 3,
            repeticiones: 10,
            marcas: [m(21, 20), m(7, 22.5)],
          ),
          Ejercicio(
            id: 3,
            nombre: 'Fondos en paralelas',
            series: 3,
            repeticiones: 12,
            marcas: [m(14, 0, 12), m(5, 5, 10)],
          ),
        ],
      ),
      Rutina(
        id: 2,
        nombre: 'Pull',
        dia: 'Miércoles — Espalda y bíceps',
        ejercicios: [
          Ejercicio(
            id: 4,
            nombre: 'Dominadas',
            series: 4,
            repeticiones: 8,
            marcas: [m(20, 0, 6), m(6, 5, 8)],
          ),
          Ejercicio(
            id: 5,
            nombre: 'Remo con barra',
            series: 4,
            repeticiones: 10,
            marcas: [m(24, 40), m(10, 45)],
          ),
        ],
      ),
      Rutina(
        id: 3,
        nombre: 'Legs',
        dia: 'Viernes — Piernas',
        ejercicios: [
          Ejercicio(
            id: 6,
            nombre: 'Sentadilla',
            series: 5,
            repeticiones: 6,
            marcas: [m(30, 60), m(20, 70), m(10, 80), m(3, 85)],
          ),
        ],
      ),
    ];
  }
}
