import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Piezas de Nutrición, cada una por separado para que cada pantalla muestre
/// solo lo suyo (diario, plan, metas, progreso). Las usan el socio (con
/// acciones) y el personal (solo lectura: sin los callbacks).

/// Calendario plegable para elegir el día del diario: cerrado es una barra
/// con el día elegido; al tocarla se abre el mes, y al elegir un día se cierra.
/// Cada día con comidas
/// lleva un punto: verde si cumplió proteínas y grasas, gris si no. No se
/// eligen días futuros ni anteriores a [desde] (lo que se cargó).
class CalendarioNutricion extends StatefulWidget {
  final ResumenNutricion resumen;
  final DateTime seleccionado;
  final DateTime desde;
  final ValueChanged<DateTime> onElegir;

  const CalendarioNutricion({
    super.key,
    required this.resumen,
    required this.seleccionado,
    required this.desde,
    required this.onElegir,
  });

  @override
  State<CalendarioNutricion> createState() => _CalendarioNutricionState();
}

class _CalendarioNutricionState extends State<CalendarioNutricion> {
  late DateTime _mes = DateTime(
    widget.seleccionado.year,
    widget.seleccionado.month,
  );

  static const _diasSemana = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  DateTime get _hoy {
    final h = DateTime.now();
    return DateTime(h.year, h.month, h.day);
  }

  bool get _puedeAtras => DateTime(
    _mes.year,
    _mes.month,
  ).isAfter(DateTime(widget.desde.year, widget.desde.month));

  bool get _puedeAdelante =>
      DateTime(_mes.year, _mes.month).isBefore(DateTime(_hoy.year, _hoy.month));

  /// Cerrado solo se ve la barra con el día elegido; abierto, el mes.
  bool _abierto = false;

  void _mover(int meses) =>
      setState(() => _mes = DateTime(_mes.year, _mes.month + meses));

  void _alternar() => setState(() {
    _abierto = !_abierto;
    // Al abrir, se muestra el mes del día elegido.
    if (_abierto) {
      _mes = DateTime(widget.seleccionado.year, widget.seleccionado.month);
    }
  });

  /// Barra siempre visible: el día elegido y si cumplió; tocarla abre/cierra.
  Widget _barra() {
    final sel = widget.seleccionado;
    final esHoy = isoFecha(sel) == isoFecha(_hoy);
    final texto = DateFormat("EEEE d 'de' MMMM", 'es').format(sel);
    final info = widget.resumen.dia(isoFecha(sel));
    return InkWell(
      borderRadius: BorderRadius.circular(AppEspaciado.radio),
      onTap: _alternar,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        child: Row(
          children: [
            IconoSuave(
              Icons.calendar_month_rounded,
              tamano: 40,
              circular: true,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    esHoy ? 'Hoy' : 'Día elegido',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  Text(
                    texto[0].toUpperCase() + texto.substring(1),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                ],
              ),
            ),
            if (info?.cumpleDia == true) ...[
              const Icon(
                Icons.check_circle_rounded,
                color: AppColores.exito,
                size: 20,
              ),
              const SizedBox(width: 6),
            ],
            AnimatedRotation(
              turns: _abierto ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(
                Icons.expand_more_rounded,
                color: AppColores.primario,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final primero = DateTime(_mes.year, _mes.month);
    final diasMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final vacios = primero.weekday - 1; // Lunes primero.
    final celdas = vacios + diasMes;
    final filas = (celdas / 7).ceil();
    final titulo = DateFormat("MMMM 'de' y", 'es').format(_mes);
    final desde = DateTime(
      widget.desde.year,
      widget.desde.month,
      widget.desde.day,
    );

    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
      child: Column(
        children: [
          _barra(),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: !_abierto
                ? const SizedBox(width: double.infinity)
                : Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Column(
                      children: [
                        const Divider(height: 8),
                        Row(
                          children: [
                            IconButton(
                              onPressed: _puedeAtras ? () => _mover(-1) : null,
                              icon: const Icon(Icons.chevron_left_rounded),
                              tooltip: 'Mes anterior',
                            ),
                            Expanded(
                              child: Text(
                                titulo[0].toUpperCase() + titulo.substring(1),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w800,
                                  color: AppColores.textoPrincipal,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: _puedeAdelante
                                  ? () => _mover(1)
                                  : null,
                              icon: const Icon(Icons.chevron_right_rounded),
                              tooltip: 'Mes siguiente',
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            for (final d in _diasSemana)
                              Expanded(
                                child: Center(
                                  child: Text(
                                    d,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColores.textoSecundario,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        for (var f = 0; f < filas; f++)
                          Row(
                            children: [
                              for (var c = 0; c < 7; c++)
                                Expanded(
                                  child: _celda(
                                    f * 7 + c - vacios + 1,
                                    diasMes,
                                    desde,
                                  ),
                                ),
                            ],
                          ),
                        const SizedBox(height: 8),
                        Wrap(
                          alignment: WrapAlignment.center,
                          spacing: 14,
                          runSpacing: 4,
                          children: [
                            _leyenda(
                              AppColores.exito,
                              'Cumplió proteínas y grasas',
                            ),
                            _leyenda(AppColores.textoSecundario, 'Registró'),
                          ],
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _celda(int dia, int diasMes, DateTime desde) {
    if (dia < 1 || dia > diasMes) return const SizedBox(height: 44);
    final fecha = DateTime(_mes.year, _mes.month, dia);
    final habilitado = !fecha.isAfter(_hoy) && !fecha.isBefore(desde);
    final elegido = isoFecha(fecha) == isoFecha(widget.seleccionado);
    final esHoy = fecha == _hoy;
    final info = widget.resumen.dia(isoFecha(fecha));
    final punto = info == null
        ? null
        : info.cumpleDia == true
        ? AppColores.exito
        : AppColores.textoSecundario;

    return SizedBox(
      height: 44,
      child: InkResponse(
        onTap: habilitado
            ? () {
                setState(() => _abierto = false);
                widget.onElegir(fecha);
              }
            : null,
        radius: 22,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: elegido ? AppColores.primario : null,
                shape: BoxShape.circle,
                border: esHoy && !elegido
                    ? Border.all(color: AppColores.primario, width: 1.5)
                    : null,
              ),
              child: Text(
                '$dia',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: elegido || esHoy
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: elegido
                      ? Colors.white
                      : habilitado
                      ? AppColores.textoPrincipal
                      : AppColores.textoSecundario.withValues(alpha: 0.45),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: punto, shape: BoxShape.circle),
            ),
          ],
        ),
      ),
    );
  }

  Widget _leyenda(Color color, String texto) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 7,
        height: 7,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      ),
      const SizedBox(width: 5),
      Flexible(
        child: Text(
          texto,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColores.textoSecundario,
          ),
        ),
      ),
    ],
  );
}

/// Portada con foto del día elegido: kcal grandes, macros y una barra de 10
/// segmentos con el avance hacia la meta de calorías.
class PortadaDia extends StatelessWidget {
  final ResumenNutricion resumen;
  final DateTime dia;

  const PortadaDia({super.key, required this.resumen, required this.dia});

  @override
  Widget build(BuildContext context) {
    final fecha = isoFecha(dia);
    final t = sumarAportes(resumen.consumosDe(fecha).map((c) => c.aporte));
    final meta = resumen.meta('kcal');
    final kcal = t['kcal'] ?? 0;
    final hoy = isoFecha(DateTime.now()) == fecha;
    final segmentos = meta == null || meta.cantidad <= 0
        ? null
        : (kcal / meta.cantidad * 10).round().clamp(0, 10);
    final s = DateFormat("EEEE d 'de' MMMM", 'es').format(dia);
    return PortadaNutricion(
      foto: FotosNutricion.diario,
      icono: Icons.today_rounded,
      chip: hoy ? 'Hoy' : s,
      alto: 178,
      titulo: meta == null
          ? Nutriente.kcal.formato(kcal)
          : '${Nutriente.kcal.formato(kcal)} de ${meta.cantidad.round()}',
      detalle:
          'Proteínas ${Nutriente.proteina.formato(t['proteina'] ?? 0)} · '
          'Carbos ${Nutriente.carbohidrato.formato(t['carbohidrato'] ?? 0)} · '
          'Grasas ${Nutriente.grasa.formato(t['grasa'] ?? 0)}',
      hechos: segmentos,
      total: segmentos == null ? null : 10,
    );
  }
}

/// Avance del día contra las metas (proteínas, grasas, carbohidratos, kcal) y
/// el resto de nutrientes en una línea.
class TarjetaMetasDia extends StatelessWidget {
  final ResumenNutricion resumen;
  final Map<String, double> totales;
  final bool cumpleDia;

  const TarjetaMetasDia({
    super.key,
    required this.resumen,
    required this.totales,
    this.cumpleDia = false,
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaPlana(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (cumpleDia)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: InsigniaNutricion(
                Icons.emoji_events_rounded,
                '¡Proteínas y grasas cumplidas!',
                AppColores.exito,
              ),
            ),
          if (resumen.metas.isEmpty)
            const Text(
              'Aún no hay metas: falta la altura o el peso. '
              'Con esos datos se calculan solas.',
              style: TextStyle(fontSize: 13, color: AppColores.textoSecundario),
            ),
          for (final (i, n) in [
            Nutriente.proteina,
            Nutriente.grasa,
            Nutriente.carbohidrato,
            Nutriente.kcal,
          ].indexed) ...[
            SizedBox(height: i == 0 ? 8 : 16),
            BarraMeta(
              nutriente: n,
              valor: totales[n.clave] ?? 0,
              meta: resumen.meta(n.clave),
            ),
          ],
          const SizedBox(height: 14),
          Text(
            'Además: grasas saturadas '
            '${Nutriente.grasaSaturada.formato(totales['grasa_saturada'] ?? 0)}'
            ' · azúcares ${Nutriente.azucar.formato(totales['azucar'] ?? 0)}'
            ' · sodio ${Nutriente.sodio.formato(totales['sodio'] ?? 0)}'
            ' · fibra ${Nutriente.fibra.formato(totales['fibra'] ?? 0)}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.35,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Lo que comió un día: una portada con foto por desayuno, almuerzo, cena y
/// aperitivos (con su botón "Agregar") y debajo una tarjeta con foto por
/// alimento. Tocar uno lo edita; deslizarlo lo quita.
class ComidasDelDia extends StatelessWidget {
  final List<Consumo> consumos;

  /// Abre el buscador para agregar a esa comida. null = solo lectura.
  final ValueChanged<String>? onAgregar;
  final ValueChanged<Consumo>? onEliminar;
  final ValueChanged<Consumo>? onEditar;

  const ComidasDelDia({
    super.key,
    required this.consumos,
    this.onAgregar,
    this.onEliminar,
    this.onEditar,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in TiempoComida.todos)
          ..._seccion(t, consumos.where((c) => c.tiempo == t.clave).toList()),
      ],
    );
  }

  List<Widget> _seccion(TiempoComida t, List<Consumo> comidos) {
    final aporte = sumarAportes(comidos.map((c) => c.aporte));
    return [
      PortadaNutricion(
        foto: FotosNutricion.de(t.clave),
        icono: t.icono,
        chip: t.nombre,
        alto: onAgregar == null ? 128 : 160,
        titulo: comidos.isEmpty
            ? 'Nada registrado'
            : Nutriente.kcal.formato(aporte['kcal'] ?? 0),
        detalle: comidos.isEmpty
            ? (onAgregar == null
                  ? null
                  : '¿Qué comiste en ${t.nombre.toLowerCase()}?')
            : '${comidos.length} alimento(s) · '
                  'P ${Nutriente.proteina.formato(aporte['proteina'] ?? 0)} · '
                  'G ${Nutriente.grasa.formato(aporte['grasa'] ?? 0)}',
        accion: onAgregar == null
            ? null
            : BotonFoto('Agregar', onTap: () => onAgregar!(t.clave)),
      ),
      const SizedBox(height: AppEspaciado.sm + 2),
      for (final c in comidos) ...[
        _fila(c),
        const SizedBox(height: AppEspaciado.sm + 2),
      ],
      const SizedBox(height: AppEspaciado.md),
    ];
  }

  Widget _fila(Consumo c) {
    final tarjeta = TarjetaAlimento(
      alimento: c.alimento,
      gramos: c.cantidadG,
      onTap: onEditar == null ? null : () => onEditar!(c),
      nota: c.planItemId != null ? 'Del plan' : null,
    );
    if (onEliminar == null) return tarjeta;
    return Dismissible(
      key: ValueKey('consumo-${c.uid}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) async {
        onEliminar!(c);
        return false; // La lista se recarga desde el servidor.
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: AppColores.error.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppEspaciado.radio + 2),
        ),
        child: const Icon(Icons.delete_rounded, color: AppColores.error),
      ),
      child: tarjeta,
    );
  }
}

/// El plan del entrenador por comida: un encabezado por desayuno, almuerzo,
/// cena y aperitivos con cuántos lleva hoy, y debajo una tarjeta con foto por
/// alimento. Con [onComi], los que aún no marcó [hoy] llevan "Lo comí"; los
/// comidos salen con ✓.
class PlanPorComidas extends StatelessWidget {
  final PlanNutricion plan;
  final List<Consumo> consumosDelDia;
  final void Function(ItemPlan item)? onComi;

  const PlanPorComidas({
    super.key,
    required this.plan,
    this.consumosDelDia = const [],
    this.onComi,
  });

  @override
  Widget build(BuildContext context) {
    final hechos = consumosDelDia
        .map((c) => c.planItemId)
        .whereType<int>()
        .toSet();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final t in TiempoComida.todos)
          if (plan.de(t.clave).isNotEmpty) ...[
            PortadaNutricion(
              foto: FotosNutricion.de(t.clave),
              icono: t.icono,
              chip: t.nombre,
              alto: 140,
              titulo: Nutriente.kcal.formato(
                plan
                    .de(t.clave)
                    .fold<double>(0, (s, i) => s + (i.aporte['kcal'] ?? 0)),
              ),
              detalle:
                  '${plan.de(t.clave).length} alimento(s) · '
                  '${plan.de(t.clave).where((i) => hechos.contains(i.id)).length} '
                  'comido(s) hoy',
              hechos: plan
                  .de(t.clave)
                  .where((i) => hechos.contains(i.id))
                  .length,
              total: plan.de(t.clave).length,
            ),
            const SizedBox(height: AppEspaciado.sm + 2),
            for (final i in plan.de(t.clave)) ...[
              TarjetaAlimento(
                alimento: i.alimento,
                gramos: i.cantidadG,
                comido: hechos.contains(i.id),
                accion: hechos.contains(i.id) || onComi == null
                    ? null
                    : FilledButton.tonalIcon(
                        onPressed: () => onComi!(i),
                        icon: const Icon(Icons.check_rounded, size: 18),
                        label: const Text('Lo comí'),
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
              ),
              const SizedBox(height: AppEspaciado.sm + 2),
            ],
            const SizedBox(height: AppEspaciado.md),
          ],
      ],
    );
  }
}

/// Tarjeta de un alimento con su foto grande, la cantidad en gramos (y a qué
/// equivale), lo que aporta y sus etiquetas. [accion] va abajo a la derecha;
/// [fin] arriba a la derecha (p. ej. quitar). [comido] marca la foto con ✓.
class TarjetaAlimento extends StatelessWidget {
  final Alimento alimento;
  final double gramos;
  final bool comido;
  final Widget? accion;
  final Widget? fin;
  final VoidCallback? onTap;

  /// Texto chico junto a la cantidad (p. ej. "Del plan").
  final String? nota;

  const TarjetaAlimento({
    super.key,
    required this.alimento,
    required this.gramos,
    this.comido = false,
    this.accion,
    this.fin,
    this.onTap,
    this.nota,
  });

  @override
  Widget build(BuildContext context) {
    final aporte = alimento.aporte(gramos);
    return TarjetaPlana(
      onTap: onTap,
      padding: const EdgeInsets.all(10),
      color: comido ? AppColores.exito.withValues(alpha: 0.04) : null,
      colorBorde: comido ? AppColores.exito.withValues(alpha: 0.35) : null,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              FotoAlimento(alimento, tamano: 84, radio: 14),
              if (comido)
                Positioned(
                  right: 4,
                  top: 4,
                  child: Container(
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check_circle_rounded,
                      color: AppColores.exito,
                      size: 24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        alimento.nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                    ),
                    ?fin,
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.scale_rounded,
                      size: 14,
                      color: AppColores.textoSecundario,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        nota == null
                            ? alimento.cantidadTexto(gramos)
                            : '${alimento.cantidadTexto(gramos)} · $nota',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 5,
                  runSpacing: 5,
                  children: [
                    for (final n in [
                      Nutriente.kcal,
                      Nutriente.proteina,
                      Nutriente.carbohidrato,
                      Nutriente.grasa,
                    ])
                      PildoraNutriente(n, aporte[n.clave] ?? 0),
                  ],
                ),
                if (alimento.etiquetas.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  EtiquetasAlimento(alimento.etiquetas),
                ],
                if (accion != null) ...[
                  const SizedBox(height: 6),
                  Align(alignment: Alignment.centerRight, child: accion),
                ] else if (comido) ...[
                  const SizedBox(height: 6),
                  const Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'Comido hoy',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: AppColores.exito,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora con el aporte de un nutriente: "P 46 g" en su color.
class PildoraNutriente extends StatelessWidget {
  final Nutriente nutriente;
  final double valor;

  const PildoraNutriente(this.nutriente, this.valor, {super.key});

  @override
  Widget build(BuildContext context) {
    final color = ColoresNutricion.de(nutriente.clave);
    final prefijo = switch (nutriente.clave) {
      'proteina' => 'P ',
      'carbohidrato' => 'C ',
      'grasa' => 'G ',
      _ => '',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            '$prefijo${nutriente.formato(valor)}',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: AppColores.textoPrincipal,
            ),
          ),
        ],
      ),
    );
  }
}

/// Píldora con ícono y texto (el estado nunca va solo en color).
class InsigniaNutricion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;

  const InsigniaNutricion(this.icono, this.texto, this.color, {super.key});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icono, size: 15, color: color),
        const SizedBox(width: 5),
        Text(
          texto,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    ),
  );
}

/// Indicaciones que el entrenador escribió en el plan.
class NotasPlan extends StatelessWidget {
  final String notas;
  final String titulo;

  const NotasPlan(
    this.notas, {
    super.key,
    this.titulo = 'Indicaciones de tu entrenador',
  });

  @override
  Widget build(BuildContext context) {
    return TarjetaPlana(
      color: AppColores.primario.withValues(alpha: 0.05),
      colorBorde: AppColores.primario.withValues(alpha: 0.2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.sticky_note_2_rounded, color: AppColores.primario),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  notas,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Últimos días con registro: si cumplió proteínas y grasas (✓/✗ con texto).
class HistorialDias extends StatelessWidget {
  final ResumenNutricion resumen;
  final int dias;

  const HistorialDias({super.key, required this.resumen, this.dias = 14});

  @override
  Widget build(BuildContext context) {
    final lista = resumen.dias.reversed.take(dias).toList();
    if (lista.isEmpty) {
      return const VacioApp(
        icono: Icons.event_busy_rounded,
        titulo: 'Sin días registrados',
        texto: 'Registra lo que comes para ver tu historial.',
      );
    }
    return GrupoFilas(
      filas: [
        for (final d in lista)
          FilaApp(
            inicio: _foto(d),
            titulo: _fecha(d.fecha),
            subtitulo:
                '${Nutriente.kcal.formato(d.totales['kcal'] ?? 0)} · '
                'P ${Nutriente.proteina.formato(d.totales['proteina'] ?? 0)} · '
                'G ${Nutriente.grasa.formato(d.totales['grasa'] ?? 0)}',
            fin: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 92),
              child: Text(
                switch (d.cumpleDia) {
                  true => 'Cumplió',
                  false => _queFallo(d),
                  null => 'Sin metas',
                },
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: d.cumpleDia == true
                      ? AppColores.exito
                      : AppColores.textoSecundario,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Foto de lo que más calorías aportó ese día, con ✓ / ✗ encima.
  Widget _foto(DiaNutricion d) {
    final comidas = resumen.consumosDe(
      d.fecha,
    )..sort((a, b) => (b.aporte['kcal'] ?? 0).compareTo(a.aporte['kcal'] ?? 0));
    final (icono, color) = switch (d.cumpleDia) {
      true => (Icons.check_circle_rounded, AppColores.exito),
      false => (Icons.cancel_rounded, AppColores.error),
      null => (Icons.remove_circle_rounded, AppColores.textoSecundario),
    };
    return SizedBox(
      width: 54,
      height: 54,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          comidas.isEmpty
              ? const IconoSuave(Icons.restaurant_rounded, tamano: 50)
              : FotoAlimento(comidas.first.alimento, tamano: 50, radio: 12),
          Positioned(
            right: -2,
            bottom: -2,
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(icono, size: 20, color: color),
            ),
          ),
        ],
      ),
    );
  }

  static String _fecha(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final s = DateFormat("EEEE d 'de' MMMM", 'es').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  static String _queFallo(DiaNutricion d) {
    final faltas = [
      if (d.cumple['proteina'] == false) 'proteína',
      if (d.cumple['grasa'] == false) 'grasas',
    ];
    return faltas.isEmpty ? 'No cumplió' : 'Falló ${faltas.join(' y ')}';
  }
}

/// Gráficos de proteínas y grasas de los últimos [dias] días.
class GraficosNutricion extends StatelessWidget {
  final ResumenNutricion resumen;
  final int dias;

  const GraficosNutricion({super.key, required this.resumen, this.dias = 14});

  @override
  Widget build(BuildContext context) {
    final hoy = DateTime.now();
    final fechas = [
      for (var i = dias - 1; i >= 0; i--)
        DateTime(hoy.year, hoy.month, hoy.day - i),
    ];
    final porFecha = {for (final d in resumen.dias) d.fecha: d};
    return Column(
      children: [
        for (final n in [Nutriente.proteina, Nutriente.grasa]) ...[
          GraficoDiasNutriente(
            nutriente: n,
            fechas: fechas,
            porFecha: porFecha,
            meta: resumen.meta(n.clave),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
        ],
      ],
    );
  }
}
