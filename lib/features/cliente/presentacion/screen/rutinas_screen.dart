import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/detalle_rutina_screen.dart';

/// Lista de rutinas del cliente, con opción de crear una nueva.
class RutinasScreen extends StatefulWidget {
  const RutinasScreen({super.key});

  @override
  State<RutinasScreen> createState() => _RutinasScreenState();
}

class _RutinasScreenState extends State<RutinasScreen> {
  final _controlador = ControladorRutinas();

  @override
  Widget build(BuildContext context) {
    final rutinas = _controlador.obtenerRutinas();
    return Scaffold(
      backgroundColor: AppColores.fondo,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _nuevaRutina,
        backgroundColor: AppColores.primario,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva rutina',
            style: TextStyle(color: Colors.white)),
      ),
      body: SafeArea(
        child: rutinas.isEmpty
            ? const EstadoVacio(
                icono: Icons.fitness_center_outlined,
                mensaje: 'Aún no tienes rutinas.\nCrea la primera con el botón +',
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                    AppEspaciado.md, AppEspaciado.md, 90),
                children: [
                  const Text(
                    'Mis Rutinas',
                    style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColores.textoPrincipal),
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  ...rutinas.map(_buildTarjeta),
                ],
              ),
      ),
    );
  }

  Widget _buildTarjeta(Rutina r) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: TarjetaApp(
        onTap: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => DetalleRutinaScreen(rutinaId: r.id)),
          );
          setState(() {}); // refrescar conteos al volver
        },
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColores.acento.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
              ),
              child: const Icon(Icons.fitness_center,
                  color: AppColores.acento, size: 24),
            ),
            const SizedBox(width: AppEspaciado.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.nombre,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal)),
                  const SizedBox(height: 2),
                  Text(r.dia,
                      style: const TextStyle(
                          fontSize: 13, color: AppColores.textoSecundario)),
                  const SizedBox(height: 4),
                  Text('${r.totalEjercicios} ejercicios',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColores.acento)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                color: AppColores.textoSecundario),
          ],
        ),
      ),
    );
  }

  Future<void> _nuevaRutina() async {
    final nombreCtrl = TextEditingController();
    final diaCtrl = TextEditingController();

    final creada = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: AppEspaciado.lg,
          right: AppEspaciado.lg,
          top: AppEspaciado.lg,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + AppEspaciado.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Nueva rutina',
                style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal)),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: nombreCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Nombre (ej. Push, Pull, Pierna)'),
            ),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: diaCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Día / enfoque (ej. Lunes — Pecho)'),
            ),
            const SizedBox(height: AppEspaciado.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nombreCtrl.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Crear rutina'),
              ),
            ),
          ],
        ),
      ),
    );

    if (creada == true) {
      _controlador.crearRutina(
        nombreCtrl.text.trim(),
        diaCtrl.text.trim().isEmpty ? 'Sin asignar' : diaCtrl.text.trim(),
      );
      setState(() {});
    }
  }
}
