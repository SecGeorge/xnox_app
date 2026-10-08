import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/notificaciones/presentacion/controlador/controlador_notificaciones.dart';

/// Público al que se dirige la notificación. Los valores coinciden con la
/// columna `tipo_envio` de la tabla `notificaciones` en el backend.
enum PublicoNotificacion {
  clientes(2, 'Clientes', 'Todos los socios con la app', Icons.people_outline),
  personal(
    1,
    'Personal',
    'Administración',
    Icons.admin_panel_settings_outlined,
  ),
  colaboradores(
    3,
    'Colaboradores',
    'Recepción y entrenadores',
    Icons.badge_outlined,
  );

  const PublicoNotificacion(
    this.valor,
    this.etiqueta,
    this.detalle,
    this.icono,
  );

  final int valor;
  final String etiqueta;
  final String detalle;
  final IconData icono;
}

/// Permite al administrador redactar una notificación y enviarla por push.
///
/// Solo debe abrirse desde una sesión de administrador; el backend además lo
/// verifica por rol, así que una app manipulada tampoco podría enviarla.
///
/// Al cerrarse devuelve `true` si se envió algo, para que la pantalla anterior
/// refresque su lista.
class CrearNotificacionScreen extends StatefulWidget {
  const CrearNotificacionScreen({super.key});

  @override
  State<CrearNotificacionScreen> createState() =>
      _CrearNotificacionScreenState();
}

class _CrearNotificacionScreenState extends State<CrearNotificacionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _tituloCtrl = TextEditingController();
  final _mensajeCtrl = TextEditingController();
  final _controlador = ControladorNotificaciones();

  PublicoNotificacion _publico = PublicoNotificacion.clientes;
  bool _enviando = false;

  @override
  void dispose() {
    _tituloCtrl.dispose();
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_formKey.currentState!.validate()) return;

    // El envío no se puede deshacer: una vez en los teléfonos, no hay forma de
    // recogerlo. Por eso se confirma mostrando a quién va dirigido.
    final confirmado = await confirmarDialog(
      context,
      titulo: '¿Enviar la notificación?',
      mensaje:
          'Se enviará a: ${_publico.detalle.toLowerCase()}.\n\n'
          'Llegará al instante a sus teléfonos y no se puede cancelar.',
      icono: Icons.send_outlined,
      textoConfirmar: 'Enviar',
    );
    if (!confirmado || !mounted) return;

    setState(() => _enviando = true);
    try {
      final ok = await _controlador.crear(
        titulo: _tituloCtrl.text.trim(),
        mensaje: _mensajeCtrl.text.trim(),
        tipoEnvio: _publico.valor,
      );
      if (!mounted) return;

      if (ok) {
        mostrarMensaje(
          context,
          'Notificación enviada',
          tipo: TipoMensaje.exito,
        );
        Navigator.of(context).pop(true);
      } else {
        setState(() => _enviando = false);
        mostrarMensaje(
          context,
          'No se pudo enviar. Verifica que tu sesión siga activa.',
          tipo: TipoMensaje.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _enviando = false);
      mostrarMensaje(
        context,
        'No se pudo enviar la notificación',
        tipo: TipoMensaje.error,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: PieBoton(
        texto: _enviando ? 'Enviando…' : 'Enviar notificación',
        icono: Icons.send_rounded,
        cargando: _enviando,
        onPressed: _enviar,
      ),
      body: SafeArea(
        bottom: false,
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AppEspaciado.md),
            children: [
              const CabeceraApp(
                titulo: 'Nueva notificación',
                subtitulo: 'Llega como aviso al celular',
              ),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.edit_note_rounded,
                titulo: 'Mensaje',
              ),
              TarjetaPlana(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _tituloCtrl,
                      maxLength: 60,
                      textCapitalization: TextCapitalization.sentences,
                      // Refresca la vista previa mientras se escribe.
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Título',
                        hintText: 'Ej. Cerrado por feriado',
                        prefixIcon: Icon(Icons.title),
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe un título'
                          : null,
                    ),
                    const SizedBox(height: AppEspaciado.sm),
                    TextFormField(
                      controller: _mensajeCtrl,
                      maxLines: 4,
                      maxLength: 180,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Mensaje',
                        hintText: 'Ej. El 28 de julio no habrá atención.',
                        alignLabelWithHint: true,
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Escribe el mensaje'
                          : null,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppEspaciado.lg),
              const TituloSeccion(
                icono: Icons.groups_rounded,
                titulo: '¿Para quién?',
              ),
              Column(
                children: [
                  for (final p in PublicoNotificacion.values) ...[
                    _opcionPublico(p),
                    const SizedBox(height: AppEspaciado.sm),
                  ],
                ],
              ),
              const SizedBox(height: AppEspaciado.md),
              const TituloSeccion(
                icono: Icons.smartphone_rounded,
                titulo: 'Vista previa',
              ),
              _vistaPrevia(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _opcionPublico(PublicoNotificacion p) {
    final seleccionado = _publico == p;
    return TarjetaPlana(
      onTap: _enviando ? null : () => setState(() => _publico = p),
      padding: const EdgeInsets.all(12),
      color: seleccionado ? AppColores.primario.withValues(alpha: 0.06) : null,
      colorBorde: seleccionado ? AppColores.primario : null,
      child: Row(
        children: [
          IconoSuave(
            p.icono,
            color: seleccionado
                ? AppColores.primario
                : AppColores.textoSecundario,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.etiqueta,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  p.detalle,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            seleccionado
                ? Icons.check_circle_rounded
                : Icons.radio_button_unchecked_rounded,
            color: seleccionado ? AppColores.primario : AppColores.borde,
          ),
        ],
      ),
    );
  }

  /// Muestra cómo se verá el aviso en el teléfono. Ayuda a detectar erratas
  /// antes de enviarlo, que es cuando todavía se puede corregir.
  Widget _vistaPrevia() {
    final titulo = _tituloCtrl.text.trim();
    final mensaje = _mensajeCtrl.text.trim();

    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const EncabezadoSeccion(titulo: 'Así lo verán'),
          const SizedBox(height: AppEspaciado.sm),
          Container(
            padding: const EdgeInsets.all(AppEspaciado.sm),
            decoration: BoxDecoration(
              color: AppColores.fondo,
              borderRadius: BorderRadius.circular(AppEspaciado.radio),
              border: Border.all(color: AppColores.borde),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColores.primario,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                const SizedBox(width: AppEspaciado.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo.isEmpty ? 'Título del aviso' : titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: titulo.isEmpty
                              ? AppColores.textoSecundario
                              : AppColores.textoPrincipal,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        mensaje.isEmpty
                            ? 'Aquí aparecerá el mensaje.'
                            : mensaje,
                        style: TextStyle(
                          fontSize: 13,
                          color: mensaje.isEmpty
                              ? AppColores.textoSecundario
                              : AppColores.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
