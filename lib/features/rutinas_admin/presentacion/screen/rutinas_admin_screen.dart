import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/rutinas_miembro_screen.dart';

/// Sección "Rutinas" del personal: se elige un miembro y se gestionan sus
/// rutinas. Reutiliza la búsqueda de miembros ya existente.
class RutinasAdminScreen extends StatefulWidget {
  const RutinasAdminScreen({super.key});

  @override
  State<RutinasAdminScreen> createState() => _RutinasAdminScreenState();
}

class _RutinasAdminScreenState extends State<RutinasAdminScreen> {
  final _controlador = ControladorMiembros();
  List<Miembro> _miembros = [];
  bool _cargando = true;
  String? _error;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await _controlador.buscarMiembros();
      if (!mounted) return;
      setState(() {
        // Solo miembros activos: no se arman rutinas para vencidos/morosos.
        _miembros =
            lista.where((m) => m.estado == EstadoMiembro.activo).toList();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los miembros';
        _cargando = false;
      });
    }
  }

  List<Miembro> get _filtrados {
    // Sin búsqueda no listamos a todos: la lista puede ser enorme. Se muestra
    // un aviso para que el personal escriba el nombre o documento.
    final q = _busqueda.trim();
    if (q.isEmpty) return const [];
    final ql = q.toLowerCase();
    return _miembros
        .where((m) =>
            m.nombre.toLowerCase().contains(ql) || m.documento.contains(q))
        .toList();
  }

  Future<void> _abrirMiembro(Miembro m) async {
    if (m.id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RutinasMiembroScreen(
          miembroId: m.id!,
          nombreMiembro: m.nombre,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rutinas'),
        actions: const [CampanaAvisos()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, AppEspaciado.sm),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: const InputDecoration(
                hintText: 'Buscar miembro por nombre o documento',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          Expanded(child: _contenido()),
        ],
      ),
    );
  }

  Widget _contenido() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return EstadoVacio(icono: Icons.error_outline, mensaje: _error!);
    }
    if (_busqueda.trim().isEmpty) {
      return const EstadoVacio(
        icono: Icons.search,
        mensaje:
            'Busca un miembro por nombre o documento para ver o crear su rutina.',
      );
    }
    final filtrados = _filtrados;
    if (filtrados.isEmpty) {
      return const EstadoVacio(
        icono: Icons.person_search,
        mensaje: 'No hay miembros activos que coincidan con la búsqueda.',
      );
    }
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(
            AppEspaciado.md, 0, AppEspaciado.md, AppEspaciado.lg),
        itemCount: filtrados.length,
        separatorBuilder: (_, _) => const SizedBox(height: AppEspaciado.sm + 2),
        itemBuilder: (_, i) => _tarjetaMiembro(filtrados[i]),
      ),
    );
  }

  Widget _tarjetaMiembro(Miembro m) {
    return TarjetaApp(
      onTap: () => _abrirMiembro(m),
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: AppEspaciado.sm + 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColores.primario.withValues(alpha: 0.08),
            child: const Icon(Icons.fitness_center,
                color: AppColores.primario, size: 22),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  m.documento.isEmpty ? m.plan : 'Doc: ${m.documento}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColores.textoSecundario),
        ],
      ),
    );
  }
}
