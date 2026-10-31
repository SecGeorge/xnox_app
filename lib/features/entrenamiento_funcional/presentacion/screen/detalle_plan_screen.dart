import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/features/entrenamiento_funcional/presentacion/screen/ejecutar_rutina_screen.dart';

/// La semana de una rutina: cada día con sus bloques (circuitos, HIIT, EMOM,
/// AMRAP, estaciones o musculación) y el botón para entrenarlo con el
/// temporizador. La usan el socio y, como vista previa, el entrenador.
class DetallePlanScreen extends StatelessWidget {
  final PlanRutina plan;
  final String? descripcion;

  /// Texto del botón de cada día ("Iniciar" para el socio, "Probar" para el
  /// entrenador).
  final String textoIniciar;

  const DetallePlanScreen({
    super.key,
    required this.plan,
    this.descripcion,
    this.textoIniciar = 'Iniciar',
  });

  @override
  Widget build(BuildContext context) {
    final m = plan.metodologia;
    final sesiones = plan.sesiones;
    final hoy = diasSemana[DateTime.now().weekday - 1];
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: Text(plan.nombre)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
        children: [
          _cabecera(m),
          const SizedBox(height: 18),
          if (sesiones.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('Esta rutina todavía no tiene ejercicios.')),
            ),
          for (final s in sesiones) ...[
            _tituloDia(context, s, s.dia == hoy),
            for (var i = 0; i < s.bloques.length; i++)
              _bloque(s.bloques[i], i, i < s.bloques.length - 1),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  Widget _cabecera(Metodologia m) {
    final duracion = MotorRutina.duracionEstimada(plan);
    final ejercicios = plan.bloquesValidos.fold<int>(
      0,
      (s, b) => s + b.ejerciciosValidos.length,
    );
    Widget dato(String v, String t) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            v,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            t,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 12),
          ),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [const Color(0xFF1E3A5F), Color.lerp(const Color(0xFF1E3A5F), m.color, 0.6)!],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(m.icono, color: Colors.white),
              const SizedBox(width: 8),
              Text(
                m.texto,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              ),
              if (plan.nivel != null) ...[
                const SizedBox(width: 8),
                Text(
                  '· ${nivelesRutina[plan.nivel] ?? plan.nivel}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ],
            ],
          ),
          if ((plan.objetivo ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Objetivo: ${plan.objetivo}',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          if ((descripcion ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                descripcion!,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
              ),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              dato(formatoReloj(duracion), 'día más largo'),
              dato('${plan.sesiones.length}', 'días'),
              dato('$ejercicios', 'ejercicios'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tituloDia(BuildContext context, SesionDia s, bool esHoy) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                esHoy ? '${s.etiqueta} · hoy' : s.etiqueta,
                style: TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
              Text(
                '${s.bloques.length} bloque(s) · ~${formatoDuracion(s.duracion)}',
                style: TextStyle(color: AppColores.textoSecundario, fontSize: 13),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFF1E3A5F)),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => EjecutarRutinaScreen(plan: plan, dia: s.dia),
            ),
          ),
          icon: const Icon(Icons.play_arrow_rounded),
          label: Text(textoIniciar),
        ),
      ],
    ),
  );

  String _reglas(PlanBloque b) {
    final m = b.metodologia;
    return switch (m.forma) {
      FormaMetodologia.circuito =>
        '${b.rondas} ${m.etiquetaRondas.toLowerCase()}'
            '${(b.descansoRondaSeg ?? 0) > 0 ? ' · ${b.descansoRondaSeg} s entre rondas' : ''}',
      FormaMetodologia.emom =>
        'cada ${b.intervaloSeg ?? MotorRutina.intervaloEmomDefecto} s'
            '${(b.tiempoLimiteSeg ?? 0) > 0 ? ' · ${formatoDuracion(b.tiempoLimiteSeg!)}' : ''}',
      FormaMetodologia.amrap =>
        '${formatoDuracion(b.tiempoLimiteSeg ?? 0)} · todas las rondas que puedas',
      _ => '',
    };
  }

  String _medida(PlanBloque b, PlanEjercicio e) {
    final m = b.metodologia;
    final partes = <String>[
      if (m.esSeries && e.series > 0) '${e.series} series',
      if (e.repeticiones > 0) '${e.repeticiones} reps',
      if ((e.trabajoSeg ?? 0) > 0) '${e.trabajoSeg} s',
      if ((e.pesoKg ?? 0) > 0) '${PlanEjercicio.formatoKg(e.pesoKg!)} kg',
      if (m.usa(CampoMetodologia.descanso) && (e.descansoSeg ?? 0) > 0)
        'desc. ${e.descansoSeg} s',
      if (Tempo.ritmo(e.tempoBajadaSeg, e.tempoSubidaSeg, e.velocidad).isNotEmpty)
        Tempo.ritmo(e.tempoBajadaSeg, e.tempoSubidaSeg, e.velocidad),
    ];
    return partes.join(' · ');
  }

  Widget _bloque(PlanBloque b, int i, bool conDescanso) {
    final m = b.metodologia;
    final reglas = _reglas(b);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: AppColores.superficie,
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: m.color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(m.icono, color: m.color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    MotorRutina.nombreBloque(b, i),
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ),
                Text(
                  '~${formatoDuracion(MotorRutina.duracionBloque(b))}',
                  style: TextStyle(color: AppColores.textoSecundario, fontSize: 12),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                [m.texto, if (reglas.isNotEmpty) reglas].join(' · '),
                style: TextStyle(color: m.color, fontSize: 12.5, fontWeight: FontWeight.w600),
              ),
            ),
            for (final e in b.ejerciciosValidos)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        width: 38,
                        height: 38,
                        color: AppColores.fondo,
                        child: (e.imagenUrl ?? '').isEmpty
                            ? Icon(m.icono, size: 18, color: AppColores.textoSecundario)
                            : Image.network(
                                e.imagenUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    Icon(m.icono, size: 18, color: AppColores.textoSecundario),
                              ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            e.nombre,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: AppColores.textoPrincipal,
                            ),
                          ),
                          if (_medida(b, e).isNotEmpty)
                            Text(
                              _medida(b, e),
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColores.textoSecundario,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            if (conDescanso && (b.descansoBloqueSeg ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Descanso de ${b.descansoBloqueSeg} s antes del siguiente bloque',
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
