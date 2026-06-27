import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/datos_negocio.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/perfil_usuario.dart';

/// Acceso a los datos de la sección "Ajustes": perfil del usuario,
/// datos del negocio y cambio de contraseña.
class RepositorioAjustesImpl {
  final HttpService _httpService;

  RepositorioAjustesImpl(this._httpService);

  Future<int> _usuarioId() async {
    final prefs = await SharedPreferences.getInstance();
    return int.tryParse(prefs.getString('idUsuario') ?? '') ?? 0;
  }

  /// Construye la URL absoluta del logo a partir de la ruta relativa que
  /// guarda el backend (ej. "imagenes/logo/x.png").
  String? _urlLogo(dynamic ruta) {
    final r = ruta?.toString().trim() ?? '';
    if (r.isEmpty) return null;
    if (r.startsWith('http')) return r;
    final limpia = r.replaceFirst(RegExp(r'^(\.{1,2}/)+'), '');
    return '${HttpService.RUTA_GLOBAL}$limpia';
  }

  // ----------------------------------------------------------------- Perfil
  Future<PerfilUsuario?> obtenerPerfil() async {
    final resp = await _httpService.obtenerConDatos(
      {'metodo': 'informacion_perfil', 'idUsuario': await _usuarioId()},
      'usuarios.php',
    );
    if (resp is Map) {
      return PerfilUsuario.fromJson(Map<String, dynamic>.from(resp));
    }
    return null;
  }

  // -------------------------------------------------------- Datos del negocio
  Future<DatosNegocio> obtenerDatosNegocio() async {
    final resp = await _httpService.obtenerConDatos(
      {'metodo': 'obtener'},
      'ajustes.php',
    );

    if (resp is! Map) return DatosNegocio.vacio();
    final json = Map<String, dynamic>.from(resp);

    return DatosNegocio(
      id: int.tryParse(json['id']?.toString() ?? ''),
      nombre: json['nombre']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      direccion: json['direccion']?.toString() ?? '',
      logo: json['logo']?.toString() ?? '',
      logoUrl: _urlLogo(json['logo']),
    );
  }

  /// Guarda los datos del negocio. Devuelve `null` si todo salió bien o un
  /// mensaje de error legible para mostrar al usuario.
  Future<String?> guardarDatosNegocio(DatosNegocio datos) async {
    final resp = await _httpService.registrar(
      {
        'metodo': 'registrar',
        'ajustes': {
          'id': datos.id,
          // Mantenemos el logo actual: no se edita desde la app.
          'logo': datos.logo,
          'logoCambia': false,
          'nombre': datos.nombre,
          'direccion': datos.direccion,
          'telefono': datos.telefono,
        },
      },
      'ajustes.php',
    );

    // Error lanzado por el dominio/controlador del backend.
    if (resp is Map && resp['error'] != null) {
      return resp['error'].toString();
    }

    // El SP responde con voit_exito ('1' = éxito) y voit_message.
    final fila = resp is List && resp.isNotEmpty ? resp.first : resp;
    if (fila is Map) {
      final exito = fila['voit_exito']?.toString() == '1';
      if (!exito) {
        return fila['voit_message']?.toString() ??
            'No se pudieron guardar los datos del negocio';
      }
    }
    return null;
  }

  // --------------------------------------------------------------- Seguridad
  /// Verifica que [actual] coincida con la contraseña vigente del usuario.
  Future<bool> verificarPassword(String actual) async {
    final resp = await _httpService.obtenerConDatos(
      {'metodo': 'verifica_pass', 'password': actual, 'id': await _usuarioId()},
      'usuarios.php',
    );
    return resp == true;
  }

  /// Cambia la contraseña del usuario. Devuelve `null` si salió bien o un
  /// mensaje de error legible.
  Future<String?> cambiarPassword(String nueva) async {
    final resp = await _httpService.obtenerConDatos(
      {
        'metodo': 'cambiar_pass',
        'password': nueva,
        'idUsuario': await _usuarioId(),
      },
      'usuarios.php',
    );

    if (resp == true) return null;
    if (resp is Map && resp['error'] != null) return resp['error'].toString();
    return 'No se pudo cambiar la contraseña';
  }
}
