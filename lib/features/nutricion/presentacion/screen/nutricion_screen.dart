import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/buscar_alimento_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/diario_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/metas_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/plan_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/progreso_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Inicio de Nutrición del socio: solo lo de hoy y cuatro accesos, cada uno a
/// su propia pantalla (diario, plan, metas, progreso) para no amontonar todo.
class NutricionScreen extends StatefulWidget {
  const NutricionScreen({super.key});

  @override
  State<NutricionScreen> createState() => _NutricionScreenState();
}

class _NutricionScreenState extends State<NutricionScreen> {
  final _c = ControladorNutricion();
  bool _avisoPerfilMostrado = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    await _c.cargar();
    final r = _c.resumen;
    // La primera vez sin altura se le pide de una: sin ella no hay metas.
    if (mounted && r != null && !r.perfil.completo && !_avisoPerfilMostrado) {
      _avisoPerfilMostrado = true;
      await _editarPerfil();
    }
  }

  Future<void> _editarPerfil() async {
    final r = _c.resumen;
    if (r == null) return;
    if (await editarPerfilNutricion(context, perfil: r.perfil)) {
      if (!mounted) return;
      mostrarMensaje(
        context,
        'Datos guardados: tus metas se actualizaron',
        tipo: TipoMensaje.exito,
      );
      await _c.cargar();
    }
  }

  /// Registrar algo de hoy sin pasar por el diario (lo más usado).
  Future<void> _registrar() async {
    final e = await Navigator.of(context).push<EleccionAlimento>(
      MaterialPageRoute(builder: (_) => const BuscarAlimentoScreen()),
    );
    if (e == null) return;
    final error = await _c.agregar(
      DateTime.now(),
      EleccionAlimentoDatos(e.alimento.id, e.tiempo, e.gramos),
    );
    if (!mounted) return;
    mostrarMensaje(
      context,
      error ?? 'Agregado: ${e.alimento.nombre}',
      tipo: error == null ? TipoMensaje.exito : TipoMensaje.error,
    );
  }

  void _abrir(Widget pantalla) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => pantalla));
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _c,
      builder: (context, _) {
        final r = _c.resumen;
        return PantallaApp(
          onRefresh: _c.cargar,
          espacioAbajo: AppEspaciado.lg,
          children: [
            CabeceraApp(
              titulo: 'Nutrición',
              subtitulo: 'Lo que comes y tus metas',
              acciones: [
                if (r != null)
                  BotonRedondo(
                    icono: Icons.accessibility_new_rounded,
                    tooltip: 'Mis datos (altura, peso, objetivo)',
                    onTap: _editarPerfil,
                  ),
              ],
            ),
            const SizedBox(height: AppEspaciado.md + 4),
            if (_c.cargando)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 80),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (r == null)
              VacioApp(
                icono: Icons.cloud_off_rounded,
                titulo: 'No se pudo cargar',
                texto:
                    '${_c.error ?? ''}\nDesliza hacia abajo para reintentar.',
              )
            else
              ..._contenido(r),
          ],
        );
      },
    );
  }

  List<Widget> _contenido(ResumenNutricion r) {
    final hoy = isoFecha(DateTime.now());
    final comidasHoy = r.consumosDe(hoy);
    final totales = sumarAportes(comidasHoy.map((c) => c.aporte));
    final metaKcal = r.meta('kcal');
    final metaProteina = r.meta('proteina');
    final plan = r.plan;
    final hechosPlan = comidasHoy.where((c) => c.planItemId != null).length;

    return [
      PortadaNutricion(
        foto: FotosNutricion.plato,
        icono: Icons.restaurant_rounded,
        chip: 'Hoy llevas',
        alto: 185,
        alineacion: const Alignment(0, 0.1),
        titulo: Nutriente.kcal.formato(totales['kcal'] ?? 0),
        detalle: metaKcal == null
            ? 'Agrega tu altura y peso para calcular tus metas'
            : 'de ${Nutriente.kcal.formato(metaKcal.cantidad)} de tu meta',
        pie: [
          DatoPie(
            icono: Icons.local_fire_department_rounded,
            valor: '${r.racha.actual} ${r.racha.actual == 1 ? 'día' : 'días'}',
            pie: 'racha',
          ),
          DatoPie(
            icono: Icons.emoji_events_rounded,
            valor: '${r.racha.mejor} ${r.racha.mejor == 1 ? 'día' : 'días'}',
            pie: 'tu récord',
          ),
        ],
      ),
      if (!r.perfil.completo) ...[
        const SizedBox(height: AppEspaciado.md),
        TarjetaPlana(
          color: AppColores.advertencia.withValues(alpha: 0.08),
          colorBorde: AppColores.advertencia.withValues(alpha: 0.4),
          onTap: _editarPerfil,
          child: const Row(
            children: [
              Icon(Icons.height_rounded, color: AppColores.advertencia),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Falta tu altura. Agrégala para calcular cuánta proteína y '
                  'grasa te toca al día.',
                  style: TextStyle(fontSize: 13, height: 1.35),
                ),
              ),
              Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ],
      const SizedBox(height: AppEspaciado.md),
      SizedBox(
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _registrar,
          icon: const Icon(Icons.add_rounded),
          label: const Text('Registrar comida'),
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppEspaciado.radio),
            ),
          ),
        ),
      ),
      const SizedBox(height: AppEspaciado.lg),
      Row(
        children: [
          Expanded(
            child: AccesoFoto(
              foto: FotosNutricion.diario,
              icono: Icons.menu_book_rounded,
              titulo: 'Mi diario',
              detalle: comidasHoy.isEmpty
                  ? 'Nada registrado hoy'
                  : '${comidasHoy.length} alimento(s) hoy',
              onTap: () => _abrir(DiarioNutricionScreen(controlador: _c)),
            ),
          ),
          const SizedBox(width: AppEspaciado.sm + 4),
          Expanded(
            child: AccesoFoto(
              foto: FotosNutricion.mesa,
              icono: Icons.assignment_rounded,
              titulo: 'Mi plan',
              detalle: plan == null
                  ? 'Sin plan asignado'
                  : '$hechosPlan de ${plan.items.length} hoy',
              onTap: () => _abrir(PlanNutricionScreen(controlador: _c)),
            ),
          ),
        ],
      ),
      const SizedBox(height: AppEspaciado.sm + 4),
      Row(
        children: [
          Expanded(
            child: AccesoFoto(
              foto: FotosNutricion.metas,
              icono: Icons.flag_rounded,
              titulo: 'Mis metas',
              detalle: metaProteina == null
                  ? 'Falta altura o peso'
                  : 'Proteína ${Nutriente.proteina.formato(totales['proteina'] ?? 0)}'
                        ' de ${Nutriente.proteina.formato(metaProteina.cantidad)}',
              onTap: () => _abrir(MetasNutricionScreen(controlador: _c)),
            ),
          ),
          const SizedBox(width: AppEspaciado.sm + 4),
          Expanded(
            child: AccesoFoto(
              foto: FotosApp.progreso,
              icono: Icons.insights_rounded,
              titulo: 'Mi progreso',
              detalle:
                  '${r.racha.diasCumplidos} de ${r.racha.diasConRegistro} días cumplidos',
              onTap: () => _abrir(ProgresoNutricionScreen(controlador: _c)),
            ),
          ),
        ],
      ),
    ];
  }
}
