import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/tema/controlador_marca.dart';
import 'package:xnox_app/core/utils/quitar_fondo.dart';
import 'package:xnox_app/core/widgets/logo_gimnasio.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';

/// Ajustes → Colores de la app. El admin elige una plantilla (o su propio
/// color); se guarda en el servidor del gimnasio (`ajustes.paleta_app`) y la
/// ven todos los dispositivos que apuntan a esa API.
class ColoresAppScreen extends StatefulWidget {
  const ColoresAppScreen({super.key});

  @override
  State<ColoresAppScreen> createState() => _ColoresAppScreenState();
}

class _ColoresAppScreenState extends State<ColoresAppScreen> {
  /// Paleta que se está guardando (muestra el indicador en su tarjeta).
  String? _guardandoId;

  bool _guardandoLogo = false;

  /// Sube un logo solo para la app. Sin `imageQuality`: así un PNG no se
  /// recomprime a JPEG y conserva el fondo transparente.
  Future<void> _subirLogo() async {
    if (_guardandoLogo) return;
    final img = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (img == null) return;
    await _revisarYGuardar(await img.readAsBytes());
  }

  /// Quitar el fondo al logo que ya se muestra (el propio o el de la web):
  /// se descarga y se abre la misma vista previa con la opción activada.
  Future<void> _quitarFondoActual(String url) async {
    if (_guardandoLogo) return;
    setState(() => _guardandoLogo = true);
    Uint8List? bytes;
    try {
      final r = await Dio().get<List<int>>(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      bytes = Uint8List.fromList(r.data ?? const []);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _guardandoLogo = false);
    if (bytes == null || bytes.isEmpty) {
      mostrarMensajeGlobal(
        'No se pudo descargar el logo actual',
        tipo: TipoMensaje.error,
      );
      return;
    }
    await _revisarYGuardar(bytes, quitarFondo: true);
  }

  /// Vista previa antes de subir, con la opción de quitar el fondo.
  Future<void> _revisarYGuardar(
    Uint8List bytes, {
    bool quitarFondo = false,
  }) async {
    final elegido = await showDialog<Uint8List>(
      context: context,
      builder: (_) =>
          _DialogoLogo(original: bytes, quitarFondoInicial: quitarFondo),
    );
    if (elegido == null) return;
    // El backend solo distingue el encabezado; el contenido real puede ser
    // PNG (con fondo quitado) o JPEG.
    await _guardarLogo('data:image/png;base64,${base64Encode(elegido)}');
  }

  Future<void> _guardarLogo(String? base64) async {
    setState(() => _guardandoLogo = true);
    final error = await ControladorMarca.instancia.cambiarLogoApp(base64);
    if (!mounted) return;
    setState(() => _guardandoLogo = false);
    if (error != null) {
      mostrarMensajeGlobal(error, tipo: TipoMensaje.error);
    } else {
      mostrarMensajeGlobal(
        base64 == null
            ? 'La app vuelve a usar el logo del gimnasio'
            : 'Logo de la app actualizado en todos los dispositivos',
        tipo: TipoMensaje.exito,
      );
    }
  }

  Future<void> _elegir(PaletaApp paleta) async {
    // Un toque a la vez: cada uno es una petición al servidor.
    if (_guardandoId != null) return;
    setState(() => _guardandoId = paleta.id);
    final error = await ControladorMarca.instancia.elegirPaleta(paleta);
    if (!mounted) return;
    setState(() => _guardandoId = null);
    if (error != null) {
      mostrarMensajeGlobal(error, tipo: TipoMensaje.error);
    } else {
      mostrarMensajeGlobal(
        '${paleta.nombre} aplicado en todos los dispositivos del gimnasio',
        tipo: TipoMensaje.exito,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MarcaGimnasio>(
      valueListenable: ControladorMarca.instancia.marca,
      builder: (context, marca, _) {
        final actual = marca.paleta;
        final colorPropio = PaletaApp.colorDePersonalizada(actual.id);
        return Scaffold(
          appBar: AppBar(title: const Text('Colores de la app')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppEspaciado.md,
              AppEspaciado.md,
              AppEspaciado.md,
              AppEspaciado.xl,
            ),
            children: [
              _Portada(marca: marca),
              const SizedBox(height: AppEspaciado.lg + 4),
              const _TituloSeccion(
                titulo: 'Logo de la app',
                subtitulo: 'Si tu logo es blanco, sube una versión a color',
              ),
              const SizedBox(height: AppEspaciado.md),
              _LogoApp(
                marca: marca,
                guardando: _guardandoLogo,
                onSubir: _subirLogo,
                onQuitarFondo: marca.logoUrl == null
                    ? null
                    : () => _quitarFondoActual(marca.logoUrl!),
                onQuitar: () => _guardarLogo(null),
              ),
              const SizedBox(height: AppEspaciado.lg + 4),
              const _TituloSeccion(
                titulo: 'Plantillas',
                subtitulo: 'Estilos listos, pensados para gimnasios',
              ),
              const SizedBox(height: AppEspaciado.md),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: PaletasApp.plantillas.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppEspaciado.md,
                  crossAxisSpacing: AppEspaciado.md,
                  childAspectRatio: 0.80,
                ),
                itemBuilder: (_, i) {
                  final p = PaletasApp.plantillas[i];
                  return _TarjetaPlantilla(
                    paleta: p,
                    seleccionada: p.id == actual.id,
                    guardando: _guardandoId == p.id,
                    onTap: () => _elegir(p),
                  );
                },
              ),
              const SizedBox(height: AppEspaciado.lg + 4),
              const _TituloSeccion(
                titulo: 'Tu color de marca',
                subtitulo: 'Armamos la paleta a partir de un solo color',
              ),
              const SizedBox(height: AppEspaciado.md),
              Container(
                padding: const EdgeInsets.all(AppEspaciado.md),
                decoration: BoxDecoration(
                  color: AppColores.superficie,
                  borderRadius: BorderRadius.circular(AppEspaciado.radio),
                  border: Border.all(color: AppColores.borde),
                ),
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final c in PaletasApp.coloresPersonalizados)
                      _MuestraColor(
                        color: c,
                        seleccionada: colorPropio?.toARGB32() == c.toARGB32(),
                        onTap: () => _elegir(PaletaApp.desdeColor(c)),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Cabecera con la marca actual: logo, nombre y la plantilla en uso, pintada
/// con los colores de esa misma plantilla.
class _Portada extends StatelessWidget {
  final MarcaGimnasio marca;

  const _Portada({required this.marca});

  @override
  Widget build(BuildContext context) {
    final p = marca.paleta;
    final nombre = (marca.nombre ?? '').isEmpty ? 'Tu gimnasio' : marca.nombre!;
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const LogoGimnasio(tamano: 56),
              const SizedBox(width: AppEspaciado.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColores.sobreRelleno,
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Estilo actual · ${p.nombre}',
                      style: TextStyle(
                        color: AppColores.sobreRellenoSuave,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md + 4),
          Container(
            height: 1,
            color: AppColores.sobreRelleno.withValues(alpha: 0.15),
          ),
          const SizedBox(height: AppEspaciado.md),
          Row(
            children: [
              Icon(
                Icons.devices_outlined,
                size: 16,
                color: AppColores.sobreRellenoSuave,
              ),
              const SizedBox(width: AppEspaciado.sm),
              Expanded(
                child: Text(
                  'Lo que elijas lo verán tus socios y colaboradores',
                  style: TextStyle(
                    color: AppColores.sobreRellenoSuave,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Vista previa del logo sobre fondo claro (como en el login) y sobre el color
/// de marca, con los botones para cambiarlo o volver al del gimnasio.
class _LogoApp extends StatelessWidget {
  final MarcaGimnasio marca;
  final bool guardando;
  final VoidCallback onSubir;
  final VoidCallback onQuitar;
  final VoidCallback? onQuitarFondo;

  const _LogoApp({
    required this.marca,
    required this.guardando,
    required this.onSubir,
    required this.onQuitar,
    this.onQuitarFondo,
  });

  Widget _muestra(Color fondo, String texto, Color colorTexto) => Expanded(
    child: Container(
      height: 104,
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const LogoGimnasio(tamano: 56),
          const SizedBox(height: 6),
          Text(texto, style: TextStyle(fontSize: 11, color: colorTexto)),
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _muestra(
                const Color(0xFFF1F3F8),
                'Fondo claro',
                AppColores.textoSecundario,
              ),
              const SizedBox(width: AppEspaciado.sm),
              _muestra(
                AppColores.relleno,
                'Color de marca',
                AppColores.sobreRellenoSuave,
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Text(
            marca.logoPropio
                ? 'Usando el logo propio de la app'
                : 'Usando el logo del gimnasio (el de la web)',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          FilledButton.icon(
            onPressed: guardando ? null : onSubir,
            icon: guardando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.image_outlined),
            label: Text(
              marca.logoPropio
                  ? 'Cambiar logo de la app'
                  : 'Subir logo para la app',
            ),
          ),
          if (onQuitarFondo != null)
            OutlinedButton.icon(
              onPressed: guardando ? null : onQuitarFondo,
              icon: const Icon(Icons.auto_fix_high_outlined),
              label: const Text('Quitar fondo al logo actual'),
            ),
          if (marca.logoPropio)
            TextButton(
              onPressed: guardando ? null : onQuitar,
              child: const Text('Volver al logo del gimnasio'),
            ),
        ],
      ),
    );
  }
}

/// Vista previa del logo antes de subirlo, sobre fondo claro y sobre el color
/// de marca, con el interruptor para quitarle el fondo. Devuelve los bytes a
/// subir (con o sin fondo) o null si se cancela.
class _DialogoLogo extends StatefulWidget {
  final Uint8List original;
  final bool quitarFondoInicial;

  const _DialogoLogo({required this.original, this.quitarFondoInicial = false});

  @override
  State<_DialogoLogo> createState() => _DialogoLogoState();
}

class _DialogoLogoState extends State<_DialogoLogo> {
  late bool _quitarFondo = widget.quitarFondoInicial;
  Uint8List? _sinFondo;
  bool _procesando = false;

  /// La imagen no tiene un fondo liso que quitar.
  bool _sinFondoQueQuitar = false;

  @override
  void initState() {
    super.initState();
    if (_quitarFondo) _procesar();
  }

  Future<void> _procesar() async {
    if (_sinFondo != null || _sinFondoQueQuitar) return;
    setState(() => _procesando = true);
    final r = await quitarFondoLogo(widget.original);
    if (!mounted) return;
    setState(() {
      _procesando = false;
      _sinFondo = r;
      _sinFondoQueQuitar = r == null;
      if (r == null) _quitarFondo = false;
    });
  }

  Uint8List get _actual =>
      _quitarFondo && _sinFondo != null ? _sinFondo! : widget.original;

  Widget _muestra(Color fondo) => Expanded(
    child: Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: AppColores.borde),
      ),
      child: _procesando
          ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
          : Image.memory(_actual, fit: BoxFit.contain),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Logo de la app'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _muestra(const Color(0xFFF1F3F8)),
              const SizedBox(width: AppEspaciado.sm),
              _muestra(AppColores.relleno),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Quitar fondo'),
            subtitle: Text(
              _sinFondoQueQuitar
                  ? 'Este logo ya no tiene un fondo liso que quitar'
                  : 'Borra el color liso que rodea al logo',
              style: const TextStyle(fontSize: 12),
            ),
            value: _quitarFondo,
            onChanged: _procesando || _sinFondoQueQuitar
                ? null
                : (v) {
                    setState(() => _quitarFondo = v);
                    if (v) _procesar();
                  },
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _procesando ? null : () => Navigator.pop(context, _actual),
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}

class _TituloSeccion extends StatelessWidget {
  final String titulo;
  final String subtitulo;

  const _TituloSeccion({required this.titulo, required this.subtitulo});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              letterSpacing: 1.4,
              fontWeight: FontWeight.w700,
              color: AppColores.primario,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitulo,
            style: const TextStyle(
              fontSize: 13,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaPlantilla extends StatelessWidget {
  final PaletaApp paleta;
  final bool seleccionada;
  final bool guardando;
  final VoidCallback onTap;

  const _TarjetaPlantilla({
    required this.paleta,
    required this.seleccionada,
    required this.guardando,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: radio,
        border: Border.all(
          color: seleccionada ? AppColores.primario : AppColores.borde,
          width: seleccionada ? 2 : 1,
        ),
        boxShadow: seleccionada ? AppSombras.tarjeta : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: radio,
          onTap: seleccionada ? null : onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(child: _Maqueta(paleta: paleta)),
                      if (seleccionada || guardando)
                        Positioned(
                          top: 6,
                          right: 6,
                          child: Container(
                            width: 24,
                            height: 24,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: AppColores.primario,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: guardando
                                ? const CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  )
                                : const Icon(
                                    Icons.check,
                                    size: 12,
                                    color: Colors.white,
                                  ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paleta.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                    ),
                    _Puntos(paleta: paleta),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  paleta.descripcion,
                  maxLines: 2,
                  style: const TextStyle(
                    fontSize: 11.5,
                    height: 1.3,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tres puntos con los colores clave de la paleta.
class _Puntos extends StatelessWidget {
  final PaletaApp paleta;

  const _Puntos({required this.paleta});

  @override
  Widget build(BuildContext context) {
    final colores = [paleta.relleno, paleta.primario, paleta.acento];
    return SizedBox(
      width: 34,
      height: 14,
      child: Stack(
        children: [
          for (var i = 0; i < colores.length; i++)
            Positioned(
              left: i * 10.0,
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colores[i],
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Maqueta en miniatura de la pantalla de inicio con la paleta: barra
/// superior, tarjeta de membresía, una fila de datos y el botón principal.
class _Maqueta extends StatelessWidget {
  final PaletaApp paleta;

  const _Maqueta({required this.paleta});

  Widget _barra(double ancho, Color color, {double alto = 4}) => Container(
    width: ancho,
    height: alto,
    decoration: BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(alto),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final borde = paleta.bordeRelleno;
    final lado = borde == null ? null : Border.all(color: borde, width: 1.2);
    return Container(
      decoration: BoxDecoration(
        color: paleta.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: paleta.borde.withValues(alpha: 0.8)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior
          Container(
            height: 22,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: paleta.relleno,
              border: borde == null
                  ? null
                  : Border(bottom: BorderSide(color: borde, width: 1.2)),
            ),
            child: Row(
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: paleta.sobreRelleno,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 5),
                _barra(28, paleta.sobreRelleno),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Tarjeta de membresía
                  Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 7),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [paleta.relleno, paleta.rellenoClaro],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(7),
                      border: lado,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _barra(18, paleta.sobreRellenoSuave, alto: 3),
                        const SizedBox(height: 4),
                        _barra(34, paleta.sobreRelleno, alto: 5),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Fila de datos
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: paleta.superficie,
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(color: paleta.borde),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 13,
                            height: 13,
                            decoration: BoxDecoration(
                              color: paleta.primario.withValues(alpha: 0.12),
                              shape: BoxShape.circle,
                            ),
                            alignment: Alignment.center,
                            child: Container(
                              width: 5,
                              height: 5,
                              decoration: BoxDecoration(
                                color: paleta.primario,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _barra(
                                  30,
                                  paleta.textoPrincipal.withValues(alpha: 0.7),
                                  alto: 3,
                                ),
                                const SizedBox(height: 3),
                                _barra(
                                  20,
                                  paleta.textoPrincipal.withValues(alpha: 0.3),
                                  alto: 3,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Botón principal
                  Container(
                    height: 15,
                    decoration: BoxDecoration(
                      color: paleta.relleno,
                      borderRadius: BorderRadius.circular(6),
                      border: lado,
                    ),
                    alignment: Alignment.center,
                    child: _barra(22, paleta.sobreRelleno, alto: 3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MuestraColor extends StatelessWidget {
  final Color color;
  final bool seleccionada;
  final VoidCallback onTap;

  const _MuestraColor({
    required this.color,
    required this.seleccionada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: seleccionada ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 42,
        height: 42,
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: seleccionada ? color : Colors.transparent,
            width: 2,
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.35),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: seleccionada
              ? const Icon(Icons.check, color: Colors.white, size: 18)
              : null,
        ),
      ),
    );
  }
}
