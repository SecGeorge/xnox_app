import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/repositorios/repositorio_auth.dart';

class RepositorioAuthImpl implements RepositorioAuth {
  final HttpService _httpService;

  RepositorioAuthImpl(this._httpService);

  @override
  Future<RespuestaLogin> login(String usuario, String password) async {
    try {
      final payload = { 
          'metodo': 'login', 
          'usuario':{
            'usuario': usuario,
            'password': password
          }
      }; 
      final response = await _httpService.obtenerConDatos(payload,'usuarios.php');

      if (response != null && response['resultado'] == true) {
        final prefs = await SharedPreferences.getInstance();
        final userData = response['datos'];
        if (userData != null) {
          await prefs.setString('idUsuario', userData['idUsuario'].toString());
          if (userData['id_sucursal'] != null) {
            await prefs.setString('idSucursal', userData['id_sucursal'].toString());
          } else {
            await prefs.setString('idSucursal', '1'); 
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
        message: response != null ? (response['error'] ?? 'Error de autenticación') : 'Error de conexión',
      );
    } catch (e) {
      return RespuestaLogin(
        success: false,
        message: 'Error inesperado: $e',
      );
    }
  }
}
