import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
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
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de campañas')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _campanias.isEmpty
              ? const EstadoVacio(
                  icono: Icons.history,
                  mensaje: 'Aún no se han registrado campañas.',
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.all(AppEspaciado.md),
                    itemCount: _campanias.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppEspaciado.sm + 4),
                    itemBuilder: (_, i) => _tarjeta(_campanias[i]),
                  ),
                ),
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
                child: Text(c.plantillaNombre,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal)),
              ),
              EtiquetaEstado(texto: c.estado, color: _colorEstado(c.estado)),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today,
                  size: 14, color: AppColores.textoSecundario),
              const SizedBox(width: 4),
              Text(c.fechaCreacion,
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColores.textoSecundario)),
              const SizedBox(width: AppEspaciado.md),
              const Icon(Icons.person_outline,
                  size: 14, color: AppColores.textoSecundario),
              const SizedBox(width: 4),
              Expanded(
                child: Text(c.administrador.isEmpty ? '—' : c.administrador,
                    style: const TextStyle(
                        fontSize: 12.5, color: AppColores.textoSecundario)),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              EtiquetaEstado(texto: c.filtro, color: AppColores.acento),
              const Spacer(),
              Icon(Icons.people_outline,
                  size: 16, color: AppColores.textoSecundario),
              const SizedBox(width: 4),
              Text('${c.totalClientes} clientes',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColores.textoPrincipal)),
            ],
          ),
        ],
      ),
    );
  }
}
