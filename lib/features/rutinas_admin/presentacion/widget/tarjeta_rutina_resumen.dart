import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

/// Tarjeta de una rutina en las listas del personal (rutinas generales y las
/// de un socio). [onAccion] recibe 'editar', 'duplicar', 'estado' o
/// 'eliminar'.
class TarjetaRutinaResumen extends StatelessWidget {
  final RutinaResumen r;
  final String foto;
  final bool puedeGestionar;
  final ValueChanged<String> onAccion;

  const TarjetaRutinaResumen({
    super.key,
    required this.r,
    required this.foto,
    required this.puedeGestionar,
    required this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
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
          onTap: puedeGestionar ? () => onAccion('editar') : null,
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
                        Row(
                          children: [
                            Icon(r.metodologia.icono, size: 14, color: r.metodologia.color),
                            const SizedBox(width: 4),
                            Text(
                              '${r.metodologia.texto}'
                              '${r.duracionSeg != null ? ' · ~${formatoDuracion(r.duracionSeg!)}' : ''}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: r.metodologia.color,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
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
                if (puedeGestionar)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert_rounded,
                      color: AppColores.textoSecundario,
                    ),
                    onSelected: onAccion,
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'editar',
                        child: Text('Editar'),
                      ),
                      const PopupMenuItem(
                        value: 'duplicar',
                        child: Text('Duplicar'),
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
