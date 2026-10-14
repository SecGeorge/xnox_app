import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/cliente/datos/almacen_medidas.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/composicion_corporal.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/composicion_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/detalle_medida_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Medidas corporales del socio: una tarjeta con foto por cada músculo, con la
/// última medida y cuánto cambió desde la primera.
///
/// Con [medidas] la usa el personal para ver las de un socio: solo lectura,
/// sin sincronizar ni IMC (el IMC tiene su propio acceso en la ficha).
class MedidasScreen extends StatefulWidget {
  final List<Medida>? medidas;
  final String? nombre;

  const MedidasScreen({super.key, this.medidas, this.nombre});

  @override
  State<MedidasScreen> createState() => _MedidasScreenState();
}

class _MedidasScreenState extends State<MedidasScreen> {
  List<Medida> _medidas = const [];

  /// Altura, sexo y edad (de Nutrición) para el IMC. Null sin conexión.
  PerfilNutricion? _perfil;

  bool get _soloVer => widget.medidas != null;

  @override
  void initState() {
    super.initState();
    if (_soloVer) {
      _medidas = widget.medidas!;
    } else {
      _cargar();
    }
  }

  /// Pinta primero lo del teléfono y luego lo sincroniza con la BD central
  /// (sube lo pendiente y trae lo registrado desde otro equipo).
  Future<void> _cargar() async {
    await _leerLocal();
    _cargarPerfil();
    try {
      await AlmacenMedidas.instancia.sincronizar();
    } catch (_) {
      // Sin servidor se queda con lo local; se reintenta al volver a entrar.
    }
    await _leerLocal();
  }

  Future<void> _leerLocal() async {
    final lista = await AlmacenMedidas.instancia.listar();
    if (!mounted) return;
    setState(() => _medidas = lista);
  }

  Future<void> _cargarPerfil() async {
    try {
      final hoy = DateTime.now();
      final r = await RepositorioNutricion().resumen(desde: hoy, hasta: hoy);
      if (!mounted) return;
      setState(() => _perfil = r.perfil);
    } catch (_) {
      // Sin conexión o sin módulo de nutrición: no se muestra el IMC.
    }
  }

  List<Medida> get _pesos => _de(ZonaMedida.peso);

  ComposicionCorporal? get _composicion {
    final p = _perfil;
    if (p == null) return null;
    final pesos = _pesos;
    return ComposicionCorporal.calcular(
      pesoKg: pesos.isEmpty ? p.peso : pesos.last.valor,
      alturaCm: p.alturaCm,
      edad: p.edad,
      sexo: p.sexo,
    );
  }

  Future<void> _completarDatos() async {
    final p = _perfil;
    if (p == null) return;
    if (await editarPerfilNutricion(context, perfil: p)) {
      await _leerLocal();
      await _cargarPerfil();
    }
  }

  Future<void> _abrirImc(ComposicionCorporal c) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ComposicionScreen(
          composicion: c,
          pesos: [for (final m in _pesos) PuntoEvolucion(m.fecha, m.valor)],
          onCompletarDatos: () {
            Navigator.of(context).pop();
            _completarDatos();
          },
        ),
      ),
    );
  }

  /// Portada del IMC: el resultado, o qué falta para calcularlo.
  Widget _portadaImc() {
    final c = _composicion;
    if (c != null) {
      return PortadaNutricion(
        foto: ComposicionScreen.fotoCuerpo,
        alineacion: const Alignment(0, -0.35),
        icono: Icons.monitor_weight_rounded,
        chip: 'Tu IMC',
        alto: 150,
        titulo: 'IMC ${numeroMedida(c.imc)} · ${c.nivel.nombre}',
        detalle: c.consejoPeso(),
        onTap: () => _abrirImc(c),
        accion: BotonFoto(
          'Ver IMC y peso ideal',
          icono: Icons.arrow_forward_rounded,
          onTap: () => _abrirImc(c),
        ),
      );
    }
    final sinAltura = _perfil!.alturaCm == null;
    return PortadaNutricion(
      foto: ComposicionScreen.fotoCuerpo,
      alineacion: const Alignment(0, -0.35),
      icono: Icons.monitor_weight_rounded,
      chip: 'Tu IMC',
      alto: 150,
      titulo: 'Calcula tu IMC',
      detalle: sinAltura
          ? 'Indica tu altura y verás tu IMC y tu peso ideal'
          : 'Registra tu peso y verás tu IMC y tu peso ideal',
      accion: BotonFoto(
        sinAltura ? 'Poner mi altura' : 'Registrar mi peso',
        icono: sinAltura ? Icons.height_rounded : Icons.monitor_weight_rounded,
        onTap: sinAltura ? _completarDatos : () => _abrir(ZonaMedida.peso),
      ),
    );
  }

  List<Medida> _de(ZonaMedida zona) =>
      _medidas.where((m) => m.zona == zona.clave).toList();

  Future<void> _abrir(ZonaMedida zona) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetalleMedidaScreen(
          zona: zona,
          registros: _soloVer ? _de(zona) : null,
        ),
      ),
    );
    if (!_soloVer) await _leerLocal();
  }

  @override
  Widget build(BuildContext context) {
    final medidas = ZonaMedida.todas.where((z) => _de(z).isNotEmpty).length;
    final ultima = _medidas.isEmpty ? null : _medidas.last.fecha;

    return PantallaApp(
      onRefresh: _soloVer ? null : _cargar,
      espacioAbajo: AppEspaciado.lg,
      children: [
        CabeceraApp(
          titulo: _soloVer ? 'Medidas' : 'Mis medidas',
          subtitulo: _soloVer
              ? widget.nombre
              : 'Mide tus músculos y mira cómo cambian',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        // Alto mínimo: con letra grande crece en vez de desbordarse.
        PortadaNutricion(
          foto: FotosApp.brazos,
          alineacion: const Alignment(0.4, -0.2),
          icono: Icons.straighten_rounded,
          chip: 'Última medición',
          alto: 170,
          titulo: ultima == null
              ? (_soloVer ? 'Sin medidas' : 'Mídete hoy')
              : DateFormat("d 'de' MMMM", 'es').format(ultima),
          pie: [
            DatoPie(
              icono: Icons.straighten_rounded,
              valor: '$medidas/${ZonaMedida.todas.length}',
              pie: 'zonas medidas',
            ),
            DatoPie(
              icono: Icons.history_rounded,
              valor: '${_medidas.length}',
              pie: _medidas.length == 1 ? 'registro' : 'registros',
            ),
          ],
        ),
        if (_perfil != null) ...[
          const SizedBox(height: AppEspaciado.md),
          _portadaImc(),
        ],
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.accessibility_new_rounded,
          titulo: _soloVer ? 'Sus músculos' : 'Tus músculos',
        ),
        Text(
          _soloVer
              ? 'Toca una zona para ver su evolución e historial.'
              : 'Mídete con cinta métrica, en relajado y a la misma hora. '
                    'Toca una zona para registrar su medida.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AppColores.textoSecundario,
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        // De dos en dos y sin alto fijo: con letra grande la tarjeta crece.
        for (var i = 0; i < ZonaMedida.todas.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
            child: Row(
              children: [
                Expanded(child: _tarjetaZona(ZonaMedida.todas[i])),
                const SizedBox(width: AppEspaciado.sm + 4),
                Expanded(
                  child: i + 1 < ZonaMedida.todas.length
                      ? _tarjetaZona(ZonaMedida.todas[i + 1])
                      : const SizedBox(),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _tarjetaZona(ZonaMedida zona) {
    final registros = _de(zona);
    final ultima = registros.isEmpty ? null : registros.last.valor;
    final cambio = registros.length < 2
        ? null
        : registros.last.valor - registros.first.valor;

    return FotoTarjeta(
      foto: zona.foto,
      alineacion: zona.alineacion,
      radio: AppEspaciado.radio + 2,
      onTap: () => _abrir(zona),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 132),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColores.destacado,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      zona.icono,
                      size: 19,
                      color: _tintaSobreDestacado,
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (cambio != null && cambio != 0)
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: ChipCambioMedida(zona: zona, cambio: cambio),
                      ),
                    ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    zona.nombre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    ultima == null
                        ? 'Sin medir'
                        : '${numeroMedida(ultima)} ${zona.unidad}',
                    style: TextStyle(
                      fontSize: ultima == null ? 12 : 18,
                      height: 1.2,
                      fontWeight: ultima == null
                          ? FontWeight.w500
                          : FontWeight.w800,
                      color: ultima == null
                          ? Colors.white.withValues(alpha: 0.75)
                          : AppColores.destacado,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tinta legible sobre el color destacado (igual que en el inicio).
  Color get _tintaSobreDestacado =>
      AppColores.destacado.computeLuminance() > 0.45
      ? const Color(0xFF0E1A12)
      : Colors.white;
}

/// Píldora con el cambio de una medida ("+1.5 cm"), en verde si va hacia
/// donde conviene a esa zona, en rojo si va al revés y neutra si da igual.
class ChipCambioMedida extends StatelessWidget {
  final ZonaMedida zona;
  final double cambio;

  const ChipCambioMedida({super.key, required this.zona, required this.cambio});

  @override
  Widget build(BuildContext context) {
    final bueno = switch (zona.tendencia) {
      TendenciaMedida.subir => cambio > 0,
      TendenciaMedida.bajar => cambio < 0,
      TendenciaMedida.neutral => null,
    };
    final color = bueno == null
        ? Colors.white
        : bueno
        ? AppColores.activo
        : AppColores.moroso;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bueno == null
            ? Colors.white.withValues(alpha: 0.18)
            : Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            cambio > 0
                ? Icons.trending_up_rounded
                : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Flexible(
            child: Text(
              '${cambio > 0 ? '+' : ''}${numeroMedida(cambio)} ${zona.unidad}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
