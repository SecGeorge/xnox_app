import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';
import 'package:xnox_app/features/seguimiento/presentacion/screen/ficha_socio_screen.dart';

/// Sección "Seguimiento" del personal: se busca un socio y se abre su ficha
/// con todo su progreso (entrenamiento, medidas, IMC y comidas). Mismo
/// buscador que Rutinas y Nutrición.
class SeguimientoAdminScreen extends StatefulWidget {
  const SeguimientoAdminScreen({super.key});

  @override
  State<SeguimientoAdminScreen> createState() => _SeguimientoAdminScreenState();
}

class _SeguimientoAdminScreenState extends State<SeguimientoAdminScreen> {
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
        // Todos, no solo activos: un socio vencido sigue teniendo historial.
        _miembros = lista.where((m) => m.id != null).toList();
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los socios';
        _cargando = false;
      });
    }
  }

  List<Miembro> get _filtrados {
    final q = _busqueda.trim();
    if (q.isEmpty) return const [];
    final ql = q.toLowerCase();
    return _miembros
        .where(
          (m) => m.nombre.toLowerCase().contains(ql) || m.documento.contains(q),
        )
        .toList();
  }

  void _abrir(Miembro m) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FichaSocioScreen(miembroId: m.id!, nombre: m.nombre),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activos = _miembros
        .where((m) => m.estado == EstadoMiembro.activo)
        .length;
    return PantallaApp(
      onRefresh: _cargar,
      children: [
        const CabeceraApp(
          titulo: 'Seguimiento',
          subtitulo: 'Todo el progreso de cada socio',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.progreso,
          alineacion: const Alignment(0.4, -0.2),
          etiqueta: 'Progreso de socios',
          titulo: _cargando ? '…' : '$activos socios activos',
          texto:
              'Busca a un socio para ver sus ejercicios, series, medidas, '
              'IMC y comidas.',
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
          titulo: '¿A quién quieres revisar?',
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
      TituloSeccion(
        icono: Icons.people_alt_rounded,
        titulo: 'Resultados',
        detalle: '${filtrados.length}',
      ),
      GrupoFilas(
        filas: [
          for (final m in filtrados)
            FilaApp(
              onTap: () => _abrir(m),
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
              subtitulo: [
                m.etiquetaEstado,
                if (m.documento.isNotEmpty) 'Doc: ${m.documento}',
              ].join(' · '),
              fin: const IconoSuave(
                Icons.insights_rounded,
                tamano: 36,
                circular: true,
              ),
            ),
        ],
      ),
    ];
  }
}
