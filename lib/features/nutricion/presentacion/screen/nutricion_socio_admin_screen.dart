import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/controlador/controlador_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/buscar_alimento_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/vista_dia_nutricion.dart';

/// Nutrición de un socio vista por el personal: lo que comió (solo lectura),
/// su plan de comidas y sus metas. Editar plan, metas y altura pide
/// `mobile_nutricion_gestion`.
class NutricionSocioAdminScreen extends StatefulWidget {
  final int miembroId;
  final String nombre;

  const NutricionSocioAdminScreen({
    super.key,
    required this.miembroId,
    required this.nombre,
  });

  @override
  State<NutricionSocioAdminScreen> createState() =>
      _NutricionSocioAdminScreenState();
}

class _NutricionSocioAdminScreenState extends State<NutricionSocioAdminScreen> {
  final _repo = RepositorioNutricion();
  ResumenNutricion? _resumen;
  String? _error;
  bool _cargando = true;
  bool _guardando = false;
  bool _gestiona = false;
  int _pestana = 0;
  DateTime _dia = DateTime.now();

  // Borrador del plan que se edita.
  final _nombrePlan = TextEditingController();
  final _notasPlan = TextEditingController();
  List<ItemPlan> _items = [];
  bool _planCambiado = false;

  // Borrador de las metas.
  final Map<String, TextEditingController> _metas = {
    for (final n in Nutriente.todos) n.clave: TextEditingController(),
  };
  final Map<String, String> _reglas = {};

  @override
  void initState() {
    super.initState();
    Permisos.cargar().then((p) {
      if (!mounted) return;
      setState(() => _gestiona = p.tiene(PermisosMovil.nutricionGestion));
    });
    _cargar();
  }

  @override
  void dispose() {
    _nombrePlan.dispose();
    _notasPlan.dispose();
    for (final c in _metas.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = _resumen == null;
      _error = null;
    });
    try {
      final hoy = DateTime.now();
      final r = await _repo.resumen(
        miembroId: widget.miembroId,
        desde: ControladorNutricion.desde,
        hasta: hoy,
      );
      if (!mounted) return;
      setState(() {
        _resumen = r;
        _cargando = false;
        _copiarBorradores(r);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _cargando = false;
      });
    }
  }

  void _copiarBorradores(ResumenNutricion r) {
    _nombrePlan.text = r.plan?.nombre ?? 'Plan de alimentación';
    _notasPlan.text = r.plan?.notas ?? '';
    _items = [...?r.plan?.items];
    _planCambiado = false;
    for (final n in Nutriente.todos) {
      final m = r.meta(n.clave);
      _metas[n.clave]!.text = m == null
          ? ''
          : '${m.cantidad == m.cantidad.roundToDouble() ? m.cantidad.toInt() : m.cantidad}';
      _reglas[n.clave] =
          m?.regla ??
          switch (n.clave) {
            'proteina' || 'fibra' => 'minimo',
            'kcal' || 'carbohidrato' => 'rango',
            _ => 'maximo',
          };
    }
  }

  Future<void> _accion(Future<void> Function() f, String ok) async {
    setState(() => _guardando = true);
    try {
      await f();
      if (!mounted) return;
      mostrarMensaje(context, ok, tipo: TipoMensaje.exito);
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      mostrarMensaje(context, '$e', tipo: TipoMensaje.error);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ---- Plan ----------------------------------------------------------------

  Future<void> _agregarAlPlan(String tiempo) async {
    final e = await Navigator.of(context).push<EleccionAlimento>(
      MaterialPageRoute(
        builder: (_) =>
            BuscarAlimentoScreen(tiempo: tiempo, textoBoton: 'Agregar al plan'),
      ),
    );
    if (e == null) return;
    setState(() {
      _items.add(
        ItemPlan(tiempo: e.tiempo, cantidadG: e.gramos, alimento: e.alimento),
      );
      _planCambiado = true;
    });
  }

  Future<void> _editarItem(ItemPlan i) async {
    final e = await elegirCantidad(
      context,
      i.alimento,
      tiempo: i.tiempo,
      gramos: i.cantidadG,
      textoBoton: 'Listo',
    );
    if (e == null) return;
    setState(() {
      final k = _items.indexOf(i);
      _items[k] = ItemPlan(
        id: i.id,
        tiempo: e.tiempo,
        cantidadG: e.gramos,
        alimento: i.alimento,
      );
      _planCambiado = true;
    });
  }

  void _guardarPlan() {
    if (_items.isEmpty) {
      mostrarMensaje(
        context,
        'Agrega al menos un alimento',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    _accion(
      () => _repo.guardarPlan(
        miembroId: widget.miembroId,
        nombre: _nombrePlan.text.trim(),
        notas: _notasPlan.text.trim(),
        items: _items,
      ),
      'Plan guardado: el socio ya lo ve en su app',
    );
  }

  Future<void> _quitarPlan() async {
    final ok = await confirmarDialog(
      context,
      titulo: 'Quitar plan',
      mensaje: '¿Quitar el plan de comidas de ${widget.nombre}?',
      icono: Icons.delete_outline_rounded,
      textoConfirmar: 'Quitar',
      peligro: true,
    );
    if (ok) _accion(() => _repo.eliminarPlan(widget.miembroId), 'Plan quitado');
  }

  // ---- Metas ---------------------------------------------------------------

  void _guardarMetas() {
    final metas = <MetaNutricion>[
      for (final n in Nutriente.todos)
        if (double.tryParse(_metas[n.clave]!.text.replaceAll(',', '.'))
            case final v?)
          MetaNutricion(
            clave: n.clave,
            cantidad: v,
            regla: _reglas[n.clave] ?? 'rango',
            origen: 'personal',
          ),
    ];
    if (metas.isEmpty) {
      mostrarMensaje(
        context,
        'Escribe al menos una meta',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    _accion(
      () => _repo.guardarMetas(widget.miembroId, metas),
      'Metas guardadas',
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = _resumen;
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: AppEspaciado.lg,
      pie: _pie(),
      children: [
        CabeceraApp(titulo: widget.nombre, subtitulo: 'Nutrición del socio'),
        const SizedBox(height: AppEspaciado.md),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 80),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (r == null)
          VacioApp(
            icono: Icons.cloud_off_rounded,
            titulo: 'No se pudo cargar',
            texto: _error,
          )
        else ...[
          _resumenSocio(r),
          const SizedBox(height: AppEspaciado.md),
          PestanasApp(
            textos: const ['Comidas', 'Plan', 'Metas', 'Progreso'],
            activa: _pestana,
            onCambio: (i) => setState(() => _pestana = i),
          ),
          const SizedBox(height: AppEspaciado.md),
          ...switch (_pestana) {
            0 => _comidas(r),
            1 => _plan(),
            3 => _progreso(r),
            _ => _metasYPerfil(r),
          },
        ],
      ],
    );
  }

  Widget? _pie() {
    if (!_gestiona || _resumen == null) return null;
    if (_pestana == 1) {
      return PieBoton(
        texto: _planCambiado ? 'Guardar plan' : 'Plan guardado',
        icono: Icons.save_rounded,
        cargando: _guardando,
        onPressed: _planCambiado ? _guardarPlan : null,
      );
    }
    if (_pestana == 2) {
      return PieBoton(
        texto: 'Guardar metas',
        icono: Icons.save_rounded,
        cargando: _guardando,
        onPressed: _guardarMetas,
      );
    }
    return null;
  }

  Widget _resumenSocio(ResumenNutricion r) {
    final p = r.perfil;
    return PortadaNutricion(
      foto: FotosNutricion.mesa,
      icono: Icons.local_fire_department_rounded,
      chip: 'Racha ${r.racha.actual} · récord ${r.racha.mejor}',
      alto: 150,
      titulo: [
        p.alturaCm == null ? 'Sin altura' : '${p.alturaCm!.round()} cm',
        if (p.peso != null) '${p.peso} kg',
      ].join(' · '),
      detalle: [
        if (p.imc != null) 'IMC ${p.imc} (${p.categoriaImc})',
        PerfilNutricion.objetivos[p.objetivo] ?? '',
        '${r.racha.diasCumplidos} de ${r.racha.diasConRegistro} días cumplidos',
      ].join(' · '),
    );
  }

  List<Widget> _comidas(ResumenNutricion r) {
    final consumos = r.consumosDe(isoFecha(_dia));
    return [
      CalendarioNutricion(
        resumen: r,
        seleccionado: _dia,
        desde: ControladorNutricion.desde,
        onElegir: (d) => setState(() => _dia = d),
      ),
      const SizedBox(height: AppEspaciado.md),
      PortadaDia(resumen: r, dia: _dia),
      const SizedBox(height: AppEspaciado.md),
      ComidasDelDia(consumos: consumos),
    ];
  }

  List<Widget> _progreso(ResumenNutricion r) => [
    PortadaNutricion(
      foto: FotosApp.progreso,
      icono: Icons.insights_rounded,
      chip: 'Progreso',
      alto: 140,
      titulo: '${r.racha.actual} días de racha',
      detalle: 'Récord: ${r.racha.mejor} días seguidos cumpliendo',
    ),
    const SizedBox(height: AppEspaciado.md),
    Text(
      'Cumplió proteínas y grasas ${r.racha.diasCumplidos} de '
      '${r.racha.diasConRegistro} días registrados (últimos 90).',
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
    ),
    const SizedBox(height: AppEspaciado.md),
    GraficosNutricion(resumen: r),
    const SizedBox(height: AppEspaciado.md),
    HistorialDias(resumen: r),
  ];

  List<Widget> _plan() {
    final totales = sumarAportes(_items.map((i) => i.aporte));
    final r = _resumen!;
    return [
      if (_gestiona) ...[
        TextField(
          controller: _nombrePlan,
          onChanged: (_) => setState(() => _planCambiado = true),
          decoration: const InputDecoration(labelText: 'Nombre del plan'),
        ),
        const SizedBox(height: AppEspaciado.sm),
        TextField(
          controller: _notasPlan,
          maxLines: 2,
          onChanged: (_) => setState(() => _planCambiado = true),
          decoration: const InputDecoration(
            labelText: 'Indicaciones para el socio',
            hintText: 'Ej. Tomar 2 L de agua, evitar frituras',
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
      ] else if (r.plan == null)
        const VacioApp(
          icono: Icons.no_food_rounded,
          titulo: 'Sin plan asignado',
          texto: 'No tienes permiso para asignar planes.',
        ),
      // Total del día del plan contra las metas.
      TarjetaPlana(
        child: Column(
          children: [
            for (final n in [
              Nutriente.proteina,
              Nutriente.grasa,
              Nutriente.carbohidrato,
              Nutriente.kcal,
            ]) ...[
              BarraMeta(
                nutriente: n,
                valor: totales[n.clave] ?? 0,
                meta: r.meta(n.clave),
              ),
              const SizedBox(height: 10),
            ],
          ],
        ),
      ),
      const SizedBox(height: AppEspaciado.md),
      for (final t in TiempoComida.todos) ...[
        PortadaNutricion(
          foto: FotosNutricion.de(t.clave),
          icono: t.icono,
          chip: t.nombre,
          alto: _gestiona ? 150 : 120,
          titulo: _items.where((i) => i.tiempo == t.clave).isEmpty
              ? 'Sin alimentos'
              : Nutriente.kcal.formato(
                  _items
                      .where((i) => i.tiempo == t.clave)
                      .fold<double>(0, (s, i) => s + (i.aporte['kcal'] ?? 0)),
                ),
          detalle:
              '${_items.where((i) => i.tiempo == t.clave).length} alimento(s)',
          accion: _gestiona
              ? BotonFoto('Agregar', onTap: () => _agregarAlPlan(t.clave))
              : null,
        ),
        const SizedBox(height: AppEspaciado.sm + 2),
        if (_items.where((i) => i.tiempo == t.clave).isEmpty)
          const SizedBox(height: AppEspaciado.sm)
        else ...[
          for (final i in _items.where((i) => i.tiempo == t.clave)) ...[
            TarjetaAlimento(
              alimento: i.alimento,
              gramos: i.cantidadG,
              onTap: _gestiona ? () => _editarItem(i) : null,
              fin: _gestiona
                  ? InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () => setState(() {
                        _items.remove(i);
                        _planCambiado = true;
                      }),
                      child: const Padding(
                        padding: EdgeInsets.all(4),
                        child: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: AppColores.error,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: AppEspaciado.sm + 2),
          ],
          const SizedBox(height: AppEspaciado.md),
        ],
      ],
      if (_gestiona && r.plan != null)
        Center(
          child: TextButton.icon(
            onPressed: _guardando ? null : _quitarPlan,
            icon: const Icon(
              Icons.delete_outline_rounded,
              color: AppColores.error,
            ),
            label: const Text(
              'Quitar plan',
              style: TextStyle(color: AppColores.error),
            ),
          ),
        ),
    ];
  }

  List<Widget> _metasYPerfil(ResumenNutricion r) {
    final p = r.perfil;
    return [
      const PortadaNutricion(
        foto: FotosNutricion.metas,
        icono: Icons.flag_rounded,
        chip: 'Metas diarias',
        alto: 130,
        titulo: 'Perfil y metas',
        detalle: 'Altura, objetivo y cuánto le toca de cada nutriente',
      ),
      const SizedBox(height: AppEspaciado.md),
      TarjetaPlana(
        onTap: _gestiona
            ? () async {
                if (await editarPerfilNutricion(
                  context,
                  perfil: p,
                  miembroId: widget.miembroId,
                )) {
                  await _cargar();
                }
              }
            : null,
        child: Row(
          children: [
            const IconoSuave(Icons.accessibility_new_rounded),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    p.completo
                        ? 'Altura ${p.alturaCm!.round()} cm'
                        : 'Falta la altura',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  Text(
                    '${PerfilNutricion.objetivos[p.objetivo] ?? ''} · '
                    '${PerfilNutricion.actividades[p.actividad] ?? ''}',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            if (_gestiona)
              const Icon(Icons.edit_rounded, color: AppColores.textoSecundario),
          ],
        ),
      ),
      const SizedBox(height: AppEspaciado.md),
      const Text(
        'Las metas se calculan con peso, altura, edad y objetivo. Si escribes '
        'una aquí, queda fija y ya no se recalcula.',
        style: TextStyle(
          fontSize: 12.5,
          height: 1.35,
          color: AppColores.textoSecundario,
        ),
      ),
      const SizedBox(height: AppEspaciado.md),
      for (final n in Nutriente.todos) ...[
        Row(
          children: [
            Expanded(
              flex: 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.nombre,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  Text(
                    switch (r.meta(n.clave)?.origen) {
                      'personal' => 'Fijada por el entrenador',
                      'auto' => 'Calculada',
                      _ => 'Sin meta',
                    },
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              flex: 4,
              child: DropdownButton<String>(
                value: _reglas[n.clave],
                isExpanded: true,
                underline: const SizedBox.shrink(),
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppColores.textoPrincipal,
                ),
                onChanged: _gestiona
                    ? (v) => setState(() => _reglas[n.clave] = v!)
                    : null,
                items: [
                  for (final regla in ['minimo', 'maximo', 'rango'])
                    DropdownMenuItem(
                      value: regla,
                      child: Text(MetaNutricion.nombreRegla(regla)),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 92,
              child: TextField(
                controller: _metas[n.clave],
                enabled: _gestiona,
                textAlign: TextAlign.right,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                decoration: InputDecoration(
                  isDense: true,
                  suffixText: n.unidad,
                  hintText: '—',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
      ],
      if (_gestiona) ...[
        const SizedBox(height: AppEspaciado.sm),
        Center(
          child: TextButton.icon(
            onPressed: _guardando
                ? null
                : () => _accion(
                    () => _repo.restablecerMetas(widget.miembroId),
                    'Se usan otra vez las metas calculadas',
                  ),
            icon: const Icon(Icons.restore_rounded),
            label: const Text('Volver a las calculadas'),
          ),
        ),
      ],
    ];
  }
}
