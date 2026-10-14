import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/nutricion_socio_admin_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Sección "Nutrición" del personal: se busca un socio y se ve lo que come,
/// su plan y sus metas. Reutiliza la búsqueda de miembros, como Rutinas.
class NutricionAdminScreen extends StatefulWidget {
  const NutricionAdminScreen({super.key});

  @override
  State<NutricionAdminScreen> createState() => _NutricionAdminScreenState();
}

class _NutricionAdminScreenState extends State<NutricionAdminScreen> {
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
        _miembros = lista;
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
    // Sin búsqueda no se lista a todos: la lista puede ser enorme.
    final q = _busqueda.trim();
    if (q.isEmpty) return const [];
    final ql = q.toLowerCase();
    return _miembros
        .where(
          (m) => m.nombre.toLowerCase().contains(ql) || m.documento.contains(q),
        )
        .toList();
  }

  Future<void> _abrir(Miembro m) async {
    if (m.id == null) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            NutricionSocioAdminScreen(miembroId: m.id!, nombre: m.nombre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: _cargar,
      children: [
        const CabeceraApp(
          titulo: 'Nutrición',
          subtitulo: 'Lo que comen tus socios, su plan y sus metas',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        const PortadaNutricion(
          foto: FotosNutricion.mesa,
          icono: Icons.restaurant_rounded,
          chip: 'Alimentación',
          alto: 150,
          titulo: 'Planes de comida',
          detalle: 'Busca a un socio para ver lo que come y asignarle su plan.',
        ),
        const SizedBox(height: AppEspaciado.md),
        BuscadorApp(
          hint: 'Buscar socio por nombre o documento',
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
          titulo: '¿A quién revisas?',
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
          texto: 'No hay socios que coincidan con la búsqueda.',
        ),
      ];
    }
    return [
      GrupoFilas(
        filas: [
          for (final m in filtrados.take(40))
            FilaApp(
              inicio: CircleAvatar(
                backgroundColor: AppColores.primario.withValues(alpha: 0.1),
                child: Text(
                  Miembro.inicialesDe(m.nombre),
                  style: TextStyle(
                    color: AppColores.primario,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              titulo: m.nombre,
              subtitulo: '${m.documento} · ${m.plan}',
              fin: const Icon(
                Icons.chevron_right_rounded,
                color: AppColores.textoSecundario,
              ),
              onTap: () => _abrir(m),
            ),
        ],
      ),
    ];
  }
}
