import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/foto_sesion.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/seguimiento/dominio/seguimiento.dart';
import 'package:xnox_app/features/seguimiento/presentacion/widget/piezas_seguimiento.dart';

/// Un ejercicio del socio: su mejor marca, la curva de la carga y cada día
/// que lo hizo con todas sus series.
class EjercicioSocioScreen extends StatelessWidget {
  final EjercicioSocio ejercicio;
  final String nombreSocio;

  const EjercicioSocioScreen({
    super.key,
    required this.ejercicio,
    required this.nombreSocio,
  });

  @override
  Widget build(BuildContext context) {
    final e = ejercicio;
    final foto = FotoSesion.deEjercicio(e.nombre);
    final desde = DateFormat("d 'de' MMMM", 'es').format(e.primera.fecha);
    return PantallaApp(
      espacioAbajo: AppEspaciado.lg,
      children: [
        CabeceraApp(titulo: e.nombre, subtitulo: nombreSocio),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaNutricion(
          foto: foto.ruta,
          alineacion: foto.alineacion,
          icono: Icons.emoji_events_rounded,
          chip: FotoSesion.grupoDeEjercicio(e.nombre) ?? 'Ejercicio',
          alto: 170,
          titulo: 'Mejor marca: ${numeroMedida(e.mejorPeso)} kg',
          detalle: e.mejora > 0
              ? 'Subió ${numeroMedida(e.mejora)} kg desde el $desde'
              : 'Lo hace desde el $desde',
          pie: [
            DatoPie(
              icono: Icons.event_repeat_rounded,
              valor: '${e.sesiones.length}',
              pie: e.sesiones.length == 1 ? 'vez' : 'veces',
            ),
            DatoPie(
              icono: Icons.repeat_rounded,
              valor: '${e.totalSeries}',
              pie: e.totalSeries == 1 ? 'serie' : 'series',
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.show_chart_rounded,
          titulo: 'Evolución de la carga',
        ),
        GraficoEvolucion(
          puntos: [
            for (final s in e.sesiones)
              PuntoEvolucion(
                s.fecha,
                s.mejorPeso,
                detalle:
                    '${s.series.isEmpty ? 1 : s.series.length} series · '
                    '${s.totalReps} reps',
              ),
          ],
          unidad: 'kg',
          mejorSiSube: true,
          textoVacio: 'Sin registros',
          textoUnPunto: 'Con otra sesión se verá la curva',
        ),
        const SizedBox(height: AppEspaciado.sm + 2),
        Row(
          children: [
            DatoCentrado('Inicio', '${numeroMedida(e.primera.mejorPeso)} kg'),
            DatoCentrado(
              'Mejor marca',
              '${numeroMedida(e.mejorPeso)} kg',
              destacar: true,
            ),
            DatoCentrado('Última', '${numeroMedida(e.ultima.mejorPeso)} kg'),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.history_rounded,
          titulo: 'Historial de series',
          detalle: '${e.sesiones.length}',
        ),
        for (final s in e.sesiones.reversed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
            child: _TarjetaSesion(sesion: s, mejor: e.mejorPeso),
          ),
      ],
    );
  }
}

/// Un día del ejercicio: fecha, rutina y una fila por serie.
class _TarjetaSesion extends StatelessWidget {
  final SesionSocio sesion;
  final double mejor;

  const _TarjetaSesion({required this.sesion, required this.mejor});

  @override
  Widget build(BuildContext context) {
    final s = sesion;
    final esRecord = s.mejorPeso == mejor && mejor > 0;
    return TarjetaPlana(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconoSuave(Icons.calendar_today_rounded, tamano: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fechaLarga(s.fecha),
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    if (s.rutinaNombre != null)
                      Text(
                        s.rutinaNombre!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                  ],
                ),
              ),
              if (esRecord)
                const ChipCambio(texto: 'Récord', bueno: true, sube: true),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          if (s.series.isEmpty)
            _filaSerie(1, '${s.repeticiones}', s.peso)
          else
            for (final x in s.series)
              _filaSerie(x.numero, x.repsTexto, s.pesoDe(x)),
        ],
      ),
    );
  }

  Widget _filaSerie(int numero, String reps, double peso) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
      ),
      child: Row(
        children: [
          // Número de serie en un círculo (como en la sesión del socio).
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Text(
              '$numero',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColores.primario,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$reps reps',
              textAlign: TextAlign.right,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Text(
            '${numeroMedida(peso)} kg',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: AppColores.primario,
            ),
          ),
        ],
      ),
    );
  }
}
