import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/ejercicio.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/features/rutinas_admin/datos/repositorio_rutinas_admin.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

/// De dónde carga y dónde guarda el editor de rutinas lo que se arma. El
/// mismo editor (igual al del web) sirve al personal, que guarda en el
/// servidor, y al socio, que guarda su rutina en el teléfono y la sincroniza.
abstract class FuenteRutina {
  /// Si es null, el editor crea una rutina nueva.
  int? get rutinaId;

  /// Rutina general (o del socio), para el subtítulo del editor.
  String get descripcion;

  Future<RutinaAdmin?> cargar();

  /// Null si guardó; si no, el mensaje de error.
  Future<String?> guardar(RutinaAdmin rutina);

  /// Restricciones por nivel. Las rutinas propias del socio no tienen.
  Future<List<ReglaNivel>> reglas();
}

/// Rutinas del personal: generales ([miembroId] null) o personalizadas de un
/// socio. Se guardan en rutinas.php.
class FuenteRutinaServidor implements FuenteRutina {
  final int? miembroId;
  @override
  final int? rutinaId;
  final _repo = RepositorioRutinasAdmin();

  FuenteRutinaServidor({this.miembroId, this.rutinaId});

  @override
  String get descripcion =>
      miembroId == null ? 'Rutina general del gimnasio' : 'Rutina semanal del socio';

  @override
  Future<RutinaAdmin?> cargar() async {
    if (rutinaId == null) return RutinaAdmin(miembroId: miembroId);
    final r = await _repo.obtener(rutinaId!);
    // Queda asociada al mismo socio (o general) al guardar.
    r?.miembroId = miembroId;
    return r;
  }

  @override
  Future<String?> guardar(RutinaAdmin rutina) => _repo.guardar(rutina);

  @override
  Future<List<ReglaNivel>> reglas() => _repo.reglasNivel();
}

/// Rutinas propias del socio: viven en SQLite y se sincronizan solas.
class FuenteRutinaLocal implements FuenteRutina {
  @override
  int? rutinaId;
  final _controlador = ControladorRutinas();

  FuenteRutinaLocal({this.rutinaId});

  @override
  String get descripcion => 'Tu rutina de la semana';

  @override
  Future<List<ReglaNivel>> reglas() async => const [];

  @override
  Future<RutinaAdmin?> cargar() async {
    if (rutinaId == null) return RutinaAdmin();
    await _controlador.asegurarCargado();
    final r = _controlador.obtenerRutina(rutinaId!);
    if (r == null) return null;
    return RutinaAdmin(
      id: r.id,
      nombre: r.nombre,
      descripcion: r.descripcion,
      objetivo: r.objetivo,
      nivel: r.nivel,
      dias: [
        for (final d in r.dias)
          DiaAdmin(
            diaSemana: d.diaSemana,
            tipo: d.tipo,
            nombre: d.nombre,
            rondas: d.rondas,
            descansoRondaSeg: d.descansoRondaSeg,
            tiempoLimiteSeg: d.tiempoLimiteSeg,
            intervaloSeg: d.intervaloSeg,
            descansoBloqueSeg: d.descansoBloqueSeg,
            ejercicios: [
              for (final e in d.ejercicios)
                EjercicioAdmin(
                  nombre: e.nombre,
                  series: e.series,
                  repeticiones: e.repeticiones,
                  descansoSeg: e.descansoSeg,
                  trabajoSeg: e.trabajoSeg,
                  pesoKg: e.pesoKg,
                  tempoBajadaSeg: e.tempoBajadaSeg,
                  tempoSubidaSeg: e.tempoSubidaSeg,
                  velocidad: e.velocidad,
                  rpe: e.rpe,
                  observaciones: e.observaciones,
                  catalogoId: e.catalogoId,
                  imagenUrl: e.imagenUrl,
                  videoUrl: e.videoUrl,
                  unilateral: e.unilateral,
                ),
            ],
          ),
      ],
    );
  }

  @override
  Future<String?> guardar(RutinaAdmin rutina) async {
    final plan = rutina.plan;
    // En SQLite los bloques van en el orden de la semana.
    int orden(String d) {
      final i = diasSemana.indexOf(d);
      return i == -1 ? 99 : i;
    }

    final bloques = [
      for (var i = 0; i < rutina.dias.length; i++) (i, rutina.dias[i]),
    ]..sort((a, b) {
        final c = orden(a.$2.diaSemana).compareTo(orden(b.$2.diaSemana));
        return c != 0 ? c : a.$1.compareTo(b.$1);
      });
    try {
      rutinaId = await _controlador.guardarRutinaPropia(
        id: rutinaId,
        nombre: rutina.nombre,
        descripcion: rutina.descripcion,
        objetivo: rutina.objetivo,
        nivel: rutina.nivel,
        tipo: plan.tipo,
        duracionSeg: MotorRutina.duracionEstimada(plan),
        dias: [
          for (final (_, d) in bloques)
            DiaRutina(
              id: 0,
              diaSemana: d.diaSemana,
              tipo: d.tipo,
              nombre: d.nombre,
              rondas: d.rondas,
              descansoRondaSeg: d.descansoRondaSeg,
              tiempoLimiteSeg: d.tiempoLimiteSeg,
              intervaloSeg: d.intervaloSeg,
              descansoBloqueSeg: d.descansoBloqueSeg,
              ejercicios: [
                for (final e in d.ejercicios)
                  Ejercicio(
                    id: 0,
                    nombre: e.nombre,
                    series: e.series,
                    repeticiones: e.repeticiones,
                    observaciones: e.observaciones,
                    catalogoId: e.catalogoId,
                    imagenUrl: e.imagenUrl,
                    videoUrl: e.videoUrl,
                    descansoSeg: e.descansoSeg,
                    trabajoSeg: e.trabajoSeg,
                    pesoKg: e.pesoKg,
                    tempoBajadaSeg: e.tempoBajadaSeg,
                    tempoSubidaSeg: e.tempoSubidaSeg,
                    velocidad: e.velocidad,
                    rpe: e.rpe,
                    unilateral: e.unilateral,
                  ),
              ],
            ),
        ],
      );
      return null;
    } catch (_) {
      return 'No se pudo guardar la rutina en el teléfono';
    }
  }
}
