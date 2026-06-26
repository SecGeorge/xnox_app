import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/sucursal.dart';
import 'package:xnox_app/features/login/dominio/entidades/tipo_usuario.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class RepositorioAuthImpl implements RepositorioAuth {
  final HttpService _httpService;

  RepositorioAuthImpl(this._httpService);

  @override
  Future<RespuestaLogin> login(
      String usuario, String password, TipoUsuario tipo) async {
    try {
      // Los clientes usan un endpoint distinto al del personal interno.
      final metodo =
          tipo == TipoUsuario.cliente ? 'login_cliente' : 'login';
      final payload = {
          'metodo': metodo,
          'usuario':{
            'usuario': usuario,
            'password': password,
            'tipo': tipo.codigo
          }
      };
      final response = await _httpService.obtenerConDatos(payload,'usuarios.php');
      if (response != null && response['resultado'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final userData = response['datos'];
        await prefs.setString('tipoUsuario', tipo.codigo);
        if (userData != null) {
          await prefs.setString('idUsuario', userData['idUsuario'].toString());
          final sucursal = userData['sucursal_id'] ?? userData['id_sucursal'];
          await prefs.setString('idSucursal', (sucursal ?? 2).toString());
          if (userData['miembro_id'] != null) {
            await prefs.setString('miembroId', userData['miembro_id'].toString());
          }
        }

        return RespuestaLogin(
          success: true,
          message: 'Login exitoso',
          userData: userData,
        );
      }

      return RespuestaLogin(
        success: false,
        message: response != null ? (response['error'] ?? 'Usuario o contraseña incorrectos') : 'Error de conexión',
      );
    } catch (e) {
      return RespuestaLogin(
        success: false,
        message: 'Error inesperado: $e',
      );
    }
  }

  @override
  Future<RespuestaLogin> registrarCliente(DatosRegistro datos) async {
    try {
      final payload = {
        'metodo': 'registrar_cliente',
        'usuario': datos.toJson(),
      };
      final response =
          await _httpService.registrar(payload, 'usuarios.php');

      if (response == null) {
        return RespuestaLogin(
            success: false, message: 'No se pudo conectar con el servidor');
      }

      // El backend responde con voit_exito (1 = éxito) y voit_mensaje.
      final exito = response['voit_exito']?.toString() == '1';
      final mensaje = response['voit_mensaje']?.toString() ??
          response['error']?.toString() ??
          (exito ? 'Cuenta creada correctamente' : 'No se pudo crear la cuenta');

      return RespuestaLogin(success: exito, message: mensaje);
    } catch (e) {
      return RespuestaLogin(
        success: false,
        message: 'Error inesperado: $e',
      );
    }
  }

  @override
  Future<List<Sucursal>> sucursalesPorCodigo(String codigoGimnasio) async {
    try {
      final payload = {
        'metodo': 'por_codigo_gimnasio',
        'codigo_gimnasio': codigoGimnasio,
      };
      final response =
          await _httpService.obtenerConDatos(payload, 'sucursal.php');

      final datos = response is Map ? response['datos'] : null;
      if (datos is List) {
        return datos
            .whereType<Map>()
            .map((e) => Sucursal.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }
}
