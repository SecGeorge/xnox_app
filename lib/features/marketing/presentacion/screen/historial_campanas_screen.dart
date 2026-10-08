import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/marketing/dominio/entidades/campania.dart';
import 'package:xnox_app/features/marketing/presentacion/controlador/controlador_mensajeria.dart';

class HistorialCampanasScreen extends StatefulWidget {
  const HistorialCampanasScreen({super.key});

  @override
  State<HistorialCampanasScreen> createState() =>
      _HistorialCampanasScreenState();
}

class _HistorialCampanasScreenState extends State<HistorialCampanasScreen> {
  final _controlador = ControladorMensajeria();
  List<Campania> _campanias = [];
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final lista = await _controlador.listarCampanias();
      if (!mounted) return;
      setState(() {
        _campanias = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
    }
  }

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Completado':
        return AppColores.exito;
      case 'Cancelado':
        return AppColores.error;
      default:
        return AppColores.vencido;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: _cargar,
      children: [
        const CabeceraApp(
          titulo: 'Historial',
          subtitulo: 'Campañas de WhatsApp enviadas',
        ),
        const SizedBox(height: AppEspaciado.lg),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_campanias.isEmpty)
          const VacioApp(
            icono: Icons.history_rounded,
            titulo: 'Aún no hay campañas',
            texto: 'Las que envíes quedarán registradas aquí.',
          )
        else
          for (final c in _campanias) ...[
            _tarjeta(c),
            const SizedBox(height: AppEspaciado.sm + 4),
          ],
      ],
    );
  }

  Widget _tarjeta(Campania c) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.plantillaNombre,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              EtiquetaEstado(texto: c.estado, color: _colorEstado(c.estado)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 14,
                color: AppColores.textoSecundario,
              ),
              const SizedBox(width: 4),
              Text(
                c.fechaCreacion,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColores.textoSecundario,
                ),
              ),
              const SizedBox(width: AppEspaciado.md),
              const Icon(
                Icons.person_outline,
                size: 14,
                color: AppColores.textoSecundario,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  c.administrador.isEmpty ? '—' : c.administrador,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              EtiquetaEstado(texto: c.filtro, color: AppColores.acento),
              const Spacer(),
              Icon(
                Icons.people_outline,
                size: 16,
                color: AppColores.textoSecundario,
              ),
              const SizedBox(width: 4),
              Text(
                '${c.totalClientes} clientes',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
