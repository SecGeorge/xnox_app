import 'package:flutter/foundation.dart' show kDebugMode;

/// Código de gimnasio que el usuario escribe en el arranque. Identifica al
/// tenant: cada gimnasio es un despliegue propio en su subdominio, así que
/// `XNONX` resuelve a `https://xnonx.xnoxsoft.es/api/`.
///
/// Se guarda en mayúsculas porque el backend lo compara con su constante
/// `CODIGO_GIMNASIO` (p. ej. 'PASSIONFIT') y esa comparación distingue
/// mayúsculas; el subdominio, en cambio, va siempre en minúsculas.
class CodigoEmpresa {
  const CodigoEmpresa._();

  /// Tope de caracteres del campo y de la validación.
  static const int maxCaracteres = 200;

  /// Lo que se puede teclear en el campo (el resto se descarta al escribir).
  static final RegExp caracteresPermitidos = RegExp(r'[a-zA-Z0-9-]');

  /// Formato de subdominio: empieza y termina en letra o número, con guiones
  /// intermedios opcionales.
  static final RegExp _formato = RegExp(r'^[A-Z0-9]([A-Z0-9-]*[A-Z0-9])?$');

  /// Solo en debug: códigos que se atienden desde el servidor de desarrollo en
  /// vez de su URL real. Está vacío a propósito, para que en debug la app se
  /// comporte igual que publicada: cada código va a su propia URL.
  ///
  /// Para volver a trabajar contra el servidor local, poner aquí el código que
  /// ese servidor atiende (su `ConstantesDominio::CODIGO_GIMNASIO`):
  /// `{'PASSIONFIT': HttpService.RUTA_GLOBAL}`.
  static const Map<String, String> rutasDeDesarrollo = <String, String>{};

  /// Códigos que se prueban contra el servidor, en orden, para saber cuál
  /// reconoce como suyo (su constante `CODIGO_GIMNASIO`, que es lo que hay que
  /// enviarle al registrar un cliente y al pedirle sus sucursales).
  ///
  /// Cada gimnasio se configura con el mismo código que escribe el usuario, así
  /// que ese es el primero. [_codigosBackendHeredados] son los valores que
  /// quedaron en despliegues que aún no siguen esa regla; cuando todos estén
  /// alineados se puede vaciar esa lista.
  ///
  /// Si un gimnasio responde cero sucursales con todos estos candidatos, lo que
  /// hay que revisar es su `ConstantesDominio::CODIGO_GIMNASIO`: debe ser igual
  /// al código que escribe el usuario. Añadir aquí el valor raro del servidor es
  /// tapar el problema, y hay que mantenerlo para siempre.
  static List<String> candidatosParaBackend(String codigo) =>
      <String>{codigo, ..._codigosBackendHeredados}.toList();

  /// Constante que compartían todos los despliegues antes de configurar cada
  /// gimnasio con su propio código.
  static const List<String> _codigosBackendHeredados = ['PASSIONFIT'];

  /// Deja el texto tal como se guarda y se envía al backend.
  static String normalizar(String texto) => texto.trim().toUpperCase();

  static bool esValido(String codigo) =>
      codigo.length <= maxCaracteres && _formato.hasMatch(codigo);

  /// URL real del gimnasio [codigo]: la que ya tenga guardada en la tabla
  /// `empresa` si lo conocemos, o la de su subdominio. Es la que se guarda,
  /// para que no dependa de si el build es debug o release.
  static String rutaReal(String codigo, {String? rutaGuardada}) =>
      rutaGuardada ?? 'https://${codigo.toLowerCase()}.xnoxsoft.es/api/';

  /// URL a la que se conecta la app: en debug, el servidor de desarrollo para
  /// los códigos de [rutasDeDesarrollo]; en cualquier otro caso, [rutaReal].
  static String rutaEnUso(String codigo, String rutaReal) {
    if (kDebugMode) {
      final desarrollo = rutasDeDesarrollo[codigo];
      if (desarrollo != null) return desarrollo;
    }
    return rutaReal;
  }
}
