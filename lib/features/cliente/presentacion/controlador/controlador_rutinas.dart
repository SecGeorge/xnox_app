import 'package:xnox_app/features/cliente/datos/almacen_rutinas.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';

/// Orquesta las rutinas del cliente sobre el almacén en memoria.
class ControladorRutinas {
  final AlmacenRutinas _almacen = AlmacenRutinas.instancia;

  List<Rutina> obtenerRutinas() => _almacen.rutinas;

  List<Ejercicio> obtenerTodosLosEjercicios() => _almacen.todosLosEjercicios;

  Rutina? obtenerRutina(int id) => _almacen.buscarRutina(id);

  void crearRutina(String nombre, String dia) =>
      _almacen.agregarRutina(nombre, dia);

  void agregarEjercicio(int rutinaId, String nombre, int series, int reps) =>
      _almacen.agregarEjercicio(rutinaId, nombre, series, reps);

  void registrarMarca(int ejercicioId, double peso, int reps) =>
      _almacen.agregarMarca(ejercicioId, peso, reps);
}
