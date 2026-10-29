import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ejercicios/presentacion/widget/hoja_agregar_ejercicio.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/features/entrenamiento_funcional/presentacion/screen/detalle_plan_screen.dart';
import 'package:xnox_app/features/rutinas_admin/datos/repositorio_rutinas_admin.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

/// Crear o editar una rutina personalizada de un miembro. La rutina es la
/// semana: cada día tiene uno o varios bloques y cada bloque su metodología
/// (musculación, circuito, HIIT, EMOM, AMRAP o estaciones) con sus rondas y
/// tiempos. Guarda contra el backend (rutinas.php, metodo guardar). Devuelve
/// `true` al Navigator si guardó.
class FormRutinaAdminScreen extends StatefulWidget {
  final int miembroId;

  /// Si viene, se edita esa rutina; si es null, se crea una nueva.
  final int? rutinaId;

  const FormRutinaAdminScreen({
    super.key,
    required this.miembroId,
    this.rutinaId,
  });

  @override
  State<FormRutinaAdminScreen> createState() => _FormRutinaAdminScreenState();
}

class _FormRutinaAdminScreenState extends State<FormRutinaAdminScreen> {
  final _repo = RepositorioRutinasAdmin();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();

  RutinaAdmin _rutina = RutinaAdmin();
  String _dia = diasSemana.first;
  bool _cargando = false;
  bool _guardando = false;

  bool get _esEdicion => widget.rutinaId != null;

  List<DiaAdmin> get _bloquesDelDia =>
      _rutina.dias.where((d) => d.diaSemana == _dia).toList();

  @override
  void initState() {
    super.initState();
    if (_esEdicion) {
      _cargar();
    } else {
      _rutina = RutinaAdmin(miembroId: widget.miembroId);
    }
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _objetivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final rutina = await _repo.obtener(widget.rutinaId!);
    if (!mounted) return;
    if (rutina == null) {
      setState(() => _cargando = false);
      mostrarMensaje(
        context,
        'No se pudo cargar la rutina',
        tipo: TipoMensaje.error,
      );
      return;
    }
    // Aseguramos que quede asociada al miembro al guardar.
    rutina.miembroId = widget.miembroId;
    _nombreCtrl.text = rutina.nombre;
    _descripcionCtrl.text = rutina.descripcion;
    _objetivoCtrl.text = rutina.objetivo ?? '';
    final primero = rutina.plan.sesiones.firstOrNull;
    setState(() {
      _rutina = rutina;
      if (primero != null) _dia = primero.dia;
      _cargando = false;
    });
  }

  void _volcarDatos() {
    _rutina.nombre = _nombreCtrl.text.trim();
    _rutina.descripcion = _descripcionCtrl.text.trim();
    final obj = _objetivoCtrl.text.trim();
    _rutina.objetivo = obj.isEmpty ? null : obj;
  }

  // ------------------------------------------------------------ Bloques
  Future<void> _agregarBloque() async {
    final tipo = await _elegirTipo(titulo: 'Nuevo bloque del ${_dia.toLowerCase()}');
    if (tipo == null || !mounted) return;
    final bloque = DiaAdmin.nuevo(_dia, tipo);
    setState(() => _insertarAlFinalDelDia(bloque));
    await _agregarEjercicio(bloque);
  }

  /// Lo pone después del último bloque de su día (al guardar se ordena la
  /// semana; dentro del día manda este orden).
  void _insertarAlFinalDelDia(DiaAdmin bloque) {
    final ultimo = _rutina.dias.lastIndexWhere((d) => d.diaSemana == bloque.diaSemana);
    _rutina.dias.insert(ultimo == -1 ? _rutina.dias.length : ultimo + 1, bloque);
  }

  void _moverBloque(DiaAdmin bloque, int delta) {
    final delDia = _bloquesDelDia;
    final i = delDia.indexOf(bloque);
    final j = i + delta;
    if (j < 0 || j >= delDia.length) return;
    final otro = delDia[j];
    final a = _rutina.dias.indexOf(bloque);
    final b = _rutina.dias.indexOf(otro);
    setState(() {
      _rutina.dias[a] = otro;
      _rutina.dias[b] = bloque;
    });
  }

  Future<void> _moverADia(DiaAdmin bloque) async {
    final dia = await _elegirDia('Mover a…', excluir: bloque.diaSemana);
    if (dia == null) return;
    setState(() {
      _rutina.dias.remove(bloque);
      bloque.diaSemana = dia;
      _insertarAlFinalDelDia(bloque);
      _dia = dia;
    });
  }

  Future<void> _duplicarDia() async {
    final destino = await _elegirDia('Copiar el ${_dia.toLowerCase()} en…', excluir: _dia);
    if (destino == null) return;
    setState(() {
      for (final b in _bloquesDelDia) {
        _insertarAlFinalDelDia(b.copia(dia: destino));
      }
      _dia = destino;
    });
    if (mounted) mostrarMensaje(context, 'Día copiado', tipo: TipoMensaje.exito);
  }

  Future<void> _agregarEjercicio(DiaAdmin bloque) async {
    final elegido = await mostrarHojaAgregarEjercicio(context);
    if (elegido == null) return;
    final ej = EjercicioAdmin(
      nombre: elegido.nombre,
      series: bloque.metodologia.esSeries ? elegido.series : 0,
      repeticiones: elegido.repeticiones,
      observaciones: elegido.observaciones,
      catalogoId: elegido.catalogoId,
      imagenUrl: elegido.imagenUrl,
    )..completarPara(bloque.metodologia);
    setState(() => bloque.ejercicios.add(ej));
    // En los bloques por tiempo hay que fijar trabajo y descanso.
    if (!bloque.metodologia.esSeries && mounted) await _editarEjercicio(bloque, ej);
  }

  Future<void> _guardar() async {
    _volcarDatos();
    final error = MotorRutina.validar(_rutina.plan);
    if (error != null) {
      mostrarMensaje(context, error, tipo: TipoMensaje.advertencia);
      return;
    }
    if (_rutina.dias.any((d) => d.ejercicios.isEmpty)) {
      mostrarMensaje(
        context,
        'Cada bloque debe tener al menos un ejercicio',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }

    setState(() => _guardando = true);
    final err = await _repo.guardar(_rutina);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (err == null) {
      mostrarMensaje(
        context,
        'Rutina guardada correctamente',
        tipo: TipoMensaje.exito,
      );
      Navigator.of(context).pop(true);
    } else {
      mostrarMensaje(context, err, tipo: TipoMensaje.error);
    }
  }

  void _vistaPrevia() {
    _volcarDatos();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => DetallePlanScreen(
          plan: _rutina.plan,
          descripcion: _rutina.descripcion,
          textoIniciar: 'Probar',
        ),
      ),
    );
  }

  // -------------------------------------------------------------- Hojas
  Future<String?> _elegirTipo({required String titulo, String? actual}) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                titulo,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 12),
              for (final m in Metodologia.todas)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Material(
                    color: m.valor == actual
                        ? m.color.withValues(alpha: 0.08)
                        : AppColores.fondo,
                    borderRadius: BorderRadius.circular(12),
                    child: ListTile(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: m.valor == actual ? m.color : Colors.transparent,
                        ),
                      ),
                      leading: CircleAvatar(
                        backgroundColor: m.color.withValues(alpha: 0.12),
                        child: Icon(m.icono, color: m.color),
                      ),
                      title: Text(
                        m.texto,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(m.ayuda, style: const TextStyle(fontSize: 12)),
                      onTap: () => Navigator.pop(c, m.valor),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<String?> _elegirDia(String titulo, {String? excluir}) {
    return showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
            for (final d in diasSemana.where((d) => d != excluir))
              ListTile(title: Text(d), onTap: () => Navigator.pop(c, d)),
          ],
        ),
      ),
    );
  }

  /// Campo numérico entero (o decimal) para las hojas de edición.
  Widget _campoNumero(
    String etiqueta,
    num? valor,
    void Function(String) onChanged, {
    bool decimal = false,
    String? ayuda,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: valor == null || valor == 0 ? '' : '$valor',
        keyboardType: TextInputType.numberWithOptions(decimal: decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
        ],
        decoration: InputDecoration(labelText: etiqueta, helperText: ayuda),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _hoja(String titulo, List<Widget> campos) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(c).viewInsets.bottom),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 14),
                ...campos,
                FilledButton(
                  onPressed: () => Navigator.pop(c),
                  child: const Text('Listo'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int? _ent(String v) {
    final n = int.tryParse(v);
    return n == null || n <= 0 ? null : n;
  }

  Future<void> _editarReglas(DiaAdmin b) async {
    final m = b.metodologia;
    final ultimo = _bloquesDelDia.last == b;
    await _hoja('Reglas · ${MotorRutina.nombreBloque(b.plan, _bloquesDelDia.indexOf(b))}', [
      TextFormField(
        initialValue: b.nombre ?? '',
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
          labelText: 'Nombre (opcional)',
          hintText: 'Ej. Calentamiento, ${m.etiquetaBloque} A',
        ),
        onChanged: (v) => b.nombre = v.trim().isEmpty ? null : v.trim(),
      ),
      const SizedBox(height: 12),
      if (m.usa(CampoMetodologia.rondas))
        _campoNumero(m.etiquetaRondas, b.rondas, (v) => b.rondas = _ent(v) ?? 1),
      if (m.usa(CampoMetodologia.descansoRonda))
        _campoNumero(
          'Descanso entre rondas (s)',
          b.descansoRondaSeg,
          (v) => b.descansoRondaSeg = _ent(v),
        ),
      if (m.usa(CampoMetodologia.tiempoLimite))
        _campoNumero(
          'Tiempo límite (min)',
          b.tiempoLimiteSeg == null ? null : b.tiempoLimiteSeg! ~/ 60,
          (v) => b.tiempoLimiteSeg = _ent(v) == null ? null : _ent(v)! * 60,
        ),
      if (m.usa(CampoMetodologia.intervalo))
        _campoNumero(
          'Intervalo (s)',
          b.intervaloSeg,
          (v) => b.intervaloSeg = _ent(v),
          ayuda: '60 = cada minuto',
        ),
      if (!ultimo)
        _campoNumero(
          'Descanso al terminar el bloque (s)',
          b.descansoBloqueSeg,
          (v) => b.descansoBloqueSeg = _ent(v),
        ),
    ]);
    if (mounted) setState(() {});
  }

  Future<void> _editarEjercicio(DiaAdmin b, EjercicioAdmin e) async {
    final m = b.metodologia;
    await _hoja(e.nombre, [
      if (m.usa(CampoMetodologia.series))
        _campoNumero('Series', e.series, (v) => e.series = _ent(v) ?? 0),
      if (m.usa(CampoMetodologia.trabajo))
        _campoNumero(
          'Trabajo (s)',
          e.trabajoSeg,
          (v) => e.trabajoSeg = _ent(v),
          ayuda: m.trabajoObligatorio ? 'Obligatorio en ${m.texto}' : 'Vacío = por repeticiones',
        ),
      if (m.usa(CampoMetodologia.repeticiones))
        _campoNumero('Repeticiones', e.repeticiones, (v) => e.repeticiones = _ent(v) ?? 0),
      if (m.usa(CampoMetodologia.peso))
        _campoNumero(
          'Peso (kg)',
          e.pesoKg,
          (v) {
            final p = double.tryParse(v);
            e.pesoKg = p == null || p <= 0 ? null : p;
          },
          decimal: true,
        ),
      if (m.usa(CampoMetodologia.descanso))
        _campoNumero(m.etiquetaDescanso, e.descansoSeg, (v) => e.descansoSeg = _ent(v)),
      TextFormField(
        initialValue: e.observaciones ?? '',
        decoration: const InputDecoration(labelText: 'Observaciones (opcional)'),
        onChanged: (v) => e.observaciones = v.trim().isEmpty ? null : v.trim(),
      ),
      const SizedBox(height: 14),
    ]);
    if (mounted) setState(() {});
  }

  // ----------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    final duracion = MotorRutina.duracionEstimada(_rutina.plan);
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: _cargando
          ? null
          : PieBoton(
              texto: 'Guardar rutina',
              icono: Icons.check_rounded,
              cargando: _guardando,
              onPressed: _guardar,
            ),
      body: SafeArea(
        bottom: false,
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(AppEspaciado.md),
                children: [
                  CabeceraApp(
                    titulo: _esEdicion ? 'Editar rutina' : 'Nueva rutina',
                    subtitulo: duracion > 0
                        ? '${_rutina.plan.metodologia.texto} · día más largo ~${formatoDuracion(duracion)}'
                        : 'Rutina semanal del socio',
                    acciones: [
                      IconButton(
                        tooltip: 'Vista previa',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: _rutina.dias.isEmpty ? null : _vistaPrevia,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                  const TituloSeccion(
                    icono: Icons.edit_note_rounded,
                    titulo: 'Datos',
                  ),
                  _datos(),
                  const SizedBox(height: AppEspaciado.lg),
                  const TituloSeccion(
                    icono: Icons.calendar_view_week_rounded,
                    titulo: 'Semana',
                  ),
                  _semana(),
                  const SizedBox(height: AppEspaciado.lg),
                  _cabeceraDia(),
                  const SizedBox(height: AppEspaciado.sm),
                  for (final b in _bloquesDelDia) _tarjetaBloque(b),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _agregarBloque,
                    icon: const Icon(Icons.add_rounded),
                    label: Text(
                      _bloquesDelDia.isEmpty
                          ? 'Agregar bloque al ${_dia.toLowerCase()}'
                          : 'Agregar otro bloque',
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _datos() => TarjetaPlana(
    child: Column(
      children: [
        TextField(
          controller: _nombreCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Nombre de la rutina',
            hintText: 'Ej. Fuerza - Nivel 1',
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        TextField(
          controller: _objetivoCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Objetivo (opcional)',
            hintText: 'Ej. Resistencia, bajar de peso',
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        DropdownButtonFormField<String?>(
          initialValue: _rutina.nivel,
          decoration: const InputDecoration(labelText: 'Nivel'),
          items: [
            const DropdownMenuItem(value: null, child: Text('Sin indicar')),
            for (final n in nivelesRutina.entries)
              DropdownMenuItem(value: n.key, child: Text(n.value)),
          ],
          onChanged: (v) => setState(() => _rutina.nivel = v),
        ),
        const SizedBox(height: AppEspaciado.md),
        TextField(
          controller: _descripcionCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          decoration: const InputDecoration(labelText: 'Descripción (opcional)'),
        ),
      ],
    ),
  );

  /// Tira L–D: cada día muestra los tipos de sus bloques; toca uno para
  /// armar su sesión.
  Widget _semana() {
    return TarjetaPlana(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
      child: Row(
        children: [
          for (final d in diasSemana)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _dia = d),
                child: _chipDia(d),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipDia(String d) {
    final bloques = _rutina.dias.where((b) => b.diaSemana == d).toList();
    final activo = d == _dia;
    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            gradient: activo ? AppColores.degradadoRelleno : null,
            color: activo
                ? null
                : bloques.isNotEmpty
                ? AppColores.primario.withValues(alpha: 0.14)
                : AppColores.primario.withValues(alpha: 0.05),
            shape: BoxShape.circle,
            border: activo ? AppColores.bordeCabecera : null,
          ),
          child: Text(
            d.substring(0, 2),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 13,
              color: activo ? AppColores.sobreRelleno : AppColores.primario,
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 14,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final b in bloques.take(3))
                Icon(b.metodologia.icono, size: 12, color: b.metodologia.color),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cabeceraDia() {
    final sesion = _rutina.plan.sesiones.where((s) => s.dia == _dia).firstOrNull;
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _dia,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColores.textoPrincipal,
                ),
              ),
              Text(
                sesion == null
                    ? 'Día de descanso'
                    : '${sesion.bloques.length} bloque(s) · ~${formatoDuracion(sesion.duracion)}',
                style: const TextStyle(fontSize: 13, color: AppColores.textoSecundario),
              ),
            ],
          ),
        ),
        if (_bloquesDelDia.isNotEmpty)
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'copiar') _duplicarDia();
              if (v == 'vaciar') {
                setState(() => _rutina.dias.removeWhere((b) => b.diaSemana == _dia));
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'copiar', child: Text('Copiar este día en…')),
              PopupMenuItem(value: 'vaciar', child: Text('Dejar como descanso')),
            ],
          ),
      ],
    );
  }

  String _reglas(DiaAdmin b) {
    final m = b.metodologia;
    return switch (m.forma) {
      FormaMetodologia.circuito =>
        '${b.rondas} ${m.etiquetaRondas.toLowerCase()}'
            '${(b.descansoRondaSeg ?? 0) > 0 ? ' · ${b.descansoRondaSeg} s entre rondas' : ''}',
      FormaMetodologia.emom =>
        'cada ${b.intervaloSeg ?? 60} s · ${formatoDuracion(b.tiempoLimiteSeg ?? 0)}',
      FormaMetodologia.amrap => formatoDuracion(b.tiempoLimiteSeg ?? 0),
      _ => '',
    };
  }

  Widget _tarjetaBloque(DiaAdmin b) {
    final m = b.metodologia;
    final delDia = _bloquesDelDia;
    final i = delDia.indexOf(b);
    final reglas = _reglas(b);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: Container(
        decoration: BoxDecoration(
          color: AppColores.superficie,
          borderRadius: BorderRadius.circular(AppEspaciado.radio),
          border: Border(left: BorderSide(color: m.color, width: 4)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: m.color.withValues(alpha: 0.12),
                  child: Icon(m.icono, color: m.color, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => _editarReglas(b),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          MotorRutina.nombreBloque(b.plan, i),
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: AppColores.textoPrincipal,
                          ),
                        ),
                        Text(
                          [
                            m.texto,
                            if (reglas.isNotEmpty) reglas,
                            '~${formatoDuracion(MotorRutina.duracionBloque(b.plan))}',
                          ].join(' · '),
                          style: TextStyle(fontSize: 12, color: m.color),
                        ),
                      ],
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    switch (v) {
                      case 'reglas':
                        await _editarReglas(b);
                      case 'tipo':
                        final t = await _elegirTipo(titulo: 'Tipo de entrenamiento', actual: b.tipo);
                        if (t != null) setState(() => b.cambiarTipo(t));
                      case 'subir':
                        _moverBloque(b, -1);
                      case 'bajar':
                        _moverBloque(b, 1);
                      case 'duplicar':
                        setState(() {
                          final c = b.copia()..nombre = b.nombre == null ? null : '${b.nombre} (copia)';
                          _rutina.dias.insert(_rutina.dias.indexOf(b) + 1, c);
                        });
                      case 'mover':
                        await _moverADia(b);
                      case 'quitar':
                        setState(() => _rutina.dias.remove(b));
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'reglas', child: Text('Nombre y reglas')),
                    const PopupMenuItem(value: 'tipo', child: Text('Cambiar tipo')),
                    if (i > 0) const PopupMenuItem(value: 'subir', child: Text('Subir')),
                    if (i < delDia.length - 1)
                      const PopupMenuItem(value: 'bajar', child: Text('Bajar')),
                    const PopupMenuItem(value: 'duplicar', child: Text('Duplicar bloque')),
                    const PopupMenuItem(value: 'mover', child: Text('Mover a otro día')),
                    const PopupMenuItem(value: 'quitar', child: Text('Quitar bloque')),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (b.ejercicios.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  'Sin ejercicios todavía',
                  style: TextStyle(fontSize: 12.5, color: AppColores.textoSecundario),
                ),
              )
            else
              for (var k = 0; k < b.ejercicios.length; k++) _filaEjercicio(b, k),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => _agregarEjercicio(b),
                icon: const Icon(Icons.add, size: 18),
                label: Text('Agregar ${m.etiquetaEjercicio.toLowerCase()}'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _medida(DiaAdmin b, EjercicioAdmin e) {
    final m = b.metodologia;
    return [
      if (m.esSeries) '${e.series} series × ${e.repeticiones} reps',
      if (!m.esSeries && e.repeticiones > 0) '${e.repeticiones} reps',
      if ((e.trabajoSeg ?? 0) > 0) '${e.trabajoSeg} s',
      if ((e.pesoKg ?? 0) > 0) '${PlanEjercicio.formatoKg(e.pesoKg!)} kg',
      if (m.usa(CampoMetodologia.descanso) && (e.descansoSeg ?? 0) > 0)
        'desc. ${e.descansoSeg} s',
      if (e.observaciones != null) e.observaciones!,
    ].join(' · ');
  }

  Widget _filaEjercicio(DiaAdmin b, int k) {
    final ej = b.ejercicios[k];
    return InkWell(
      onTap: () => _editarEjercicio(b, ej),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            _miniatura(ej.imagenUrl),
            const SizedBox(width: AppEspaciado.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ej.nombre,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  Text(
                    _medida(b, ej),
                    style: const TextStyle(fontSize: 12, color: AppColores.textoSecundario),
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 18),
              onSelected: (v) => setState(() {
                switch (v) {
                  case 'subir':
                    b.ejercicios.insert(k - 1, b.ejercicios.removeAt(k));
                  case 'bajar':
                    b.ejercicios.insert(k + 1, b.ejercicios.removeAt(k));
                  case 'duplicar':
                    b.ejercicios.insert(k + 1, ej.copia());
                  case 'quitar':
                    b.ejercicios.removeAt(k);
                }
              }),
              itemBuilder: (_) => [
                if (k > 0) const PopupMenuItem(value: 'subir', child: Text('Subir')),
                if (k < b.ejercicios.length - 1)
                  const PopupMenuItem(value: 'bajar', child: Text('Bajar')),
                const PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                const PopupMenuItem(value: 'quitar', child: Text('Quitar')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniatura(String? url) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? const Icon(
              Icons.fitness_center,
              size: 18,
              color: AppColores.textoSecundario,
            )
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Icon(
                Icons.fitness_center,
                size: 18,
                color: AppColores.textoSecundario,
              ),
            ),
    );
  }
}
