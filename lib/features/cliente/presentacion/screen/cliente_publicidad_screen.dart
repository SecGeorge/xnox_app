import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';

/// Pantalla de inicio del cliente: muestra la publicidad del gimnasio
/// (solo lectura). Si el backend no devuelve campañas, usa una lista demo.
class ClientePublicidadScreen extends StatefulWidget {
  const ClientePublicidadScreen({super.key});

  @override
  State<ClientePublicidadScreen> createState() =>
      _ClientePublicidadScreenState();
}

class _ClientePublicidadScreenState extends State<ClientePublicidadScreen> {
  final _controlador = ControladorPublicidad();
  List<Publicidad> _publicidades = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    try {
      final data = await _controlador.fetchPublicidades();
      setState(() {
        _publicidades = data.isNotEmpty ? data : _demo();
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _publicidades = _demo();
        _isLoading = false;
      });
    }
  }

  // Publicidad demo mientras no haya backend.
  List<Publicidad> _demo() {
    final hoy = DateTime.now();
    return [
      Publicidad(
        titulo: '¡Verano fit! 2x1 en planes trimestrales',
        descripcion:
            'Trae a un amigo y entrenen juntos. Promo válida todo el mes.',
        fechaInicio: hoy.subtract(const Duration(days: 3)),
        fechaFin: hoy.add(const Duration(days: 20)),
      ),
      Publicidad(
        titulo: 'Nueva zona de peso libre',
        descripcion:
            'Renovamos el área de pesas con racks y mancuernas hasta 50 kg.',
        fechaInicio: hoy.subtract(const Duration(days: 10)),
        fechaFin: hoy.add(const Duration(days: 40)),
      ),
      Publicidad(
        titulo: 'Clases de funcional — Martes y Jueves 7pm',
        descripcion: 'Cupos limitados. Inscríbete en recepción.',
        fechaInicio: hoy.subtract(const Duration(days: 1)),
        fechaFin: hoy.add(const Duration(days: 15)),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _cargar,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                    AppEspaciado.lg, AppEspaciado.md, AppEspaciado.lg),
                children: [
                  const Text(
                    'Bienvenido 👋',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Novedades y promociones del gimnasio',
                    style: TextStyle(
                        fontSize: 13.5, color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  ..._publicidades.map(_buildTarjeta),
                ],
              ),
      ),
    );
  }

  Widget _buildTarjeta(Publicidad p) {
    final formato = DateFormat('d MMM', 'es');
    final vigencia =
        '${formato.format(p.fechaInicio)} – ${formato.format(p.fechaFin)}';

    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.md),
      child: TarjetaApp(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen o banner de marca.
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(AppEspaciado.radio)),
              child: p.imagenUrl != null && p.imagenUrl!.isNotEmpty
                  ? Image.network(p.imagenUrl!,
                      height: 140, width: double.infinity, fit: BoxFit.cover,
                      errorBuilder: (context, error, stack) => _banner())
                  : _banner(),
            ),
            Padding(
              padding: const EdgeInsets.all(AppEspaciado.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.titulo,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    p.descripcion,
                    style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.35,
                        color: AppColores.textoSecundario),
                  ),
                  const SizedBox(height: AppEspaciado.sm + 4),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined,
                          size: 14, color: AppColores.textoSecundario),
                      const SizedBox(width: 6),
                      Text(
                        vigencia,
                        style: const TextStyle(
                            fontSize: 12, color: AppColores.textoSecundario),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _banner() {
    return Container(
      height: 140,
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: const Center(
        child: Icon(Icons.campaign, color: Colors.white70, size: 48),
      ),
    );
  }
}
