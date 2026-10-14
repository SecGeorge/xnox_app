import 'package:flutter/foundation.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';

/// Estado de Nutrición del socio, compartido por el inicio de Nutrición y sus
/// pantallas (diario, plan, metas, progreso): todas leen el mismo resumen y,
/// tras guardar algo, se recarga una sola vez para todas.
class ControladorNutricion extends ChangeNotifier {
  final _repo = RepositorioNutricion();

  ResumenNutricion? resumen;
  String? error;
  bool cargando = false;

  /// Se piden 90 días (el backend acepta hasta 92): el calendario del diario
  /// deja elegir cualquiera de ellos.
  static const diasHistorial = 90;

  /// Primer día cargado.
  static DateTime get desde {
    final hoy = DateTime.now();
    return DateTime(hoy.year, hoy.month, hoy.day - (diasHistorial - 1));
  }

  Future<void> cargar() async {
    cargando = resumen == null;
    error = null;
    notifyListeners();
    try {
      final hoy = DateTime.now();
      resumen = await _repo.resumen(
        desde: DateTime(hoy.year, hoy.month, hoy.day - (diasHistorial - 1)),
        hasta: hoy,
      );
    } catch (e) {
      error = '$e';
    }
    cargando = false;
    notifyListeners();
  }

  /// Ejecuta un guardado y recarga. Devuelve el error (o null si salió bien).
  Future<String?> _guardar(Future<void> Function() accion) async {
    try {
      await accion();
    } catch (e) {
      return '$e';
    }
    await cargar();
    return null;
  }

  Future<String?> agregar(DateTime dia, EleccionAlimentoDatos e) => _guardar(
    () => _repo.guardarConsumo(
      fecha: dia,
      tiempo: e.tiempo,
      alimentoId: e.alimentoId,
      cantidadG: e.gramos,
    ),
  );

  Future<String?> editar(Consumo c, String tiempo, double gramos) => _guardar(
    () => _repo.guardarConsumo(
      uid: c.uid,
      fecha: DateTime.parse(c.fecha),
      tiempo: tiempo,
      alimentoId: c.alimento.id,
      cantidadG: gramos,
      planItemId: c.planItemId,
    ),
  );

  Future<String?> eliminar(Consumo c) =>
      _guardar(() => _repo.eliminarConsumo(c.uid));

  Future<String?> comiDelPlan(DateTime dia, ItemPlan i) => _guardar(
    () => _repo.guardarConsumo(
      fecha: dia,
      tiempo: i.tiempo,
      alimentoId: i.alimento.id,
      cantidadG: i.cantidadG,
      planItemId: i.id,
    ),
  );
}

/// Lo mínimo para registrar una comida (sin depender de la capa de widgets).
class EleccionAlimentoDatos {
  final int alimentoId;
  final String tiempo;
  final double gramos;

  const EleccionAlimentoDatos(this.alimentoId, this.tiempo, this.gramos);
}
