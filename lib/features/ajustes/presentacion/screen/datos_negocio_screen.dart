import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ajustes/dominio/entidades/datos_negocio.dart';
import 'package:xnox_app/features/ajustes/presentacion/controlador/controlador_ajustes.dart';

/// "Datos del negocio": muestra y permite editar el nombre, teléfono y
/// dirección del gimnasio (tabla `ajustes` del backend).
class DatosNegocioScreen extends StatefulWidget {
  const DatosNegocioScreen({super.key});

  @override
  State<DatosNegocioScreen> createState() => _DatosNegocioScreenState();
}

class _DatosNegocioScreenState extends State<DatosNegocioScreen> {
  final _controlador = ControladorAjustes();
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _direccionController = TextEditingController();

  DatosNegocio? _datos;
  bool _isLoading = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final datos = await _controlador.obtenerDatosNegocio();
      if (!mounted) return;
      setState(() {
        _datos = datos;
        _nombreController.text = datos.nombre;
        _telefonoController.text = datos.telefono;
        _direccionController.text = datos.direccion;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      mostrarMensaje(
        context,
        'No se pudieron cargar los datos del negocio',
        tipo: TipoMensaje.error,
      );
    }
  }

  Future<void> _guardar() async {
    if (!_formKey.currentState!.validate()) return;
    final base = _datos ?? DatosNegocio.vacio();
    final actualizado = base.copyWith(
      nombre: _nombreController.text.trim(),
      telefono: _telefonoController.text.trim(),
      direccion: _direccionController.text.trim(),
    );

    setState(() => _isSaving = true);
    try {
      final error = await _controlador.guardarDatosNegocio(actualizado);
      if (!mounted) return;
      setState(() => _isSaving = false);
      if (error == null) {
        mostrarMensaje(
          context,
          'Datos del negocio actualizados',
          tipo: TipoMensaje.exito,
        );
        Navigator.of(context).pop();
      } else {
        mostrarMensaje(context, error, tipo: TipoMensaje.error);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      mostrarMensaje(
        context,
        'No se pudo guardar. Intenta nuevamente.',
        tipo: TipoMensaje.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: _isLoading
          ? null
          : PieBoton(
              texto: 'Guardar cambios',
              icono: Icons.check_rounded,
              cargando: _isSaving,
              onPressed: _guardar,
            ),
      body: SafeArea(
        bottom: false,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(AppEspaciado.md),
                  children: [
                    const CabeceraApp(
                      titulo: 'Datos del negocio',
                      subtitulo: 'Así te ven tus socios en la app',
                    ),
                    const SizedBox(height: AppEspaciado.md + 4),
                    _buildLogo(),
                    const SizedBox(height: AppEspaciado.lg),
                    const TituloSeccion(
                      icono: Icons.storefront_rounded,
                      titulo: 'Información',
                    ),
                    TarjetaPlana(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _etiqueta('Nombre del negocio'),
                          TextFormField(
                            controller: _nombreController,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'Ej. Gimnasio XNOX',
                              prefixIcon: Icon(Icons.badge_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa el nombre del negocio'
                                : null,
                          ),
                          const SizedBox(height: AppEspaciado.md),
                          _etiqueta('Teléfono'),
                          TextFormField(
                            controller: _telefonoController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              hintText: 'Ej. 987654321',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Ingresa el teléfono'
                                : null,
                          ),
                          const SizedBox(height: AppEspaciado.md),
                          _etiqueta('Dirección'),
                          TextFormField(
                            controller: _direccionController,
                            textCapitalization: TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText: 'Ej. Av. Principal 123',
                              prefixIcon: Icon(Icons.place_outlined),
                            ),
                            maxLines: 2,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  /// Portada con foto y el logo del gimnasio encima, centrado.
  Widget _buildLogo() {
    final url = _datos?.logoUrl;
    return SizedBox(
      height: 196,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          const SizedBox(
            height: 140,
            child: FotoTarjeta(
              foto: FotosApp.membresia,
              alineacion: Alignment(0.3, -0.3),
              radio: AppEspaciado.radio + 6,
              child: SizedBox.expand(),
            ),
          ),
          Positioned(
            bottom: 0,
            child: Container(
              width: 108,
              height: 108,
              decoration: BoxDecoration(
                color: AppColores.superficie,
                borderRadius: BorderRadius.circular(AppEspaciado.radio + 6),
                border: Border.all(color: AppColores.superficie, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: url != null
                  ? Image.network(
                      url,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _logoPlaceholder(),
                    )
                  : _logoPlaceholder(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoPlaceholder() {
    return Container(
      decoration: BoxDecoration(gradient: AppColores.degradadoRelleno),
      child: Icon(
        Icons.storefront_rounded,
        size: 44,
        color: AppColores.sobreRelleno,
      ),
    );
  }

  Widget _etiqueta(String texto) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w600,
          color: AppColores.textoPrincipal,
        ),
      ),
    );
  }
}
