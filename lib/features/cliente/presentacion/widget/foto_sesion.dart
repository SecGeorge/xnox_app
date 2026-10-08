import 'package:flutter/widgets.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/dia_rutina.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';

/// Foto de portada de una sesión según lo que se entrena: un día de piernas
/// muestra a alguien haciendo piernas, uno de espalda una dominada, etc.
class FotoSesion {
  final String ruta;

  /// Encuadre de la foto dentro de la tarjeta (dónde está la persona).
  final Alignment alineacion;

  const FotoSesion._(this.ruta, this.alineacion);

  static const _base = 'assets/imagenes/sesiones';

  static const piernas = FotoSesion._(
    '$_base/piernas.jpg',
    Alignment(0.2, -0.2),
  );
  static const gluteos = FotoSesion._(
    '$_base/gluteos.jpg',
    Alignment(0.0, 0.3),
  );
  static const pecho = FotoSesion._('$_base/pecho.jpg', Alignment(0.4, -0.3));
  static const espalda = FotoSesion._(
    '$_base/espalda.jpg',
    Alignment(0.0, -0.5),
  );
  static const hombros = FotoSesion._(
    '$_base/hombros.jpg',
    Alignment(0.3, -0.4),
  );
  static const brazos = FotoSesion._('$_base/brazos.jpg', Alignment(0.6, -0.4));
  static const core = FotoSesion._('$_base/core.jpg', Alignment(0.3, 0.2));
  static const descanso = FotoSesion._(
    '$_base/descanso.jpg',
    Alignment(0.2, 0.0),
  );
  static const general = FotoSesion._(
    'assets/imagenes/inicio/rutina_hoy.jpg',
    Alignment(0.6, -0.4),
  );

  /// Grupos que se reconocen (sin tildes, en minúsculas). Si dos palabras
  /// aparecen en la misma posición gana la que va antes en la lista: por eso
  /// "curl femoral" va antes que el "curl" de bíceps.
  static const _grupos = <_Grupo>[
    _Grupo('Glúteos', gluteos, [
      'glute',
      'hip t',
      'peso muerto',
      'cadena posterior',
    ]),
    _Grupo('Femoral', gluteos, ['curl femoral', 'femoral']),
    _Grupo('Piernas', piernas, [
      'pierna',
      'cuadricep',
      'sentadilla',
      'prensa',
      'zancada',
      'bulgara',
      'pantorrilla',
      'gemelo',
      'talon',
      'tren inferior',
    ]),
    _Grupo('Espalda', espalda, [
      'espalda',
      'jalon',
      'remo',
      'dominada',
      'traccion',
    ]),
    _Grupo('Pecho', pecho, [
      'pecho',
      'banca',
      'flexion',
      'pectoral',
      'apertura',
    ]),
    _Grupo('Hombros', hombros, ['hombro', 'militar', 'lateral', 'deltoide']),
    _Grupo('Bíceps', brazos, ['bicep', 'curl']),
    _Grupo('Tríceps', brazos, ['tricep', 'fondos']),
    _Grupo('Core', core, [
      'abdomen',
      'abdominal',
      'core',
      'plancha',
      'crunch',
      'oblicuo',
    ]),
  ];

  static String _normalizar(String t) => t
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u');

  /// El grupo cuya palabra aparece primero en [texto] ("Hombros y Core" es de
  /// hombros). Null si no hay ninguna.
  static _Grupo? _grupoDe(String texto) {
    final t = _normalizar(texto);
    _Grupo? mejor;
    var posicion = 1 << 30;
    for (final g in _grupos) {
      for (final p in g.palabras) {
        final i = t.indexOf(p);
        if (i >= 0 && i < posicion) {
          posicion = i;
          mejor = g;
        }
      }
    }
    return mejor;
  }

  /// Grupos del día ordenados por cuántos ejercicios tienen (empate: el que
  /// aparece primero en la rutina).
  static List<_Grupo> _gruposDelDia(DiaRutina dia) {
    final conteo = <_Grupo, int>{};
    for (final e in dia.ejercicios) {
      final g = _grupoDe(e.nombre);
      if (g != null) conteo[g] = (conteo[g] ?? 0) + 1;
    }
    final orden = conteo.keys.toList(); // orden de aparición
    // sort es estable en Dart: los empates conservan el orden de aparición.
    orden.sort((a, b) => conteo[b]!.compareTo(conteo[a]!));
    return orden;
  }

  /// Una rutina semanal tiene varios días con objetivos distintos: cada día se
  /// juzga por sus ejercicios, no por el nombre de la rutina.
  static bool _esSemanal(Rutina r) => r.dias.length > 1;

  /// Foto para el día [dia] de [rutina].
  static FotoSesion para(Rutina rutina, [DiaRutina? dia]) {
    if (!_esSemanal(rutina) || dia == null) {
      final porNombre = _grupoDe(rutina.nombre);
      if (porNombre != null) return porNombre.foto;
    }
    if (dia != null) {
      final grupos = _gruposDelDia(dia);
      if (grupos.isNotEmpty) return grupos.first.foto;
    }
    return general;
  }

  /// Título del día: en una rutina semanal, lo que se entrena ese día
  /// ("Espalda y Bíceps"); en una de un solo día, el nombre de la rutina.
  static String titulo(Rutina rutina, DiaRutina dia) {
    if (!_esSemanal(rutina)) return rutina.nombre;
    final grupos = _gruposDelDia(dia);
    if (grupos.isEmpty) return rutina.nombre;
    if (grupos.length == 1) return grupos.first.nombre;
    return '${grupos[0].nombre} y ${grupos[1].nombre}';
  }

  /// En una rutina semanal el nombre de la rutina pasa a ser el subtítulo.
  static String? subtitulo(Rutina rutina, DiaRutina dia) {
    if (!_esSemanal(rutina)) return null;
    return titulo(rutina, dia) == rutina.nombre ? null : rutina.nombre;
  }
}

class _Grupo {
  final String nombre;
  final FotoSesion foto;
  final List<String> palabras;

  const _Grupo(this.nombre, this.foto, this.palabras);
}
