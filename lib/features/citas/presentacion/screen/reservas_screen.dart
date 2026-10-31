import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';
import 'package:xnox_app/features/citas/datos/repositorio_citas.dart';
import 'package:xnox_app/features/citas/dominio/cita.dart';
import 'package:xnox_app/features/citas/presentacion/screen/citas_screen.dart';
import 'package:xnox_app/features/clases/datos/repositorio_clases.dart';
import 'package:xnox_app/features/clases/dominio/sesion_clase.dart';
import 'package:xnox_app/features/clases/presentacion/screen/clases_screen.dart';

/// Todo lo que el socio reserva, en una sola entrada del menú: clases
/// grupales y citas (masajes, nutricionista…) agrupadas por categoría, con
/// sus próximas reservas arriba. Solo aparecen las categorías que el
/// gimnasio ofrece.
class ReservasScreen extends StatefulWidget {
  const ReservasScreen({super.key});

  @override
  State<ReservasScreen> createState() => _ReservasScreenState();
}

class _ReservasScreenState extends State<ReservasScreen> {
  final _clases = RepositorioClases();
  final _citas = RepositorioCitas();

  List<SesionClase> _sesiones = const [];
  CatalogoCitas _catalogo = CatalogoCitas.vacio;
  bool _cargando = true;
  bool _sinConexion = false;

  static const _fotos = 'assets/imagenes';

  /// Ícono legible sobre el color destacado de la marca (claro u oscuro).
  Color get _tinta => AppColores.destacado.computeLuminance() > 0.45
      ? const Color(0xFF0E1A12)
      : Colors.white;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  /// Cada parte se carga por separado: si un gimnasio no tiene Citas (o
  /// Clases) la otra igual se muestra.
  Future<void> _cargar() async {
    var fallos = 0;
    final resultados = await Future.wait<Object?>([
      _clases.agenda().catchError((_) {
        fallos++;
        return <SesionClase>[];
      }),
      _citas.catalogo().catchError((_) {
        fallos++;
        return CatalogoCitas.vacio;
      }),
    ]);
    if (!mounted) return;
    setState(() {
      _sesiones = resultados[0] as List<SesionClase>;
      _catalogo = resultados[1] as CatalogoCitas;
      _sinConexion = fallos == 2;
      _cargando = false;
    });
  }

  Future<void> _abrir(Widget pantalla) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pantalla));
    if (mounted) _cargar();
  }

  static String _capital(String t) =>
      t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);

  String _cuando(DateTime inicio) {
    final hoy = DateTime.now();
    final dia = DateTime(inicio.year, inicio.month, inicio.day);
    final dif = dia.difference(DateTime(hoy.year, hoy.month, hoy.day)).inDays;
    final nombre = dif == 0
        ? 'Hoy'
        : dif == 1
        ? 'Mañana'
        : _capital(DateFormat('EEE d MMM', 'es').format(dia));
    return '$nombre · ${DateFormat('HH:mm').format(inicio)}';
  }

  /// Próximas clases reservadas y citas pendientes, en orden.
  List<_Proxima> get _proximas {
    final lista = <_Proxima>[
      for (final s in _sesiones.where((s) => s.reservaEstado == 1 && !s.pasada))
        _Proxima(
          s.inicio,
          s.nombre,
          s.entrenador,
          s.color,
          Icons.groups_rounded,
          () => _abrir(const ClasesScreen()),
        ),
      for (final c in _catalogo.proximas)
        _Proxima(
          c.inicio,
          c.tipo,
          c.profesional,
          c.color,
          c.especialidad.icono,
          () => _abrir(
            CitasScreen(especialidad: c.especialidad, repositorio: _citas),
          ),
        ),
    ]..sort((a, b) => a.inicio.compareTo(b.inicio));
    return lista;
  }

  List<_Categoria> get _categorias => [
    if (_sesiones.isNotEmpty)
      _Categoria(
        'Clases',
        'Zumba, spinning y más · reserva tu cupo',
        Icons.groups_rounded,
        '$_fotos/inicio/motivacion.jpg',
        () => _abrir(const ClasesScreen()),
      ),
    for (final e in _catalogo.especialidades)
      _Categoria(e.nombre, _detalle(e), e.icono, switch (e) {
        Especialidad.masajes => '$_fotos/sesiones/descanso.jpg',
        Especialidad.nutricion => '$_fotos/nutricion/mesa.jpg',
        Especialidad.otra => '$_fotos/inicio/progreso.jpg',
      }, () => _abrir(CitasScreen(especialidad: e, repositorio: _citas))),
  ];

  String _detalle(Especialidad e) {
    final nombres = _catalogo.tipos
        .where((t) => t.especialidad == e)
        .map((t) => t.nombre)
        .toList();
    return nombres.length <= 2
        ? nombres.join(' · ')
        : '${nombres.take(2).join(' · ')} y ${nombres.length - 2} más';
  }

  @override
  Widget build(BuildContext context) {
    final proximas = _proximas;
    final categorias = _categorias;
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: 40,
      children: [
        const CabeceraApp(
          titulo: 'Reservas',
          subtitulo: 'Clases, masajes, nutricionista y más',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_sinConexion)
          const VacioApp(
            icono: Icons.cloud_off_rounded,
            titulo: 'No se pudieron cargar las reservas',
            texto: 'Desliza hacia abajo para reintentar.',
          )
        else if (categorias.isEmpty)
          const VacioApp(
            icono: Icons.event_note_rounded,
            titulo: 'Aún no hay nada para reservar',
            texto:
                'Cuando tu gimnasio publique clases o citas, las verás aquí.',
          )
        else ...[
          if (proximas.isNotEmpty) ...[
            TituloSeccion(
              icono: Icons.bookmark_added_rounded,
              titulo: 'Tus próximas reservas',
              detalle: '${proximas.length}',
            ),
            for (final p in proximas.take(3)) ...[
              _filaProxima(p),
              const SizedBox(height: AppEspaciado.sm),
            ],
            const SizedBox(height: AppEspaciado.md),
          ],
          const TituloSeccion(
            icono: Icons.category_rounded,
            titulo: '¿Qué quieres reservar?',
          ),
          for (final c in categorias) ...[
            _tarjetaCategoria(c),
            const SizedBox(height: AppEspaciado.sm + 4),
          ],
        ],
      ],
    );
  }

  Widget _filaProxima(_Proxima p) {
    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      onTap: p.onTap,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Icon(p.icono, size: 20, color: p.color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.titulo,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  [
                    _cuando(p.inicio),
                    p.detalle,
                  ].where((t) => t.isNotEmpty).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            color: AppColores.textoSecundario,
          ),
        ],
      ),
    );
  }

  Widget _tarjetaCategoria(_Categoria c) {
    return SizedBox(
      height: 104,
      child: FotoTarjeta(
        foto: c.foto,
        radio: AppEspaciado.radio + 2,
        degradadoHorizontal: true,
        onTap: c.onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColores.destacado,
                  shape: BoxShape.circle,
                ),
                child: Icon(c.icono, size: 22, color: _tinta),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.titulo,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      c.subtitulo,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _Categoria {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  final String foto;
  final VoidCallback onTap;

  const _Categoria(
    this.titulo,
    this.subtitulo,
    this.icono,
    this.foto,
    this.onTap,
  );
}

class _Proxima {
  final DateTime inicio;
  final String titulo;
  final String detalle;
  final Color color;
  final IconData icono;
  final VoidCallback onTap;

  const _Proxima(
    this.inicio,
    this.titulo,
    this.detalle,
    this.color,
    this.icono,
    this.onTap,
  );
}
