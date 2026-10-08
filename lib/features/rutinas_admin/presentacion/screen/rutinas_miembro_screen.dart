import 'package:flutter/material.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
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
    setState(
      () => _puedeGestionar = permisos.tiene(PermisosMovil.rutinasGestion),
    );
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
      mostrarMensaje(
        context,
        'No se pudieron cargar las rutinas',
        tipo: TipoMensaje.error,
      );
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
        builder: (_) =>
            FormRutinaAdminScreen(miembroId: widget.miembroId, rutinaId: r.id),
      ),
    );
    if (editado == true) _cargar();
  }

  Future<void> _asignarPlantilla() async {
    final plantillas = await _repo.listarPlantillas();
    if (!mounted) return;
    if (plantillas.isEmpty) {
      mostrarMensaje(
        context,
        'No hay plantillas disponibles para asignar',
        tipo: TipoMensaje.advertencia,
      );
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
            Padding(
              padding: EdgeInsets.all(AppEspaciado.md),
              child: Text(
                'Asignar una plantilla',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColores.textoPrincipal,
                ),
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: plantillas.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final p = plantillas[i];
                  return ListTile(
                    leading: Icon(
                      Icons.fitness_center,
                      color: AppColores.primario,
                    ),
                    title: Text(p.nombre),
                    subtitle: Text(
                      '${p.totalDias} día(s) · ${p.totalEjercicios} ejercicio(s)',
                    ),
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
      mostrarMensaje(
        context,
        'Rutina asignada correctamente',
        tipo: TipoMensaje.exito,
      );
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

  static const _fotos = [
    FotosApp.pecho,
    FotosApp.espalda,
    FotosApp.piernas,
    FotosApp.hombros,
    FotosApp.gluteos,
    FotosApp.brazos,
  ];

  @override
  Widget build(BuildContext context) {
    final activas = _rutinas.where((r) => r.activa).length;
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: 110,
      botonFlotante: _puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: _nueva,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva'),
            )
          : null,
      children: [
        CabeceraApp(
          titulo: widget.nombreMiembro,
          subtitulo: 'Rutinas del socio',
          acciones: [
            if (_puedeGestionar)
              BotonRedondo(
                icono: Icons.playlist_add_check_rounded,
                tooltip: 'Asignar plantilla',
                onTap: _asignarPlantilla,
              ),
          ],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.inicio,
          alineacion: const Alignment(0.6, -0.4),
          etiqueta: 'Plan de entrenamiento',
          titulo: _cargando
              ? '…'
              : activas == 1
              ? '1 rutina activa'
              : '$activas rutinas activas',
          texto: 'Crea una nueva o asígnale una plantilla del gimnasio.',
        ),
        if (_puedeGestionar) ...[
          const SizedBox(height: AppEspaciado.sm + 4),
          TarjetaPlana(
            onTap: _asignarPlantilla,
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const IconoSuave(Icons.playlist_add_check_rounded),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Asignar plantilla',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      const Text(
                        'Copia una rutina sugerida del gimnasio',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, color: AppColores.primario),
              ],
            ),
          ),
        ],
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.fitness_center_rounded,
          titulo: 'Rutinas',
          detalle: _cargando ? null : '${_rutinas.length}',
        ),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_rutinas.isEmpty)
          const VacioApp(
            icono: Icons.fitness_center_rounded,
            titulo: 'Aún no tiene rutinas',
            texto: 'Crea una o asígnale una plantilla.',
          )
        else
          for (var i = 0; i < _rutinas.length; i++) ...[
            _tarjeta(_rutinas[i], _fotos[i % _fotos.length]),
            const SizedBox(height: AppEspaciado.sm + 4),
          ],
      ],
    );
  }

  Widget _tarjeta(RutinaResumen r, String foto) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
        border: Border.all(color: AppColores.borde),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _puedeGestionar ? () => _editar(r) : null,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 92,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      Image.asset(foto, fit: BoxFit.cover, cacheWidth: 300),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColores.primario.withValues(alpha: 0.25),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          r.nombre,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${r.totalDias} ${r.totalDias == 1 ? 'día' : 'días'} · '
                          '${r.totalEjercicios} ${r.totalEjercicios == 1 ? 'ejercicio' : 'ejercicios'}'
                          '${r.origenNombre != null ? ' · de "${r.origenNombre}"' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 8),
                        EtiquetaEstado(
                          texto: r.activa ? 'Activa' : 'Inactiva',
                          color: r.activa
                              ? AppColores.activo
                              : AppColores.vencido,
                        ),
                      ],
                    ),
                  ),
                ),
                if (_puedeGestionar)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColores.textoSecundario,
                    ),
                    onSelected: (op) {
                      if (op == 'editar') _editar(r);
                      if (op == 'estado') _cambiarEstado(r, 'estado');
                      if (op == 'eliminar') _cambiarEstado(r, 'eliminar');
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: 'estado',
                        child: Text(r.activa ? 'Desactivar' : 'Activar'),
                      ),
                      const PopupMenuItem(
                        value: 'eliminar',
                        child: Text(
                          'Eliminar',
                          style: TextStyle(color: AppColores.moroso),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
