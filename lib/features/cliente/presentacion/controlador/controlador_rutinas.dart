import 'package:xnox_app/features/cliente/datos/almacen_rutinas.dart';
import 'package:xnox_app/features/cliente/datos/repositorio_rutinas_remoto.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';

/// Orquesta las rutinas del cliente sobre el almacén SQLite y la sincronización
/// con el backend (rutinas sugeridas del administrador).
class ControladorRutinas {
  final AlmacenRutinas _almacen = AlmacenRutinas.instancia;
  final RepositorioRutinasRemoto _remoto = RepositorioRutinasRemoto();

  // -------------------------------------------------------- Lecturas (caché)
  List<Rutina> obtenerRutinas() => _almacen.rutinas;
  List<Rutina> obtenerSugeridas() => _almacen.rutinasSugeridas;

  /// Rutinas que el gimnasio armó para este cliente.
  List<Rutina> obtenerAsignadas() => _almacen.rutinasAsignadas;
  List<Rutina> obtenerMisRutinas() => _almacen.rutinasCliente;
  List<Ejercicio> obtenerTodosLosEjercicios() => _almacen.todosLosEjercicios;
  Rutina? obtenerRutina(int id) => _almacen.buscarRutina(id);

  /// Garantiza que la caché esté cargada desde SQLite.
  Future<void> asegurarCargado() => _almacen.asegurarCargado();

  /// Flujo de apertura: carga SQLite y, si hay conexión, sincroniza las
  /// rutinas sugeridas del backend. Sin Internet, se queda con SQLite.
  Future<void> sincronizar() async {
    await _almacen.asegurarCargado();
    final remotas = await _remoto.obtenerSugeridas();
    if (remotas.isNotEmpty) {
      await _almacen.sincronizarSugeridas(remotas);
    }
  }

  // ------------------------------------------------ Mutaciones (solo cliente)
  Future<int> crearRutina(String nombre, String descripcion) =>
      _almacen.crearRutina(nombre, descripcion);

  Future<void> editarRutina(int id, String nombre, String descripcion) =>
      _almacen.editarRutina(id, nombre, descripcion);

  Future<void> eliminarRutina(int id) => _almacen.eliminarRutina(id);

  Future<int> agregarDia(int rutinaId, String diaSemana) =>
      _almacen.agregarDia(rutinaId, diaSemana);

  Future<void> eliminarDia(int diaId) => _almacen.eliminarDia(diaId);

  Future<void> agregarEjercicio(
    int diaId,
    String nombre,
    int series,
    int repeticiones, {
    String? observaciones,
    int? catalogoId,
    String? imagenUrl,
    String? videoUrl,
  }) =>
      _almacen.agregarEjercicio(diaId, nombre, series, repeticiones,
          observaciones: observaciones,
          catalogoId: catalogoId,
          imagenUrl: imagenUrl,
          videoUrl: videoUrl);

  Future<void> eliminarEjercicio(int ejercicioId) =>
      _almacen.eliminarEjercicio(ejercicioId);

  /// Registra una marca de progreso (peso + reps por serie) en un ejercicio.
  Future<void> registrarMarca(
          int ejercicioId, double peso, List<int> repsPorSerie) =>
      _almacen.agregarMarca(ejercicioId, peso, repsPorSerie);

  // ----------------------------------- Registro serie por serie (sesión hoy)

  /// Agrega una serie a la sesión de hoy; devuelve el id de la sesión.
  Future<int> agregarSerie(int ejercicioId, double peso, int reps) =>
      _almacen.agregarSerie(ejercicioId, peso, reps);

  Future<void> editarSerie(int marcaId, int numero, int reps) =>
      _almacen.editarSerie(marcaId, numero, reps);

  Future<void> eliminarSerie(int marcaId, int numero) =>
      _almacen.eliminarSerie(marcaId, numero);

  Future<void> editarPesoSesion(int marcaId, double peso) =>
      _almacen.editarPesoSesion(marcaId, peso);
}
