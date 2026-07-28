import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/empresa/datos/verificador_empresa.dart';
import 'package:xnox_app/features/empresa/dominio/codigo_empresa.dart';
import 'package:xnox_app/features/login/presentacion/screen/sesion_gate.dart';

/// Primer arranque: el usuario escribe el código de su gimnasio. Con él se fija
/// la ruta base de la API y se recuerda, así que las próximas aperturas se
/// saltan esta pantalla.
class CodigoEmpresaScreen extends StatefulWidget {
  const CodigoEmpresaScreen({super.key});

  @override
  State<CodigoEmpresaScreen> createState() => _CodigoEmpresaScreenState();
}

class _CodigoEmpresaScreenState extends State<CodigoEmpresaScreen> {
  static const _azul = Color(0xFF1A2B4C);

  final _codigo = TextEditingController();
  bool _procesando = false;

  @override
  void dispose() {
    _codigo.dispose();
    super.dispose();
  }

  /// Valida el código, comprueba que el gimnasio responde y entra. Los avisos
  /// salen por [mostrarMensajeGlobal], que muestra uno solo a la vez y
  /// reemplaza el anterior; además [_procesando] ignora los toques repetidos
  /// mientras hay una comprobación en curso.
  Future<void> _continuar() async {
    if (_procesando) return;

    final codigo = CodigoEmpresa.normalizar(_codigo.text);
    if (codigo.isEmpty) {
      mostrarMensajeGlobal(
        'Escribe el código de tu gimnasio.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    if (!CodigoEmpresa.esValido(codigo)) {
      mostrarMensajeGlobal(
        'El código solo admite letras, números y guiones.',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _procesando = true);

    // Si el gimnasio ya está en la tabla `empresa` usamos la URL guardada; si
    // no, se arma desde el subdominio y al guardarlo queda para siempre. Se
    // valida y se navega contra la ruta en uso (en debug puede ser el servidor
    // de desarrollo), pero lo que se guarda es siempre la URL real.
    final guardado = await EmpresaDao.instancia.porCodigo(codigo);
    final rutaReal =
        CodigoEmpresa.rutaReal(codigo, rutaGuardada: guardado?.rutaGlobal);
    final ruta = CodigoEmpresa.rutaEnUso(codigo, rutaReal);
    final resultado = await const VerificadorEmpresa().verificar(ruta, codigo);
    if (!mounted) return;
    if (resultado != ResultadoVerificacion.valido) {
      setState(() => _procesando = false);
      mostrarMensajeGlobal(
        resultado == ResultadoVerificacion.sinConexion
            ? 'Sin conexión a internet. Verifica tu red e inténtalo de nuevo.'
            : 'No encontramos el gimnasio "$codigo". Revisa el código con tu gimnasio.',
        tipo: TipoMensaje.error,
      );
      return;
    }

    // Qué código reconoce ese servidor dentro de sus peticiones: se guarda para
    // que el registro de clientes no tenga que volver a pedirlo.
    final codigoBackend = await const VerificadorEmpresa().codigoQueReconoce(
          ruta,
          CodigoEmpresa.candidatosParaBackend(codigo),
        ) ??
        guardado?.codigoBackend;
    if (!mounted) return;

    try {
      await EmpresaDao.instancia.guardarYActivar(
        codigo: codigo,
        rutaGlobal: rutaReal,
        nombre: guardado?.nombre,
        codigoBackend: codigoBackend,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = false);
      mostrarMensajeGlobal(
        'No se pudo guardar el código. Intenta de nuevo.',
        tipo: TipoMensaje.error,
      );
      return;
    }

    HttpService().aplicarRuta(ruta);
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SesionGate()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'XNOX-SOFT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: _azul,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Escribe el código de tu gimnasio',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _codigo,
                    enabled: !_procesando,
                    autofocus: true,
                    maxLength: CodigoEmpresa.maxCaracteres,
                    // El contador 0/200 solo estorba en un campo de código.
                    buildCounter: (_,
                            {required currentLength,
                            required isFocused,
                            maxLength}) =>
                        null,
                    textInputAction: TextInputAction.go,
                    textCapitalization: TextCapitalization.none,
                    autocorrect: false,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                        CodigoEmpresa.caracteresPermitidos,
                      ),
                      // El código se guarda y se envía en mayúsculas: que se
                      // vea así mientras se escribe evita sorpresas.
                      TextInputFormatter.withFunction(
                        (anterior, nuevo) => nuevo.copyWith(
                          text: nuevo.text.toUpperCase(),
                        ),
                      ),
                    ],
                    onSubmitted: (_) => _continuar(),
                    decoration: InputDecoration(
                      labelText: 'Código de gimnasio',
                      prefixIcon: const Icon(Icons.business_outlined,
                          color: _azul),
                      filled: true,
                      fillColor: const Color(0xFFF1F3F8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _procesando ? null : _continuar,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _azul,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _procesando
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.4,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continuar',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
