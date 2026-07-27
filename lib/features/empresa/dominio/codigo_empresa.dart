import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:xnox_app/core/network/http_service.dart';

/// Código de gimnasio que el usuario escribe en el arranque. Identifica al
/// tenant: cada gimnasio es un despliegue propio en su subdominio, así que
/// `PASSIONFIT` resuelve a `https://passionfit.xnoxsoft.es/api/`.
///
/// Se guarda en mayúsculas porque el backend lo compara con su constante
/// `CODIGO_GIMNASIO` (p. ej. 'PASSIONFIT') y esa comparación distingue
/// mayúsculas; el subdominio, en cambio, va siempre en minúsculas.
class CodigoEmpresa {
  const CodigoEmpresa._();

  /// Tope de caracteres del campo y de la validación.
  static const int maxCaracteres = 200;

  /// Solo en debug: manda cualquier código al servidor local de desarrollo en
  /// vez de al subdominio, así se prueba con el código real del gimnasio
  /// (p. ej. PASSIONFIT) contra la máquina de trabajo. Ponlo en `false` para
  /// que un build de debug apunte a los subdominios reales.
  static const bool usarServidorLocalEnDebug = true;

  /// Lo que se puede teclear en el campo (el resto se descarta al escribir).
  static final RegExp caracteresPermitidos = RegExp(r'[a-zA-Z0-9-]');

  /// Formato de subdominio: empieza y termina en letra o número, con guiones
  /// intermedios opcionales.
  static final RegExp _formato = RegExp(r'^[A-Z0-9]([A-Z0-9-]*[A-Z0-9])?$');

  /// Deja el texto tal como se guarda y se envía al backend.
  static String normalizar(String texto) => texto.trim().toUpperCase();

  static bool esValido(String codigo) =>
      codigo.length <= maxCaracteres && _formato.hasMatch(codigo);

  /// URL base de la API del gimnasio [codigo] (ya normalizado).
  static String ruta(String codigo) {
    if (kDebugMode && usarServidorLocalEnDebug) {
      // Ruta de arranque de HttpService: el servidor de la máquina de trabajo.
      return HttpService.RUTA_GLOBAL;
    }
    return 'https://${codigo.toLowerCase()}.xnoxsoft.es/api/';
  }
}
