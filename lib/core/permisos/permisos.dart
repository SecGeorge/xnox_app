import 'package:shared_preferences/shared_preferences.dart';

/// Claves de permiso de la app móvil. DEBEN coincidir exactamente con las
/// definidas en el panel web (src/config/modulos.js, categoría "App Móvil").
abstract class PermisosMovil {
  /// Interruptor maestro: sin este permiso el rol no puede ingresar al móvil.
  static const acceso = 'mobile_acceso';
  static const inicio = 'mobile_inicio';
  static const miembros = 'mobile_miembros';
  static const miembrosGestion = 'mobile_miembros_gestion';
  static const pagos = 'mobile_pagos';
  static const pagosRegistrar = 'mobile_pagos_registrar';
  static const publicidad = 'mobile_publicidad';
  static const publicidadGestion = 'mobile_publicidad_gestion';
  static const marketing = 'mobile_marketing';
  static const rutinas = 'mobile_rutinas';
  static const rutinasGestion = 'mobile_rutinas_gestion';
  static const lectorPagos = 'mobile_lector_pagos';
  static const notifEnviar = 'mobile_notif_enviar';
  static const ajustesNegocio = 'mobile_ajustes_negocio';
  static const ajustesYape = 'mobile_ajustes_yape';
}

/// Permisos del usuario en sesión, usados para mostrar/ocultar secciones y
/// acciones en la app móvil. Llegan del backend como CSV en el login (ej.
/// "mobile_inicio,mobile_pagos") y se guardan en SharedPreferences.
///
/// El rol Administrador (id_rol 1) tiene acceso total: `tiene()` siempre es
/// verdadero para él, sin importar el CSV.
class Permisos {
  final Set<String> _claves;
  final int idRol;

  const Permisos._(this._claves, this.idRol);

  /// Carga los permisos y el rol guardados durante el login.
  static Future<Permisos> cargar() async {
    final prefs = await SharedPreferences.getInstance();
    return Permisos.desde(
      prefs.getString('permisos') ?? '',
      int.tryParse(prefs.getString('idRol') ?? '') ?? 0,
    );
  }

  /// Construye desde un CSV de permisos y un id de rol (útil para pruebas).
  factory Permisos.desde(String csv, int idRol) {
    final claves = csv
        .split(',')
        .map((p) => p.trim())
        .where((p) => p.isNotEmpty)
        .toSet();
    return Permisos._(claves, idRol);
  }

  /// El Administrador (rol 1) puede ver y hacer todo en el móvil.
  bool get esAdministrador => idRol == 1;

  /// ¿El usuario tiene la clave de permiso indicada?
  bool tiene(String clave) => esAdministrador || _claves.contains(clave);

  /// ¿Tiene al menos una de las claves indicadas?
  bool tieneAlguno(Iterable<String> claves) =>
      esAdministrador || claves.any(_claves.contains);
}
