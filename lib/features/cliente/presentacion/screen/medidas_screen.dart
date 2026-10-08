import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/cliente/datos/almacen_medidas.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/detalle_medida_screen.dart';

/// Medidas corporales del socio: una tarjeta con foto por cada músculo, con la
/// última medida y cuánto cambió desde la primera.
class MedidasScreen extends StatefulWidget {
  const MedidasScreen({super.key});

  @override
  State<MedidasScreen> createState() => _MedidasScreenState();
}

class _MedidasScreenState extends State<MedidasScreen> {
  List<Medida> _medidas = const [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Pinta primero lo del teléfono y luego lo sincroniza con la BD central
  /// (sube lo pendiente y trae lo registrado desde otro equipo).
  Future<void> _cargar() async {
    await _leerLocal();
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

  List<Medida> _de(ZonaMedida zona) =>
      _medidas.where((m) => m.zona == zona.clave).toList();

  Future<void> _abrir(ZonaMedida zona) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalleMedidaScreen(zona: zona)),
    );
    await _leerLocal();
  }

  @override
  Widget build(BuildContext context) {
    final medidas = ZonaMedida.todas.where((z) => _de(z).isNotEmpty).length;
    final ultima = _medidas.isEmpty ? null : _medidas.last.fecha;

    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: AppEspaciado.lg,
      children: [
        const CabeceraApp(
          titulo: 'Mis medidas',
          subtitulo: 'Mide tus músculos y mira cómo cambian',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.brazos,
          altura: 170,
          etiqueta: 'Última medición',
          titulo: ultima == null
              ? 'Mídete hoy'
              : DateFormat("d 'de' MMMM", 'es').format(ultima),
          pie: Row(
            children: [
              DatoPortada(
                icono: Icons.straighten_rounded,
                valor: '$medidas/${ZonaMedida.todas.length}',
                pie: 'zonas medidas',
              ),
              const SizedBox(width: 18),
              DatoPortada(
                icono: Icons.history_rounded,
                valor: '${_medidas.length}',
                pie: _medidas.length == 1 ? 'registro' : 'registros',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.accessibility_new_rounded,
          titulo: 'Tus músculos',
        ),
        const Text(
          'Mídete con cinta métrica, en relajado y a la misma hora. '
          'Toca una zona para registrar su medida.',
          style: TextStyle(
            fontSize: 13,
            height: 1.35,
            color: AppColores.textoSecundario,
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: AppEspaciado.sm + 4,
          crossAxisSpacing: AppEspaciado.sm + 4,
          childAspectRatio: 1.05,
          children: [
            for (final zona in ZonaMedida.todas) _tarjetaZona(zona),
          ],
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
        child: Column(
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
                  child: Icon(zona.icono, size: 19, color: _tintaSobreDestacado),
                ),
                const Spacer(),
                if (cambio != null && cambio != 0)
                  ChipCambioMedida(zona: zona, cambio: cambio),
              ],
            ),
            const Spacer(),
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
                fontWeight: ultima == null ? FontWeight.w500 : FontWeight.w800,
                color: ultima == null
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppColores.destacado,
              ),
            ),
          ],
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
            cambio > 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 3),
          Text(
            '${cambio > 0 ? '+' : ''}${numeroMedida(cambio)} ${zona.unidad}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
