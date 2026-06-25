import 'package:flutter/material.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/presentacion/screen/formulario_publicidad_screen.dart';

class PublicidadScreen extends StatefulWidget {
  const PublicidadScreen({super.key});

  @override
  State<PublicidadScreen> createState() => _PublicidadScreenState();
}

class _PublicidadScreenState extends State<PublicidadScreen> {
  final _controlador = ControladorPublicidad();
  List<Publicidad> _publicidades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPublicidades();
  }

  Future<void> _cargarPublicidades() async {
    setState(() => _isLoading = true);
    try {
      final data = await _controlador.fetchPublicidades();
      setState(() {
        _publicidades = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar publicidades: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Publicidad'),
        backgroundColor: const Color(0xFF1A2B4C),
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _publicidades.isEmpty
              ? const Center(child: Text('No hay publicidades registradas'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _publicidades.length,
                  itemBuilder: (context, index) {
                    final pub = _publicidades[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 16),
                      child: ListTile(
                        leading: pub.imagenUrl != null
                            ? Image.network(pub.imagenUrl!, width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c, e, s) => const Icon(Icons.image))
                            : const Icon(Icons.image),
                        title: Text(pub.titulo),
                        subtitle: Text('${pub.descripcion}\nDesde: ${pub.fechaInicio.toString().split(' ')[0]} hasta ${pub.fechaFin.toString().split(' ')[0]}'),
                        isThreeLine: true,
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const FormularioPublicidadScreen()),
          );
          if (result == true) {
            _cargarPublicidades();
          }
        },
        backgroundColor: const Color(0xFF1A2B4C),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
