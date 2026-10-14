import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/seguimiento/dominio/seguimiento.dart';
import 'package:xnox_app/features/seguimiento/presentacion/screen/ejercicio_socio_screen.dart';
import 'package:xnox_app/features/seguimiento/presentacion/widget/piezas_seguimiento.dart';

/// Entrenamiento del socio en dos pestañas: por ejercicio (cuánto subió en
/// cada uno) y por día (qué hizo cada día, con sus series).
class EntrenamientoSocioScreen extends StatefulWidget {
  final SeguimientoSocio socio;
  final int pestanaInicial;

  const EntrenamientoSocioScreen({
    super.key,
    required this.socio,
    this.pestanaInicial = 0,
  });

  @override
  State<EntrenamientoSocioScreen> createState() =>
      _EntrenamientoSocioScreenState();
}

class _EntrenamientoSocioScreenState extends State<EntrenamientoSocioScreen> {
  late int _pestana = widget.pestanaInicial;

  /// Días que se muestran en "Por día" (se amplía con "Ver más").
  int _diasVisibles = 14;

  SeguimientoSocio get _s => widget.socio;

  void _abrir(EjercicioSocio e) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            EjercicioSocioScreen(ejercicio: e, nombreSocio: _s.nombre),
      ),
    );
  }

  void _abrirPorNombre(String nombre) {
    final e = _s.ejercicios.firstWhere(
      (x) => x.nombre.toLowerCase() == nombre.toLowerCase(),
    );
    _abrir(e);
  }

  @override
  Widget build(BuildContext context) {
    final ejercicios = _s.ejercicios;
    final semana = _s.diasUltimaSemana;
    return PantallaApp(
      espacioAbajo: AppEspaciado.lg,
      children: [
        CabeceraApp(titulo: 'Entrenamiento', subtitulo: _s.nombre),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaNutricion(
          foto: FotosApp.rutinas,
          alineacion: const Alignment(0.2, -0.2),
          icono: Icons.fitness_center_rounded,
          chip: 'Esta semana',
          alto: 170,
          titulo: semana == 0
              ? 'No entrenó esta semana'
              : 'Entrenó $semana de 7 días',
          detalle: _s.sesiones.isEmpty
              ? 'Aún no registra entrenamientos'
              : 'Último entrenamiento: ${haceCuanto(_s.sesiones.first.fecha).toLowerCase()}',
          hechos: semana,
          total: 7,
          pie: [
            DatoPie(
              icono: Icons.calendar_month_rounded,
              valor: '${_s.diasEntrenados}',
              pie: 'días en total',
            ),
            DatoPie(
              icono: Icons.fitness_center_rounded,
              valor: '${ejercicios.length}',
              pie: 'ejercicios',
            ),
            DatoPie(
              icono: Icons.repeat_rounded,
              valor: '${_s.totalSeries}',
              pie: 'series',
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.md),
        PestanasApp(
          textos: const ['Por ejercicio', 'Por día'],
          activa: _pestana,
          onCambio: (i) => setState(() => _pestana = i),
        ),
        const SizedBox(height: AppEspaciado.md),
        if (_s.sesiones.isEmpty)
          const VacioApp(
            icono: Icons.fitness_center_rounded,
            titulo: 'Sin entrenamientos',
            texto:
                'Cuando el socio registre sus series en la app, '
                'aparecerán aquí.',
          )
        else if (_pestana == 0)
          ...ejercicios.map(_tarjetaEjercicio)
        else
          ..._porDia(),
      ],
    );
  }

  Widget _tarjetaEjercicio(EjercicioSocio e) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: TarjetaPlana(
        onTap: () => _abrir(e),
        child: Column(
          children: [
            Row(
              children: [
                FotoEjercicio(e.nombre),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      Text(
                        '${e.sesiones.length} '
                        '${e.sesiones.length == 1 ? 'vez' : 'veces'} · '
                        'última: ${haceCuanto(e.ultima.fecha).toLowerCase()}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                if (e.mejora > 0)
                  ChipCambio(
                    texto: '+${numeroMedida(e.mejora)} kg',
                    bueno: true,
                    sube: true,
                  ),
              ],
            ),
            const SizedBox(height: AppEspaciado.sm + 4),
            Row(
              children: [
                DatoCentrado(
                  'Inicio',
                  '${numeroMedida(e.primera.mejorPeso)} kg',
                ),
                DatoCentrado(
                  'Mejor marca',
                  '${numeroMedida(e.mejorPeso)} kg',
                  destacar: true,
                ),
                DatoCentrado(
                  'Última',
                  '${numeroMedida(e.ultima.mejorPeso)} kg',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _porDia() {
    final formato = DateFormat('yyyy-MM-dd');
    final dias = <String, List<SesionSocio>>{};
    for (final s in _s.sesiones) {
      dias.putIfAbsent(formato.format(s.fecha), () => []).add(s);
    }
    final claves = dias.keys.toList();
    return [
      for (final k in claves.take(_diasVisibles)) ...[
        TituloSeccion(
          icono: Icons.calendar_today_rounded,
          titulo: fechaLarga(dias[k]!.first.fecha),
          detalle: '${dias[k]!.length}',
        ),
        GrupoFilas(
          filas: [
            for (final s in dias[k]!)
              FilaApp(
                onTap: () => _abrirPorNombre(s.ejercicio),
                inicio: FotoEjercicio(s.ejercicio, tamano: 42),
                titulo: s.ejercicio,
                subtitulo: s.seriesTexto,
                fin: const Icon(
                  Icons.chevron_right_rounded,
                  color: AppColores.textoSecundario,
                ),
              ),
          ],
        ),
        const SizedBox(height: AppEspaciado.md),
      ],
      if (claves.length > _diasVisibles)
        Center(
          child: TextButton.icon(
            onPressed: () => setState(() => _diasVisibles += 14),
            icon: const Icon(Icons.expand_more_rounded),
            label: Text('Ver más días (${claves.length - _diasVisibles})'),
          ),
        ),
    ];
  }
}
