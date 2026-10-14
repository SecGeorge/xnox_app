import 'package:flutter/material.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/composicion_corporal.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/composicion_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/medidas_screen.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/nutricion_socio_admin_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/rutinas_admin/presentacion/screen/rutinas_miembro_screen.dart';
import 'package:xnox_app/features/seguimiento/datos/repositorio_seguimiento.dart';
import 'package:xnox_app/features/seguimiento/dominio/seguimiento.dart';
import 'package:xnox_app/features/seguimiento/presentacion/screen/ejercicio_socio_screen.dart';
import 'package:xnox_app/features/seguimiento/presentacion/screen/entrenamiento_socio_screen.dart';
import 'package:xnox_app/features/seguimiento/presentacion/widget/piezas_seguimiento.dart';

/// Ficha de un socio para el personal: en orden, su resumen, sus mejoras y
/// un acceso por tema (entrenamiento, medidas, IMC, comidas y rutinas).
class FichaSocioScreen extends StatefulWidget {
  final int miembroId;
  final String nombre;

  const FichaSocioScreen({
    super.key,
    required this.miembroId,
    required this.nombre,
  });

  @override
  State<FichaSocioScreen> createState() => _FichaSocioScreenState();
}

class _FichaSocioScreenState extends State<FichaSocioScreen> {
  final _repo = RepositorioSeguimiento();
  final _repoNutricion = RepositorioNutricion();

  SeguimientoSocio? _socio;

  /// Altura, sexo y comidas. Null si el gimnasio no tiene Nutrición o falló.
  ResumenNutricion? _nutricion;
  String? _error;
  bool _cargando = true;
  Permisos? _permisos;

  @override
  void initState() {
    super.initState();
    Permisos.cargar().then((p) {
      if (mounted) setState(() => _permisos = p);
    });
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _socio == null;
      _error = null;
    });
    final hoy = DateTime.now();
    final nutricion = _repoNutricion
        .resumen(
          miembroId: widget.miembroId,
          desde: DateTime(hoy.year, hoy.month, hoy.day - 6),
          hasta: hoy,
        )
        .then<ResumenNutricion?>((r) => r)
        .catchError((_) => null);
    try {
      final socio = await _repo.detalle(widget.miembroId);
      final n = await nutricion;
      if (!mounted) return;
      setState(() {
        _socio = socio;
        _nutricion = n;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e'.replaceFirst('Exception: ', '');
        _cargando = false;
      });
    }
  }

  bool _puede(String permiso) => _permisos?.tiene(permiso) ?? false;

  String get _nombre {
    final n = _socio?.nombre ?? '';
    return n.isEmpty ? widget.nombre : n;
  }

  ComposicionCorporal? get _composicion {
    final s = _socio;
    final p = _nutricion?.perfil;
    return ComposicionCorporal.calcular(
      pesoKg: s?.pesoActual ?? p?.peso,
      alturaCm: p?.alturaCm,
      edad: p?.edad ?? s?.edad,
      sexo: p?.sexo,
    );
  }

  Future<void> _ir(Widget pantalla, {bool recargar = false}) async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => pantalla));
    if (recargar) await _cargar();
  }

  Future<void> _editarDatos() async {
    final perfil = _nutricion?.perfil;
    if (perfil == null) return;
    final ok = await editarPerfilNutricion(
      context,
      perfil: perfil,
      miembroId: widget.miembroId,
    );
    if (ok) await _cargar();
  }

  void _abrirImc() {
    final c = _composicion;
    final s = _socio!;
    final gestiona = _puede(PermisosMovil.nutricionGestion);
    if (c == null) {
      final perfil = _nutricion?.perfil;
      if (perfil == null) {
        mostrarMensaje(
          context,
          'No se pudo leer la altura del socio',
          tipo: TipoMensaje.advertencia,
        );
      } else if (perfil.alturaCm == null && gestiona) {
        _editarDatos();
      } else {
        mostrarMensaje(
          context,
          perfil.alturaCm == null
              ? 'Falta la altura del socio (Nutrición → Datos del socio)'
              : 'El socio aún no registra su peso en Mis medidas',
          tipo: TipoMensaje.advertencia,
        );
      }
      return;
    }
    _ir(
      ComposicionScreen(
        composicion: c,
        propio: false,
        nombre: _nombre,
        pesos: [
          for (final m in s.medidasDe('peso')) PuntoEvolucion(m.fecha, m.valor),
        ],
        onCompletarDatos: gestiona
            ? () {
                Navigator.of(context).pop();
                _editarDatos();
              }
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = _socio;
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: AppEspaciado.lg,
      children: [
        CabeceraApp(
          titulo: _nombre,
          subtitulo: s == null
              ? 'Ficha del socio'
              : [
                  if ((s.codigo ?? '').isNotEmpty) 'Código ${s.codigo}',
                  if ((_nutricion?.perfil.edad ?? s.edad) != null)
                    '${_nutricion?.perfil.edad ?? s.edad} años',
                ].join(' · '),
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (s == null)
          VacioApp(
            icono: Icons.cloud_off_rounded,
            titulo: _error ?? 'No se pudo cargar el socio',
            texto: 'Desliza hacia abajo para reintentar.',
          )
        else
          ..._contenido(s),
      ],
    );
  }

  List<Widget> _contenido(SeguimientoSocio s) {
    final c = _composicion;
    final semana = s.diasUltimaSemana;
    return [
      // 1. Resumen.
      PortadaNutricion(
        foto: FotosApp.progreso,
        alineacion: const Alignment(0.4, -0.2),
        icono: Icons.insights_rounded,
        chip: 'Resumen',
        alto: 170,
        titulo: s.sesiones.isEmpty
            ? 'Aún no registra entrenamientos'
            : 'Esta semana entrenó $semana de 7 días',
        detalle: s.sesiones.isEmpty
            ? null
            : 'Último entrenamiento: '
                  '${haceCuanto(s.sesiones.first.fecha).toLowerCase()}',
        hechos: semana,
        total: 7,
        pie: [
          DatoPie(
            icono: Icons.monitor_weight_rounded,
            valor: c != null
                ? '${numeroMedida(c.pesoKg)} kg'
                : s.pesoActual == null
                ? '—'
                : '${numeroMedida(s.pesoActual!)} kg',
            pie: 'peso',
          ),
          if (c != null)
            DatoPie(
              icono: Icons.speed_rounded,
              valor: numeroMedida(c.imc),
              pie: c.nivel.nombre,
            ),
          DatoPie(
            icono: Icons.calendar_month_rounded,
            valor: '${s.diasEntrenados}',
            pie: 'días entrenados',
          ),
        ],
      ),
      const SizedBox(height: AppEspaciado.lg),

      // 2. Accesos por tema.
      const TituloSeccion(
        icono: Icons.grid_view_rounded,
        titulo: 'Todo sobre el socio',
      ),
      ..._accesos(s, c),
      const SizedBox(height: AppEspaciado.lg),

      // 3. Mejoras.
      TituloSeccion(
        icono: Icons.emoji_events_rounded,
        titulo: 'Sus mejoras',
        detalle: 'desde que empezó',
      ),
      _mejoras(s),
      const SizedBox(height: AppEspaciado.lg),

      // 4. Lo último que hizo.
      TituloSeccion(
        icono: Icons.history_rounded,
        titulo: 'Últimos ejercicios',
        accion: s.sesiones.isEmpty ? null : 'Ver todo',
        onAccion: () =>
            _ir(EntrenamientoSocioScreen(socio: s, pestanaInicial: 1)),
      ),
      if (s.sesiones.isEmpty)
        const VacioApp(
          icono: Icons.fitness_center_rounded,
          titulo: 'Sin entrenamientos',
          texto: 'Cuando registre sus series en la app, aparecerán aquí.',
        )
      else
        GrupoFilas(
          filas: [
            for (final x in s.sesiones.take(5))
              FilaApp(
                onTap: () => _abrirEjercicio(s, x.ejercicio),
                inicio: FotoEjercicio(x.ejercicio, tamano: 42),
                titulo: x.ejercicio,
                subtitulo: '${haceCuanto(x.fecha)} · ${x.seriesTexto}',
                fin: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColores.textoSecundario,
                ),
              ),
          ],
        ),
    ];
  }

  void _abrirEjercicio(SeguimientoSocio s, String nombre) {
    final e = s.ejercicios.firstWhere(
      (x) => x.nombre.toLowerCase() == nombre.toLowerCase(),
    );
    _ir(EjercicioSocioScreen(ejercicio: e, nombreSocio: _nombre));
  }

  List<Widget> _accesos(SeguimientoSocio s, ComposicionCorporal? c) {
    final perfil = _nutricion?.perfil;
    final hoy = _nutricion?.dia(isoFecha(DateTime.now()));
    final ejercicios = s.ejercicios.length;
    final tarjetas = <Widget>[
      AccesoFoto(
        foto: FotosApp.rutinas,
        icono: Icons.fitness_center_rounded,
        titulo: 'Entrenamiento',
        detalle: ejercicios == 0
            ? 'Sin ejercicios aún'
            : '$ejercicios ejercicios · ${s.totalSeries} series',
        onTap: () => _ir(EntrenamientoSocioScreen(socio: s)),
      ),
      AccesoFoto(
        foto: FotosApp.brazos,
        icono: Icons.straighten_rounded,
        titulo: 'Medidas',
        detalle: '${s.zonasMedidas} de ${ZonaMedida.todas.length} zonas',
        onTap: () => _ir(MedidasScreen(medidas: s.medidas, nombre: _nombre)),
      ),
      AccesoFoto(
        foto: ComposicionScreen.fotoCuerpo,
        icono: Icons.monitor_weight_rounded,
        titulo: 'IMC y peso ideal',
        detalle: c != null
            ? 'IMC ${numeroMedida(c.imc)} · ${c.nivel.nombre}'
            : perfil?.alturaCm == null
            ? 'Falta la altura'
            : 'Falta el peso',
        onTap: _abrirImc,
      ),
      if (_puede(PermisosMovil.nutricion))
        AccesoFoto(
          foto: FotosNutricion.plato,
          icono: Icons.restaurant_rounded,
          titulo: 'Comidas',
          detalle: hoy == null || hoy.registros == 0
              ? 'Hoy no registró comidas'
              : 'Hoy: ${hoy.totales['kcal']!.round()} kcal',
          onTap: () => _ir(
            NutricionSocioAdminScreen(
              miembroId: widget.miembroId,
              nombre: _nombre,
            ),
            recargar: true,
          ),
        ),
      if (_puede(PermisosMovil.rutinas))
        AccesoFoto(
          foto: FotosApp.pecho,
          icono: Icons.event_note_rounded,
          titulo: 'Rutinas',
          detalle: 'Ver y asignar su rutina',
          onTap: () => _ir(
            RutinasMiembroScreen(
              miembroId: widget.miembroId,
              nombreMiembro: _nombre,
            ),
          ),
        ),
    ];
    // De dos en dos; la última sola ocupa todo el ancho.
    return [
      for (var i = 0; i < tarjetas.length; i += 2)
        Padding(
          padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
          child: i + 1 < tarjetas.length
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: tarjetas[i]),
                    const SizedBox(width: AppEspaciado.sm + 4),
                    Expanded(child: tarjetas[i + 1]),
                  ],
                )
              : tarjetas[i],
        ),
    ];
  }

  Widget _mejoras(SeguimientoSocio s) {
    final fuerza = s.ejercicios.where((e) => e.mejora > 0).take(3).toList();
    final medidas = s.cambiosMedidas
      ..sort((a, b) {
        // Primero lo que mejoró, luego lo que empeoró, al final lo neutro.
        int orden(CambioMedida x) => switch (x.bueno) {
          true => 0,
          false => 1,
          null => 2,
        };
        return orden(a).compareTo(orden(b));
      });
    if (fuerza.isEmpty && medidas.isEmpty) {
      return const VacioApp(
        icono: Icons.emoji_events_outlined,
        titulo: 'Aún no hay con qué comparar',
        texto:
            'Las mejoras aparecen cuando repite un ejercicio con más peso o '
            'vuelve a medirse.',
      );
    }
    return GrupoFilas(
      filas: [
        for (final e in fuerza)
          FilaApp(
            onTap: () =>
                _ir(EjercicioSocioScreen(ejercicio: e, nombreSocio: _nombre)),
            inicio: FotoEjercicio(e.nombre, tamano: 42),
            titulo: e.nombre,
            subtitulo:
                'Fuerza: ${numeroMedida(e.primera.mejorPeso)} → '
                '${numeroMedida(e.mejorPeso)} kg',
            fin: ChipCambio(
              texto: '+${numeroMedida(e.mejora)} kg',
              bueno: true,
              sube: true,
            ),
          ),
        for (final m in medidas.take(4))
          FilaApp(
            inicio: IconoSuave(m.zona.icono),
            titulo: m.zona.nombre,
            subtitulo:
                '${numeroMedida(m.inicio)} → ${numeroMedida(m.actual)} '
                '${m.zona.unidad}',
            fin: ChipCambio(
              texto:
                  '${m.cambio > 0 ? '+' : ''}${numeroMedida(m.cambio)} '
                  '${m.zona.unidad}',
              bueno: m.bueno,
              sube: m.cambio > 0,
            ),
          ),
      ],
    );
  }
}
