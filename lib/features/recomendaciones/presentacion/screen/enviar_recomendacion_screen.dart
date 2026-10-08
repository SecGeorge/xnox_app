import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/recomendaciones/datos/repositorio_recomendaciones.dart';
import 'package:xnox_app/features/recomendaciones/dominio/entidades/recomendacion.dart';
import 'package:xnox_app/features/recomendaciones/dominio/filtro_contenido.dart';

/// Formulario para dejar una recomendación. Lo puede abrir cualquier perfil
/// de la app (socio, recepción o administrador): no exige ningún permiso.
///
/// El autor no se envía desde aquí, lo resuelve el backend con la sesión. Si
/// el usuario marca "Enviar como anónimo", el servidor guarda la sugerencia
/// sin autor — no es solo un ocultar en pantalla.
class EnviarRecomendacionScreen extends StatefulWidget {
  const EnviarRecomendacionScreen({super.key});

  @override
  State<EnviarRecomendacionScreen> createState() =>
      _EnviarRecomendacionScreenState();
}

class _EnviarRecomendacionScreenState extends State<EnviarRecomendacionScreen> {
  final _repositorio = RepositorioRecomendaciones();
  final _mensajeCtrl = TextEditingController();

  DestinoRecomendacion _destino = DestinoRecomendacion.gimnasio;
  bool _anonimo = false;
  bool _enviando = false;

  /// Reparo del filtro de contenido, si lo hubo. Se muestra bajo el campo
  /// para que quede a la vista mientras corrige, no solo en el toast.
  String? _error;

  /// Solo los socios con la membresía vigente pueden recomendar. Se consulta
  /// al abrir para avisarle antes de que escriba, en vez de rechazarle el
  /// envío cuando ya redactó todo. El servidor lo vuelve a comprobar.
  bool _verificando = true;
  bool _habilitado = true;
  String _motivoBloqueo = '';

  static const _maxCaracteres = 500;

  @override
  void initState() {
    super.initState();
    _verificarHabilitacion();
  }

  Future<void> _verificarHabilitacion() async {
    final estado = await _repositorio.puedeEnviar();
    if (!mounted) return;
    setState(() {
      _habilitado = estado.puede;
      _motivoBloqueo = estado.motivo;
      _verificando = false;
    });
  }

  @override
  void dispose() {
    _mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    final mensaje = _mensajeCtrl.text.trim();

    // Groserías y texto sin sentido se frenan antes de gastar la petición. El
    // backend vuelve a validar lo mismo, esto es solo para avisar al toque.
    final reparo = FiltroContenido.validar(mensaje);
    if (reparo != null) {
      setState(() => _error = reparo);
      mostrarMensaje(context, reparo, tipo: TipoMensaje.advertencia);
      return;
    }
    setState(() => _error = null);

    setState(() => _enviando = true);
    final resultado = await _repositorio.enviar(
      destino: _destino,
      mensaje: mensaje,
      anonimo: _anonimo,
    );
    if (!mounted) return;
    setState(() => _enviando = false);

    if (!resultado.exito) {
      mostrarMensaje(context, resultado.mensaje, tipo: TipoMensaje.error);
      return;
    }

    // El toast se muestra sobre la pantalla anterior: esta se cierra en el
    // acto para que el usuario no tenga que hacerlo a mano.
    Navigator.of(context).pop(true);
    mostrarMensajeGlobal(resultado.mensaje, tipo: TipoMensaje.exito);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: !_verificando && _habilitado
          ? PieBoton(
              texto: _enviando ? 'Enviando…' : 'Enviar recomendación',
              icono: Icons.send_rounded,
              cargando: _enviando,
              onPressed: _enviar,
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: _verificando
            ? const Center(child: CircularProgressIndicator())
            : _habilitado
            ? _formulario()
            : _bloqueado(),
      ),
    );
  }

  /// Pantalla que ve el socio con la membresía vencida.
  Widget _bloqueado() {
    return ListView(
      padding: const EdgeInsets.all(AppEspaciado.md),
      children: [
        const CabeceraApp(titulo: 'Dejar una recomendación'),
        const SizedBox(height: AppEspaciado.xl),
        Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColores.advertencia.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.card_membership,
                  color: AppColores.advertencia,
                  size: 34,
                ),
              ),
              const SizedBox(height: AppEspaciado.md),
              Text(
                'Membresía no vigente',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const SizedBox(height: AppEspaciado.sm),
              Text(
                _motivoBloqueo.isEmpty
                    ? 'Para dejar una recomendación necesitas una membresía activa.'
                    : _motivoBloqueo,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  height: 1.4,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(height: AppEspaciado.lg),
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColores.primario,
                  side: BorderSide(color: AppColores.primario),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                  ),
                ),
                child: const Text('Entendido'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _formulario() {
    return ListView(
      padding: const EdgeInsets.all(AppEspaciado.md),
      children: [
        const CabeceraApp(
          titulo: 'Dejar una recomendación',
          subtitulo: 'Ayúdanos a mejorar',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        _intro(),
        const SizedBox(height: AppEspaciado.md),
        _selectorDestino(),
        const SizedBox(height: AppEspaciado.md),
        _campoMensaje(),
        const SizedBox(height: AppEspaciado.md),
        _switchAnonimo(),
      ],
    );
  }

  Widget _intro() {
    return const PortadaFoto(
      foto: FotosApp.motivacion,
      alineacion: Alignment(0.5, -0.3),
      altura: 150,
      etiqueta: 'Tu opinión cuenta',
      titulo: '¿Qué mejorarías?',
      texto:
          'Llega directo al administrador. Escríbela con respeto: los '
          'mensajes con groserías no se envían.',
    );
  }

  Widget _selectorDestino() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '¿Sobre qué es tu recomendación?',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          Row(
            children: [
              Expanded(
                child: _opcionDestino(
                  DestinoRecomendacion.gimnasio,
                  Icons.fitness_center,
                  'Equipos, clases, limpieza, atención…',
                ),
              ),
              const SizedBox(width: AppEspaciado.sm),
              Expanded(
                child: _opcionDestino(
                  DestinoRecomendacion.app,
                  Icons.phone_iphone,
                  'Funciones o problemas de la aplicación',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _opcionDestino(
    DestinoRecomendacion destino,
    IconData icono,
    String detalle,
  ) {
    final activo = _destino == destino;
    return InkWell(
      onTap: () => setState(() => _destino = destino),
      borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      child: Container(
        padding: const EdgeInsets.all(AppEspaciado.sm + 4),
        decoration: BoxDecoration(
          color: activo
              ? AppColores.primario.withValues(alpha: 0.08)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
          border: Border.all(
            color: activo ? AppColores.primario : AppColores.borde,
            width: activo ? 1.5 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icono,
              size: 22,
              color: activo ? AppColores.primario : AppColores.textoSecundario,
            ),
            const SizedBox(height: 6),
            Text(
              destino.etiqueta,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: activo ? AppColores.primario : AppColores.textoPrincipal,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              detalle,
              style: const TextStyle(
                fontSize: 11.5,
                height: 1.3,
                color: AppColores.textoSecundario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campoMensaje() {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu recomendación',
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          TextField(
            controller: _mensajeCtrl,
            maxLines: 6,
            maxLength: _maxCaracteres,
            textCapitalization: TextCapitalization.sentences,
            // El reparo desaparece en cuanto empieza a corregir: dejarlo
            // fijo mientras reescribe se siente como un regaño.
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
            decoration: InputDecoration(
              errorText: _error,
              errorMaxLines: 3,
              hintText: _destino == DestinoRecomendacion.app
                  ? 'Ej: me gustaría ver mi historial de pagos en la app'
                  : 'Ej: sería bueno tener más discos de 10 kg',
              hintStyle: const TextStyle(
                fontSize: 13.5,
                color: AppColores.textoSecundario,
              ),
              filled: true,
              fillColor: AppColores.fondo,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                borderSide: BorderSide(color: AppColores.borde),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                borderSide: BorderSide(color: AppColores.borde),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                borderSide: BorderSide(color: AppColores.primario),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _switchAnonimo() {
    return TarjetaApp(
      padding: const EdgeInsets.fromLTRB(
        AppEspaciado.md,
        AppEspaciado.sm,
        AppEspaciado.sm,
        AppEspaciado.sm,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Enviar como anónimo',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'No se guardará tu nombre. Tampoco podrán responderte.',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _anonimo,
            activeThumbColor: AppColores.primario,
            onChanged: (v) => setState(() => _anonimo = v),
          ),
        ],
      ),
    );
  }
}
