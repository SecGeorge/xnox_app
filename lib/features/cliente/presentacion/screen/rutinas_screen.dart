import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/rutina.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_rutinas.dart';
import 'package:xnox_app/features/cliente/presentacion/screen/detalle_rutina_screen.dart';

/// Lista de rutinas del cliente.
///
/// Separa las rutinas SUGERIDAS por el administrador (solo lectura, vienen del
/// backend y se sincronizan a SQLite) de las rutinas propias del cliente (CRUD
/// local). Al abrir: carga SQLite y sincroniza con el backend si hay conexión.
class RutinasScreen extends StatefulWidget {
  const RutinasScreen({super.key});

  @override
  State<RutinasScreen> createState() => _RutinasScreenState();
}

class _RutinasScreenState extends State<RutinasScreen> {
  final _controlador = ControladorRutinas();
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    await _controlador.sincronizar();
    if (!mounted) return;
    setState(() => _cargando = false);
  }

  @override
  Widget build(BuildContext context) {
    final sugeridas = _controlador.obtenerSugeridas();
    final mias = _controlador.obtenerMisRutinas();
    final vacio = sugeridas.isEmpty && mias.isEmpty;

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
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _cargar,
                child: vacio
                    ? ListView(
                        children: const [
                          SizedBox(height: 120),
                          EstadoVacio(
                            icono: Icons.fitness_center_outlined,
                            mensaje:
                                'Aún no tienes rutinas.\nCrea la primera con el botón +',
                          ),
                        ],
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                            AppEspaciado.md, AppEspaciado.md, 90),
                        children: [
                          if (sugeridas.isNotEmpty) ...[
                            _tituloSeccion('Rutinas sugeridas', Icons.verified),
                            const SizedBox(height: AppEspaciado.sm),
                            ...sugeridas.map(_buildTarjeta),
                            const SizedBox(height: AppEspaciado.lg),
                          ],
                          _tituloSeccion('Mis rutinas', Icons.person),
                          const SizedBox(height: AppEspaciado.sm),
                          if (mias.isEmpty)
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 24),
                              child: Text(
                                'Crea tu propia rutina con el botón +',
                                style: TextStyle(
                                    color: AppColores.textoSecundario),
                              ),
                            )
                          else
                            ...mias.map(_buildTarjeta),
                        ],
                      ),
              ),
      ),
    );
  }

  Widget _tituloSeccion(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 20, color: AppColores.primario),
        const SizedBox(width: 8),
        Text(
          texto,
          style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColores.textoPrincipal),
        ),
      ],
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
                  Row(
                    children: [
                      Flexible(
                        child: Text(r.nombre,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColores.textoPrincipal)),
                      ),
                      if (r.esSugerida) ...[
                        const SizedBox(width: 8),
                        const EtiquetaEstado(
                            texto: 'Sugerida', color: AppColores.azul),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(r.resumenDias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13, color: AppColores.textoSecundario)),
                  const SizedBox(height: 4),
                  Text('${r.totalDias} día(s) · ${r.totalEjercicios} ejercicios',
                      style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: AppColores.acento)),
                ],
              ),
            ),
            if (!r.esSugerida)
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColores.textoSecundario),
                tooltip: 'Eliminar',
                onPressed: () => _eliminarRutina(r),
              )
            else
              const Icon(Icons.chevron_right,
                  color: AppColores.textoSecundario),
          ],
        ),
      ),
    );
  }

  Future<void> _eliminarRutina(Rutina r) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar "${r.nombre}" y todos sus ejercicios?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColores.moroso),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true) return;
    await _controlador.eliminarRutina(r.id);
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _nuevaRutina() async {
    final nombreCtrl = TextEditingController();
    final descCtrl = TextEditingController();

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
                  labelText: 'Nombre (ej. Pecho y Tríceps)'),
            ),
            const SizedBox(height: AppEspaciado.md),
            TextField(
              controller: descCtrl,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Descripción (opcional)'),
            ),
            const SizedBox(height: AppEspaciado.lg),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (nombreCtrl.text.trim().isEmpty) return;
                  Navigator.of(ctx).pop(true);
                },
                child: const Text('Crear y agregar días'),
              ),
            ),
          ],
        ),
      ),
    );

    if (creada != true) return;
    final id = await _controlador.crearRutina(
      nombreCtrl.text.trim(),
      descCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() {});
    // Abrir el detalle para que agregue días y ejercicios.
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DetalleRutinaScreen(rutinaId: id)),
    );
    if (!mounted) return;
    setState(() {});
  }
}
