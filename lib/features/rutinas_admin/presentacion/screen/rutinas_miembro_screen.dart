import 'package:flutter/material.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/rutinas_admin/datos/repositorio_rutinas_admin.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/form_rutina_admin_screen.dart';

/// Rutinas personalizadas de un miembro. Permite ver, asignar una plantilla,
/// crear/editar y anular/eliminar (según el permiso de gestión).
class RutinasMiembroScreen extends StatefulWidget {
  final int miembroId;
  final String nombreMiembro;

  const RutinasMiembroScreen({
    super.key,
    required this.miembroId,
    required this.nombreMiembro,
  });

  @override
  State<RutinasMiembroScreen> createState() => _RutinasMiembroScreenState();
}

class _RutinasMiembroScreenState extends State<RutinasMiembroScreen> {
  final _repo = RepositorioRutinasAdmin();
  List<RutinaResumen> _rutinas = [];
  bool _cargando = true;
  bool _puedeGestionar = false;

  @override
  void initState() {
    super.initState();
    _cargarPermisos();
    _cargar();
  }

  Future<void> _cargarPermisos() async {
    final permisos = await Permisos.cargar();
    if (!mounted) return;
    setState(() =>
        _puedeGestionar = permisos.tiene(PermisosMovil.rutinasGestion));
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final lista = await _repo.listarDeMiembro(widget.miembroId);
      if (!mounted) return;
      setState(() {
        _rutinas = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudieron cargar las rutinas',
          tipo: TipoMensaje.error);
    }
  }

  Future<void> _nueva() async {
    final creado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormRutinaAdminScreen(miembroId: widget.miembroId),
      ),
    );
    if (creado == true) _cargar();
  }

  Future<void> _editar(RutinaResumen r) async {
    final editado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormRutinaAdminScreen(
          miembroId: widget.miembroId,
          rutinaId: r.id,
        ),
      ),
    );
    if (editado == true) _cargar();
  }

  Future<void> _asignarPlantilla() async {
    final plantillas = await _repo.listarPlantillas();
    if (!mounted) return;
    if (plantillas.isEmpty) {
      mostrarMensaje(context, 'No hay plantillas disponibles para asignar',
          tipo: TipoMensaje.advertencia);
      return;
    }
    final elegida = await showModalBottomSheet<RutinaResumen>(
      context: context,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppEspaciado.md),
              child: Text('Asignar una plantilla',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal)),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: plantillas.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = plantillas[i];
                  return ListTile(
                    leading: const Icon(Icons.fitness_center,
                        color: AppColores.primario),
                    title: Text(p.nombre),
                    subtitle: Text(
                        '${p.totalDias} día(s) · ${p.totalEjercicios} ejercicio(s)'),
                    onTap: () => Navigator.pop(ctx, p),
                  );
                },
              ),
            ),
            const SizedBox(height: AppEspaciado.sm),
          ],
        ),
      ),
    );
    if (elegida == null) return;
    final error = await _repo.asignarPlantilla(elegida.id, widget.miembroId);
    if (!mounted) return;
    if (error == null) {
      mostrarMensaje(context, 'Rutina asignada correctamente',
          tipo: TipoMensaje.exito);
      _cargar();
    } else {
      mostrarMensaje(context, error, tipo: TipoMensaje.error);
    }
  }

  Future<void> _cambiarEstado(RutinaResumen r, String accion) async {
    if (accion == 'eliminar') {
      final ok = await confirmarDialog(
        context,
        titulo: 'Eliminar rutina',
        mensaje: '¿Seguro que deseas eliminar "${r.nombre}"?',
        icono: Icons.delete_outline,
        textoConfirmar: 'Eliminar',
        peligro: true,
      );
      if (!ok) return;
    }
    final error = accion == 'eliminar'
        ? await _repo.eliminar(r.id)
        : (r.activa ? await _repo.anular(r.id) : await _repo.activar(r.id));
    if (!mounted) return;
    if (error == null) {
      _cargar();
    } else {
      mostrarMensaje(context, error, tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nombreMiembro)),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : _rutinas.isEmpty
              ? const EstadoVacio(
                  icono: Icons.fitness_center,
                  mensaje:
                      'Este miembro aún no tiene rutinas.\nCrea una o asigna una plantilla.',
                )
              : RefreshIndicator(
                  onRefresh: _cargar,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                        AppEspaciado.md, AppEspaciado.md, 96),
                    itemCount: _rutinas.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppEspaciado.sm + 4),
                    itemBuilder: (_, i) => _tarjeta(_rutinas[i]),
                  ),
                ),
      floatingActionButton: _puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: _nueva,
              backgroundColor: AppColores.primario,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('Nueva'),
            )
          : null,
      persistentFooterButtons: _puedeGestionar
          ? [
              TextButton.icon(
                onPressed: _asignarPlantilla,
                icon: const Icon(Icons.playlist_add_check),
                label: const Text('Asignar plantilla'),
              ),
            ]
          : null,
    );
  }

  Widget _tarjeta(RutinaResumen r) {
    return TarjetaApp(
      onTap: _puedeGestionar ? () => _editar(r) : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.nombre,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                    ),
                    EtiquetaEstado(
                      texto: r.activa ? 'Activa' : 'Inactiva',
                      color: r.activa ? AppColores.activo : AppColores.vencido,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${r.totalDias} día(s) · ${r.totalEjercicios} ejercicio(s)'
                  '${r.origenNombre != null ? ' · de "${r.origenNombre}"' : ''}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColores.textoSecundario),
                ),
              ],
            ),
          ),
          if (_puedeGestionar)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert,
                  color: AppColores.textoSecundario),
              onSelected: (op) {
                if (op == 'editar') _editar(r);
                if (op == 'estado') _cambiarEstado(r, 'estado');
                if (op == 'eliminar') _cambiarEstado(r, 'eliminar');
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'editar', child: Text('Editar')),
                PopupMenuItem(
                    value: 'estado',
                    child: Text(r.activa ? 'Desactivar' : 'Activar')),
                const PopupMenuItem(
                  value: 'eliminar',
                  child: Text('Eliminar',
                      style: TextStyle(color: AppColores.moroso)),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
