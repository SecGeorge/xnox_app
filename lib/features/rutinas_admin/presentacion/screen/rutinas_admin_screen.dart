import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/rutinas_admin/datos/repositorio_rutinas_admin.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/fuente_rutina.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/form_rutina_admin_screen.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/rutinas_miembro_screen.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/widget/tarjeta_rutina_resumen.dart';

/// Sección "Rutinas" del personal: las rutinas generales del gimnasio (como
/// la pantalla Rutinas del web) y, buscando a un socio, sus rutinas.
class RutinasAdminScreen extends StatefulWidget {
  const RutinasAdminScreen({super.key});

  @override
  State<RutinasAdminScreen> createState() => _RutinasAdminScreenState();
}

class _RutinasAdminScreenState extends State<RutinasAdminScreen> {
  final _controlador = ControladorMiembros();
  final _repo = RepositorioRutinasAdmin();
  List<Miembro> _miembros = [];
  List<RutinaResumen> _generales = [];
  bool _cargandoGenerales = true;
  bool _puedeGestionar = false;
  bool _cargando = true;
  String? _error;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarGenerales();
    Permisos.cargar().then((p) {
      if (mounted) setState(() => _puedeGestionar = p.tiene(PermisosMovil.rutinasGestion));
    });
  }

  /// Todas las rutinas generales de la sucursal, activas e inactivas.
  Future<void> _cargarGenerales() async {
    setState(() => _cargandoGenerales = true);
    try {
      final lista = await _repo.listarGenerales();
      if (!mounted) return;
      setState(() {
        _generales = lista;
        _cargandoGenerales = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cargandoGenerales = false);
    }
  }

  Future<void> _abrirEditor({int? rutinaId}) async {
    final guardo = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FormRutinaAdminScreen(fuente: FuenteRutinaServidor(rutinaId: rutinaId)),
      ),
    );
    if (guardo == true) _cargarGenerales();
  }

  Future<void> _accionGeneral(RutinaResumen r, String accion) async {
    if (accion == 'editar') return _abrirEditor(rutinaId: r.id);
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
    final error = switch (accion) {
      'eliminar' => await _repo.eliminar(r.id),
      'duplicar' => await _repo.duplicar(r.id),
      _ => r.activa ? await _repo.anular(r.id) : await _repo.activar(r.id),
    };
    if (!mounted) return;
    if (error == null) {
      _cargarGenerales();
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
        _miembros = lista
            .where((m) => m.estado == EstadoMiembro.activo)
            .toList();
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
        .where(
          (m) => m.nombre.toLowerCase().contains(ql) || m.documento.contains(q),
        )
        .toList();
  }

  Future<void> _abrirMiembro(Miembro m) async {
    if (m.id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            RutinasMiembroScreen(miembroId: m.id!, nombreMiembro: m.nombre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: () async {
        await Future.wait([_cargar(), _cargarGenerales()]);
      },
      espacioAbajo: 110,
      botonFlotante: _puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: () => _abrirEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva rutina'),
            )
          : null,
      children: [
        const CabeceraApp(
          titulo: 'Rutinas',
          subtitulo: 'Rutinas del gimnasio y de cada socio',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.rutinas,
          alineacion: const Alignment(0.2, -0.2),
          etiqueta: 'Entrenamiento',
          titulo: _cargando ? '…' : '${_miembros.length} socios activos',
          texto: 'Busca a un socio para ver o crear su rutina, o arma una general.',
        ),
        const SizedBox(height: AppEspaciado.md),
        BuscadorApp(
          hint: 'Buscar miembro por nombre o documento',
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: AppEspaciado.lg),
        ..._contenido(),
      ],
    );
  }

  List<Widget> _listaGenerales() {
    final activas = _generales.where((r) => r.activa).length;
    return [
      TituloSeccion(
        icono: Icons.fitness_center_rounded,
        titulo: 'Rutinas generales',
        detalle: _cargandoGenerales ? null : '$activas activas · ${_generales.length}',
      ),
      if (_cargandoGenerales)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Center(child: CircularProgressIndicator()),
        )
      else if (_generales.isEmpty)
        const VacioApp(
          icono: Icons.fitness_center_rounded,
          titulo: 'Aún no hay rutinas generales',
          texto: 'Crea la primera con "Nueva rutina".',
        )
      else
        for (var i = 0; i < _generales.length; i++) ...[
          TarjetaRutinaResumen(
            r: _generales[i],
            foto: _fotos[i % _fotos.length],
            puedeGestionar: _puedeGestionar,
            onAccion: (op) => _accionGeneral(_generales[i], op),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
        ],
    ];
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return [
        VacioApp(
          icono: Icons.cloud_off_rounded,
          titulo: _error!,
          texto: 'Desliza hacia abajo para reintentar.',
        ),
      ];
    }
    // Sin búsqueda: las rutinas generales del gimnasio.
    if (_busqueda.trim().isEmpty) return _listaGenerales();
    final filtrados = _filtrados;
    if (filtrados.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.search_off_rounded,
          titulo: 'Sin coincidencias',
          texto: 'No hay miembros activos que coincidan con la búsqueda.',
        ),
      ];
    }
    return [
      TituloSeccion(
        icono: Icons.people_alt_rounded,
        titulo: 'Resultados',
        detalle: '${filtrados.length}',
      ),
      GrupoFilas(
        filas: [
          for (final m in filtrados)
            FilaApp(
              onTap: () => _abrirMiembro(m),
              inicio: Container(
                width: 46,
                height: 46,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: AppColores.degradadoRelleno,
                  border: AppColores.bordeCabecera,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  m.iniciales,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColores.sobreRelleno,
                  ),
                ),
              ),
              titulo: m.nombre,
              subtitulo: m.documento.isEmpty ? m.plan : 'Doc: ${m.documento}',
              fin: const IconoSuave(
                Icons.fitness_center_rounded,
                tamano: 36,
                circular: true,
              ),
            ),
        ],
      ),
    ];
  }
}
