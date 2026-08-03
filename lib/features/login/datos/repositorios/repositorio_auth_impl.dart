import 'package:shared_preferences/shared_preferences.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/servicios/servicio_notificaciones.dart';
import 'package:xnox_app/features/login/dominio/entidades/datos_registro.dart';
import 'package:xnox_app/features/login/dominio/entidades/respuesta_login.dart';
import 'package:xnox_app/features/login/dominio/entidades/resultado_sucursales.dart';
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
        final userData = response['datos'];

        // Control de acceso al móvil para el PERSONAL interno (no clientes):
        // el rol debe tener el permiso maestro 'mobile_acceso'. El rol
        // Administrador (id_rol 1) siempre entra. Los permisos llegan como CSV.
        if (tipo != TipoUsuario.cliente) {
          final idRol = int.tryParse(userData?['id_rol']?.toString() ?? '') ?? 0;
          final permisos = (userData?['permisos']?.toString() ?? '')
              .split(',')
              .map((p) => p.trim())
              .toSet();
          final tieneAccesoMovil = idRol == 1 || permisos.contains('mobile_acceso');
          if (!tieneAccesoMovil) {
            return RespuestaLogin(
              success: false,
              message:
                  'Tu rol no tiene acceso a la app móvil. Contacta al administrador.',
            );
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('tipoUsuario', tipo.codigo);
        if (userData != null) {
          await prefs.setString('idUsuario', userData['idUsuario'].toString());
          // Rol y permisos (CSV) para gobernar qué ve el usuario en el móvil.
          await prefs.setString('idRol', userData['id_rol']?.toString() ?? '');
          await prefs.setString(
              'permisos', userData['permisos']?.toString() ?? '');
          // Para el cliente, el nombre de usuario es su DNI/código (sirve de QR).
          await prefs.setString(
              'usuarioNombre', userData['nombreUsuario']?.toString() ?? '');
          // Nombre real del cliente, para saludarlo en el inicio.
          await prefs.setString(
              'nombreCliente', userData['nombre']?.toString() ?? '');
          final sucursal = userData['sucursal_id'] ?? userData['id_sucursal'];
          await prefs.setString('idSucursal', (sucursal ?? 2).toString());
          if (userData['miembro_id'] != null) {
            await prefs.setString('miembroId', userData['miembro_id'].toString());
          }
        }

        // Ya hay sesión: el backend puede asociar el token de este teléfono a
        // quien acaba de entrar y mandarle notificaciones.
        await ServicioNotificaciones().registrarEnBackend();

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
  Future<ResultadoSucursales> sucursalesPorCodigo(String codigoGimnasio) async {
    try {
      final payload = {
        'metodo': 'por_codigo_gimnasio',
        'codigo_gimnasio': codigoGimnasio,
      };
      final response =
          await _httpService.obtenerConDatos(payload, 'sucursal.php');

      if (response is! Map) {
        return ResultadoSucursales.errorServidor(codigoGimnasio);
      }

      final datos = response['datos'];
      if (datos is List) {
        final sucursales = datos
            .whereType<Map>()
            .map((e) => Sucursal.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        return ResultadoSucursales.ok(sucursales, codigoGimnasio);
      }

      // Sin `datos`: el servicio no llegó a responder (el HttpService ya
      // devuelve un mapa marcado en ese caso) o devolvió un error propio.
      final mensaje = response['error']?.toString();
      if (response['sin_conexion'] == true) {
        return ResultadoSucursales.sinConexion(codigoGimnasio, mensaje);
      }
      return ResultadoSucursales.errorServidor(codigoGimnasio, mensaje);
    } catch (_) {
      return ResultadoSucursales.errorServidor(codigoGimnasio);
    }
  }

  @override
  Future<void> logout() async {
    // Antes de borrar la sesión: el backend deja de mandar avisos a este
    // teléfono. Si se hiciera después, ya no sabríamos de quién era el token.
    await ServicioNotificaciones().darDeBajaEnBackend();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  @override
  Future<TipoUsuario?> sesionActiva() async {
    final prefs = await SharedPreferences.getInstance();
    // El login guarda 'idUsuario' solo cuando autentica correctamente, así que
    // su presencia indica que hay una sesión válida persistida.
    final idUsuario = prefs.getString('idUsuario');
    if (idUsuario == null || idUsuario.isEmpty) return null;
    return TipoUsuario.desdeTexto(prefs.getString('tipoUsuario'));
  }
}
