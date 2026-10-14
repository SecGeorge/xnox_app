import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/buscar_alimento_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Mi diario: lo que comí cada día, por desayuno, almuerzo, cena y
/// aperitivos. Tocar un alimento cambia la cantidad; deslizarlo lo quita.
class DiarioNutricionScreen extends StatefulWidget {
  final ControladorNutricion controlador;

  const DiarioNutricionScreen({super.key, required this.controlador});

  @override
  State<DiarioNutricionScreen> createState() => _DiarioNutricionScreenState();
}

class _DiarioNutricionScreenState extends State<DiarioNutricionScreen> {
  DateTime _dia = DateTime.now();

  ControladorNutricion get _c => widget.controlador;

  void _avisar(String? error, String ok) {
    if (!mounted) return;
    mostrarMensaje(
      context,
      error ?? ok,
      tipo: error == null ? TipoMensaje.exito : TipoMensaje.error,
    );
  }

  Future<void> _agregar(String tiempo) async {
    final e = await Navigator.of(context).push<EleccionAlimento>(
      MaterialPageRoute(builder: (_) => BuscarAlimentoScreen(tiempo: tiempo)),
    );
    if (e == null) return;
    _avisar(
      await _c.agregar(
        _dia,
        EleccionAlimentoDatos(e.alimento.id, e.tiempo, e.gramos),
      ),
      'Agregado: ${e.alimento.nombre}',
    );
  }

  Future<void> _editar(Consumo c) async {
    final e = await elegirCantidad(
      context,
      c.alimento,
      tiempo: c.tiempo,
      gramos: c.cantidadG,
      textoBoton: 'Guardar cambios',
    );
    if (e == null) return;
    _avisar(await _c.editar(c, e.tiempo, e.gramos), 'Cambios guardados');
  }

  Future<void> _eliminar(Consumo c) async {
    final ok = await confirmarDialog(
      context,
      titulo: 'Quitar alimento',
      mensaje: '¿Quitar "${c.alimento.nombre}" de este día?',
      icono: Icons.delete_outline_rounded,
      textoConfirmar: 'Quitar',
      peligro: true,
    );
    if (!ok) return;
    _avisar(await _c.eliminar(c), 'Quitado');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final r = _c.resumen;
        final consumos = r?.consumosDe(isoFecha(_dia)) ?? const <Consumo>[];
        return PantallaApp(
          onRefresh: _c.cargar,
          espacioAbajo: AppEspaciado.lg,
          children: [
            const CabeceraApp(
              titulo: 'Mi diario',
              subtitulo: 'Lo que comiste cada día',
            ),
            const SizedBox(height: AppEspaciado.md),
            if (r != null) ...[
              CalendarioNutricion(
                resumen: r,
                seleccionado: _dia,
                desde: ControladorNutricion.desde,
                onElegir: (d) => setState(() => _dia = d),
              ),
              const SizedBox(height: AppEspaciado.md),
              PortadaDia(resumen: r, dia: _dia),
              const SizedBox(height: AppEspaciado.md),
              ComidasDelDia(
                consumos: consumos,
                onAgregar: _agregar,
                onEditar: _editar,
                onEliminar: _eliminar,
              ),
              const Text(
                'Toca un alimento para cambiar la cantidad o deslízalo a la '
                'izquierda para quitarlo.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
