import 'package:xnox_app/features/cliente/datos/almacen_rutinas.dart';
import 'package:xnox_app/features/cliente/datos/repositorio_rutinas_remoto.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
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

  /// Rutina que el socio eligió para entrenar (null = no eligió).
  Rutina? obtenerRutinaActiva() => _almacen.rutinaActiva;

  Future<void> elegirRutinaActiva(int? id) => _almacen.elegirRutinaActiva(id);

  /// Rutinas que cuentan para "lo que toca hoy": solo la elegida o, si no
  /// eligió ninguna, todas en orden de prioridad (las del gimnasio para el
  /// socio, las suyas y las sugeridas).
  List<Rutina> obtenerParaEntrenar() {
    final activa = _almacen.rutinaActiva;
    if (activa != null) return [activa];
    return [
      ..._almacen.rutinasAsignadas,
      ..._almacen.rutinasCliente,
      ..._almacen.rutinasSugeridas,
    ];
  }

  /// Garantiza que la caché esté cargada desde SQLite.
  Future<void> asegurarCargado() => _almacen.asegurarCargado();

  /// Flujo de apertura: carga SQLite y, si hay conexión, sincroniza las
  /// rutinas sugeridas del backend y luego el entrenamiento del socio (sus
  /// rutinas y sesiones; va después para enganchar las sesiones a los
  /// ejercicios del gimnasio ya actualizados). Sin Internet, se queda con
  /// SQLite.
  Future<void> sincronizar() =>
      _sincronizacion ??= _sincronizar().whenComplete(
        () => _sincronizacion = null,
      );

  /// La sincronización en curso: el inicio y Rutinas la comparten en vez de
  /// lanzar cada uno la suya.
  static Future<void>? _sincronizacion;

  Future<void> _sincronizar() async {
    await _almacen.asegurarCargado();
    final remotas = await _remoto.obtenerSugeridas();
    if (remotas.isNotEmpty) {
      await _almacen.sincronizarSugeridas(remotas);
    }
    await _almacen.sincronizarEntrenamiento();
  }

  // ------------------------------------------------ Mutaciones (solo cliente)
  Future<int> crearRutina(String nombre, String descripcion) =>
      _almacen.crearRutina(nombre, descripcion);

  /// Crea o reemplaza una rutina propia armada en el editor de rutinas.
  Future<int> guardarRutinaPropia({
    int? id,
    required String nombre,
    required String descripcion,
    String? objetivo,
    String? nivel,
    required String tipo,
    int? duracionSeg,
    required List<DiaRutina> dias,
  }) => _almacen.guardarRutinaPropia(
    id: id,
    nombre: nombre,
    descripcion: descripcion,
    objetivo: objetivo,
    nivel: nivel,
    tipo: tipo,
    duracionSeg: duracionSeg,
    dias: dias,
  );

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
    bool unilateral = false,
  }) => _almacen.agregarEjercicio(
    diaId,
    nombre,
    series,
    repeticiones,
    observaciones: observaciones,
    catalogoId: catalogoId,
    imagenUrl: imagenUrl,
    videoUrl: videoUrl,
    unilateral: unilateral,
  );

  Future<void> cambiarUnilateral(int ejercicioId, bool unilateral) =>
      _almacen.cambiarUnilateral(ejercicioId, unilateral);

  Future<void> eliminarEjercicio(int ejercicioId) =>
      _almacen.eliminarEjercicio(ejercicioId);

  /// Registra una marca de progreso (peso + reps por serie) en un ejercicio.
  Future<void> registrarMarca(
    int ejercicioId,
    double peso,
    List<int> repsPorSerie,
  ) => _almacen.agregarMarca(ejercicioId, peso, repsPorSerie);

  // ----------------------------------- Registro serie por serie (sesión hoy)

  /// Agrega una serie a la sesión de hoy; devuelve el id de la sesión.
  Future<int> agregarSerie(
    int ejercicioId,
    double peso,
    int reps, {
    int? izq,
    int? der,
  }) => _almacen.agregarSerie(ejercicioId, peso, reps, izq: izq, der: der);

  Future<void> editarSerie(
    int marcaId,
    int numero,
    int reps, {
    int? izq,
    int? der,
  }) => _almacen.editarSerie(marcaId, numero, reps, izq: izq, der: der);

  Future<void> eliminarSerie(int marcaId, int numero) =>
      _almacen.eliminarSerie(marcaId, numero);

  Future<void> editarPesoSerie(int marcaId, int numero, double peso) =>
      _almacen.editarPesoSerie(marcaId, numero, peso);
}
