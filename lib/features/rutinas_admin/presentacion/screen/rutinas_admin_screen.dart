import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
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
      onRefresh: _cargar,
      children: [
        const CabeceraApp(
          titulo: 'Rutinas',
          subtitulo: 'Arma y asigna rutinas semanales a tus socios',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.rutinas,
          alineacion: const Alignment(0.2, -0.2),
          etiqueta: 'Entrenamiento',
          titulo: _cargando ? '…' : '${_miembros.length} socios activos',
          texto: 'Busca a un socio para ver o crear su rutina de la semana.',
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
    if (_busqueda.trim().isEmpty) {
      return const [
        VacioApp(
          icono: Icons.person_search_rounded,
          titulo: '¿A quién le armas la rutina?',
          texto: 'Escribe el nombre o documento del socio.',
        ),
      ];
    }
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
