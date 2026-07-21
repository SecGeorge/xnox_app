import 'package:flutter/material.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/features/empresa/dominio/entidades/empresa.dart';
import 'package:xnox_app/features/login/presentacion/screen/sesion_gate.dart';

/// Primer arranque: el usuario elige la empresa (tenant) del catálogo. La
/// elección fija la ruta base de la API y se recuerda, así que las próximas
/// aperturas se saltan esta pantalla.
class SeleccionEmpresaScreen extends StatefulWidget {
  const SeleccionEmpresaScreen({super.key});

  @override
  State<SeleccionEmpresaScreen> createState() => _SeleccionEmpresaScreenState();
}

class _SeleccionEmpresaScreenState extends State<SeleccionEmpresaScreen> {
  static const _azul = Color(0xFF1A2B4C);

  final _dao = EmpresaDao.instancia;
  final Future<List<Empresa>> _empresas = EmpresaDao.instancia.listar();
  String? _procesando; // código en curso, para el spinner de la fila

  Future<void> _elegir(Empresa empresa) async {
    if (_procesando != null) return;
    setState(() => _procesando = empresa.codigo);

    try {
      final activada = await _dao.activar(empresa.codigo);
      final ruta = activada?.rutaGlobal ?? empresa.rutaGlobal;
      HttpService().aplicarRuta(ruta);
    } catch (_) {
      if (!mounted) return;
      setState(() => _procesando = null);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo seleccionar la empresa. Intenta de nuevo.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

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
                    'Selecciona tu empresa',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 32),
                  FutureBuilder<List<Empresa>>(
                    future: _empresas,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState != ConnectionState.done) {
                        return const Padding(
                          padding: EdgeInsets.all(32),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                      final empresas = snapshot.data ?? const [];
                      if (empresas.isEmpty) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Text(
                            'No hay empresas disponibles.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }
                      return Column(
                        children: empresas
                            .map((e) => _tarjetaEmpresa(e))
                            .toList(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tarjetaEmpresa(Empresa empresa) {
    final enCurso = _procesando == empresa.codigo;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: const Color(0xFFF1F3F8),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: _procesando == null ? () => _elegir(empresa) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            child: Row(
              children: [
                const Icon(Icons.business_outlined, color: _azul),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        empresa.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        empresa.codigo,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                enCurso
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2.4),
                      )
                    : const Icon(Icons.chevron_right, color: Colors.black38),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
