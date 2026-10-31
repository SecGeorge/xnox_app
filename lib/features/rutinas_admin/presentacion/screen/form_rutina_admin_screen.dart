import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/ejercicios/datos/repositorio_ejercicios.dart';
import 'package:xnox_app/features/ejercicios/dominio/entidades/ejercicio_catalogo.dart';
import 'package:xnox_app/features/ejercicios/presentacion/widget/hoja_agregar_ejercicio.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/metodologia.dart';
import 'package:xnox_app/features/entrenamiento_funcional/dominio/motor_rutina.dart';
import 'package:xnox_app/features/entrenamiento_funcional/presentacion/screen/detalle_plan_screen.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/fuente_rutina.dart';
import 'package:xnox_app/features/rutinas_admin/dominio/rutina_admin.dart';

/// Editor de rutinas, con los mismos datos y la misma forma que el del web:
/// datos de la rutina, la semana (cada día con uno o varios bloques), cada
/// bloque con su metodología y reglas, y cada ejercicio con su grupo
/// muscular, series, repeticiones, peso, descanso, tempo y velocidad.
///
/// Dónde carga y guarda lo decide [fuente]: el personal guarda en el
/// servidor (rutinas generales o de un socio) y el socio, su rutina propia en
/// el teléfono. Devuelve `true` al Navigator si guardó.
class FormRutinaAdminScreen extends StatefulWidget {
  final FuenteRutina fuente;

  const FormRutinaAdminScreen({super.key, required this.fuente});

  @override
  State<FormRutinaAdminScreen> createState() => _FormRutinaAdminScreenState();
}

class _FormRutinaAdminScreenState extends State<FormRutinaAdminScreen> {
  final _repoEjercicios = RepositorioEjercicios();
  final _nombreCtrl = TextEditingController();
  final _descripcionCtrl = TextEditingController();
  final _objetivoCtrl = TextEditingController();

  RutinaAdmin _rutina = RutinaAdmin();
  String _dia = diasSemana.first;
  bool _cargando = true;
  bool _guardando = false;

  /// Catálogo del gimnasio para elegir ejercicios, y sus grupos musculares.
  List<EjercicioCatalogo> _catalogo = [];
  List<String> _grupos = [];

  /// Grupo muscular elegido en cada fila de ejercicio (solo filtra la búsqueda).
  final _grupoFila = Map<EjercicioAdmin, String?>.identity();

  /// Sube cuando un cambio masivo (aplicar a todos, cambiar el tipo) reescribe
  /// valores: los campos se reconstruyen con lo nuevo.
  int _version = 0;

  /// Llenado rápido de los bloques por tiempo.
  final _rapido = Map<DiaAdmin, (int, int)>.identity();

  bool get _esEdicion => widget.fuente.rutinaId != null;

  List<DiaAdmin> get _bloquesDelDia =>
      _rutina.dias.where((d) => d.diaSemana == _dia).toList();

  @override
  void initState() {
    super.initState();
    _cargar();
    _cargarCatalogo();
  }

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _descripcionCtrl.dispose();
    _objetivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final rutina = await widget.fuente.cargar();
    if (!mounted) return;
    if (rutina == null) {
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudo cargar la rutina', tipo: TipoMensaje.error);
      return;
    }
    _nombreCtrl.text = rutina.nombre;
    _descripcionCtrl.text = rutina.descripcion;
    _objetivoCtrl.text = rutina.objetivo ?? '';
    final primero = rutina.plan.sesiones.firstOrNull;
    setState(() {
      _rutina = rutina;
      if (primero != null && primero.dia.isNotEmpty) _dia = primero.dia;
      _cargando = false;
    });
  }

  Future<void> _cargarCatalogo() async {
    final res = await Future.wait([_repoEjercicios.listar(), _repoEjercicios.grupos()]);
    if (!mounted) return;
    final catalogo = (res[0] as List<EjercicioCatalogo>?) ?? [];
    // Solo los grupos que tienen ejercicios, más los que traiga el catálogo.
    final conEjercicios = {
      for (final e in catalogo)
        if ((e.grupoMuscular ?? '').trim().isNotEmpty) e.grupoMuscular!.trim(),
    };
    final grupos = [
      for (final g in res[1] as List<String>)
        if (conEjercicios.any((c) => _normalizar(c) == _normalizar(g))) g,
    ];
    for (final c in conEjercicios) {
      if (!grupos.any((g) => _normalizar(g) == _normalizar(c))) grupos.add(c);
    }
    setState(() {
      _catalogo = catalogo;
      _grupos = grupos;
    });
  }

  /// "Glúteo " -> "gluteo" para comparar sin tildes ni mayúsculas.
  static String _normalizar(String t) {
    const con = 'áéíóúüñ';
    const sin = 'aeiouun';
    final b = StringBuffer();
    for (final c in t.toLowerCase().trim().split('')) {
      final i = con.indexOf(c);
      b.write(i == -1 ? c : sin[i]);
    }
    return b.toString();
  }

  void _volcarDatos() {
    _rutina.nombre = _nombreCtrl.text.trim();
    _rutina.descripcion = _descripcionCtrl.text.trim();
    final obj = _objetivoCtrl.text.trim();
    _rutina.objetivo = obj.isEmpty ? null : obj;
  }

  // ------------------------------------------------------------ Bloques
  void _agregarBloque(String tipo) {
    final m = Metodologia.de(tipo);
    final bloque = DiaAdmin.nuevo(_dia, tipo)
      ..ejercicios.add(EjercicioAdmin(nombre: '')..completarPara(m));
    setState(() => _insertarAlFinalDelDia(bloque));
  }

  /// Lo pone después del último bloque de su día (al guardar se ordena la
  /// semana; dentro del día manda este orden).
  void _insertarAlFinalDelDia(DiaAdmin bloque) {
    final ultimo = _rutina.dias.lastIndexWhere((d) => d.diaSemana == bloque.diaSemana);
    _rutina.dias.insert(ultimo == -1 ? _rutina.dias.length : ultimo + 1, bloque);
  }

  void _moverBloque(DiaAdmin bloque, int delta) {
    final delDia = _bloquesDelDia;
    final j = delDia.indexOf(bloque) + delta;
    if (j < 0 || j >= delDia.length) return;
    final otro = delDia[j];
    final a = _rutina.dias.indexOf(bloque);
    final b = _rutina.dias.indexOf(otro);
    setState(() {
      _rutina.dias[a] = otro;
      _rutina.dias[b] = bloque;
    });
  }

  void _moverADia(DiaAdmin bloque, String dia) {
    if (dia == bloque.diaSemana) return;
    setState(() {
      _rutina.dias.remove(bloque);
      bloque.diaSemana = dia;
      _insertarAlFinalDelDia(bloque);
      _dia = dia;
    });
  }

  void _duplicarDia(String destino) {
    setState(() {
      for (final b in _bloquesDelDia) {
        _insertarAlFinalDelDia(b.copia(dia: destino));
      }
      _dia = destino;
    });
    mostrarMensaje(context, '$_dia copiado', tipo: TipoMensaje.exito);
  }

  void _aplicarATodos(DiaAdmin b) {
    final (trabajo, descanso) = _rapido[b] ?? (30, 15);
    setState(() {
      for (final e in b.ejercicios) {
        if (trabajo > 0) e.trabajoSeg = trabajo;
        if (b.metodologia.usa(CampoMetodologia.descanso)) {
          e.descansoSeg = descanso > 0 ? descanso : null;
        }
      }
      _version++;
    });
  }

  Future<void> _guardar() async {
    _volcarDatos();
    if (_rutina.nombre.isEmpty) {
      mostrarMensaje(context, 'El nombre de la rutina es obligatorio', tipo: TipoMensaje.advertencia);
      return;
    }
    // Como en el web: las filas sin nombre y los bloques vacíos no se guardan.
    for (final d in _rutina.dias) {
      d.ejercicios.removeWhere((e) => e.nombre.trim().isEmpty);
    }
    _rutina.dias.removeWhere((d) => d.ejercicios.isEmpty);
    if (_rutina.dias.isEmpty) {
      setState(() {});
      mostrarMensaje(context, 'Agrega al menos un ejercicio con nombre', tipo: TipoMensaje.advertencia);
      return;
    }
    final error = MotorRutina.validar(_rutina.plan);
    if (error != null) {
      setState(() {});
      mostrarMensaje(context, error, tipo: TipoMensaje.advertencia);
      return;
    }

    setState(() => _guardando = true);
    final err = await widget.fuente.guardar(_rutina);
    if (!mounted) return;
    setState(() => _guardando = false);
    if (err == null) {
      mostrarMensaje(context, 'Rutina guardada correctamente', tipo: TipoMensaje.exito);
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

  // ------------------------------------------------- Elegir un ejercicio
  /// Busca en el catálogo (acotado al grupo de la fila) o deja escribir el
  /// nombre a mano; también permite crear uno nuevo con fotos.
  Future<void> _elegirEjercicio(DiaAdmin b, EjercicioAdmin e) async {
    final grupo = _grupoDe(e);
    final elegido = await showModalBottomSheet<_Elegido>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColores.superficie,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => _HojaElegirEjercicio(
        catalogo: grupo == null
            ? _catalogo
            : _catalogo.where((x) => _normalizar(x.grupoMuscular ?? '') == _normalizar(grupo)).toList(),
        grupo: grupo,
        inicial: e.nombre,
      ),
    );
    if (elegido == null || !mounted) return;
    if (elegido.crearNuevo) {
      final nuevo = await mostrarHojaAgregarEjercicio(context);
      if (nuevo == null || !mounted) return;
      setState(() {
        e
          ..nombre = nuevo.nombre
          ..catalogoId = nuevo.catalogoId
          ..imagenUrl = nuevo.imagenUrl
          ..videoUrl = nuevo.videoUrl;
      });
      _cargarCatalogo();
      return;
    }
    setState(() {
      e.nombre = elegido.nombre;
      final c = elegido.catalogo;
      e.catalogoId = c?.id;
      e.imagenUrl = c?.imagenUrl;
      e.videoUrl = c?.videoUrl;
    });
  }

  /// Grupo de la fila: el elegido o, si no, el del ejercicio del catálogo.
  String? _grupoDe(EjercicioAdmin e) {
    if (_grupoFila.containsKey(e)) return _grupoFila[e];
    if (e.catalogoId == null) return null;
    final c = _catalogo.where((x) => x.id == e.catalogoId).firstOrNull;
    final g = c?.grupoMuscular;
    if (g == null) return null;
    return _grupos.where((x) => _normalizar(x) == _normalizar(g)).firstOrNull;
  }

  int _cantidadEnGrupo(String g) =>
      _catalogo.where((x) => _normalizar(x.grupoMuscular ?? '') == _normalizar(g)).length;

  // ----------------------------------------------------------------- UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      bottomNavigationBar: _cargando
          ? null
          : PieBoton(
              texto: 'Guardar rutina',
              icono: Icons.save_outlined,
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
                    subtitulo: widget.fuente.descripcion,
                    acciones: [
                      IconButton(
                        tooltip: 'Vista previa',
                        icon: const Icon(Icons.visibility_outlined),
                        onPressed: _rutina.dias.isEmpty ? null : _vistaPrevia,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppEspaciado.md),
                  _resumen(),
                  const SizedBox(height: AppEspaciado.md),
                  _seccion(
                    Icons.assignment_outlined,
                    'Datos de la rutina',
                    child: _datos(),
                  ),
                  const SizedBox(height: AppEspaciado.md),
                  _seccion(
                    Icons.calendar_view_week_rounded,
                    'Semana de entrenamiento',
                    sub: 'Elige un día y arma su sesión con uno o varios bloques.',
                    child: _semana(),
                  ),
                  const SizedBox(height: AppEspaciado.md),
                  for (final b in _bloquesDelDia) ...[
                    _tarjetaBloque(b),
                    const SizedBox(height: AppEspaciado.md),
                  ],
                  _seccion(
                    Icons.add_rounded,
                    '${_bloquesDelDia.isEmpty ? 'Agregar el primer bloque del' : 'Agregar otro bloque al'} ${_dia.toLowerCase()}',
                    child: _tipos(),
                  ),
                  const SizedBox(height: AppEspaciado.lg),
                ],
              ),
      ),
    );
  }

  // ------------------------------------------------------- Piezas comunes
  Widget _seccion(IconData icono, String titulo, {String? sub, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColores.primario.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icono, size: 17, color: AppColores.primario),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.primario,
                  ),
                ),
              ),
            ],
          ),
          if (sub != null) ...[
            const SizedBox(height: 6),
            Text(sub, style: const TextStyle(fontSize: 12.5, color: AppColores.textoSecundario)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _etiqueta(String texto) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Text(
      texto.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.3,
        color: AppColores.textoSecundario,
      ),
    ),
  );

  /// Campo relleno, sin borde: el mismo estilo de los campos del web.
  InputDecoration _decoracion({String? hint, String? prefijo, String? sufijo, IconData? icono}) {
    final borde = OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: BorderSide.none,
    );
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: AppColores.fondo,
      hintText: hint,
      hintStyle: const TextStyle(color: AppColores.textoSecundario, fontSize: 14),
      prefixText: prefijo,
      suffixText: sufijo,
      suffixStyle: const TextStyle(fontSize: 12, color: AppColores.textoSecundario),
      prefixIcon: icono == null ? null : Icon(icono, size: 18, color: AppColores.textoSecundario),
      prefixIconConstraints: const BoxConstraints(minWidth: 36),
      contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 11),
      border: borde,
      enabledBorder: borde,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: AppColores.primario, width: 1.4),
      ),
    );
  }

  int? _ent(String v) {
    final n = int.tryParse(v);
    return n == null || n <= 0 ? null : n;
  }

  /// Campo numérico chico con su etiqueta arriba (series, reps, tiempos...).
  Widget _numero(
    Object dueno,
    String campo,
    String etiqueta,
    num? valor,
    ValueChanged<String> onChanged, {
    String? sufijo,
    String? prefijo,
    double ancho = 78,
    bool decimal = false,
  }) {
    return SizedBox(
      width: ancho,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _etiqueta(etiqueta),
          TextFormField(
            key: ValueKey('${identityHashCode(dueno)}-$campo-$_version'),
            initialValue: valor == null || valor == 0 ? '' : PlanEjercicio.formatoKg(valor.toDouble()),
            keyboardType: TextInputType.numberWithOptions(decimal: decimal),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(decimal ? r'[0-9.]' : r'[0-9]')),
            ],
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            decoration: _decoracion(hint: '—', sufijo: sufijo, prefijo: prefijo),
            onChanged: (v) {
              onChanged(v);
              setState(() {});
            },
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------- Resumen
  Widget _resumen() {
    final plan = _rutina.plan;
    final m = plan.metodologia;
    final duracion = MotorRutina.duracionEstimada(plan);
    final dias = plan.sesiones.length;
    final ejercicios = _rutina.dias.fold<int>(
      0,
      (s, b) => s + b.ejercicios.where((e) => e.nombre.trim().isNotEmpty).length,
    );
    Widget cifra(int n, String texto) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              '$n',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            Text(texto, style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.75))),
          ],
        ),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(8, 3, 10, 3),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(m.icono, size: 14, color: Colors.white),
                const SizedBox(width: 5),
                Text(
                  m.texto,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            duracion > 0 ? formatoDuracion(duracion) : '—',
            style: const TextStyle(
              fontSize: 32,
              height: 1.1,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          Text(
            'duración estimada del día más largo',
            style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              cifra(dias, dias == 1 ? 'día' : 'días'),
              const SizedBox(width: 8),
              cifra(_rutina.dias.length, _rutina.dias.length == 1 ? 'bloque' : 'bloques'),
              const SizedBox(width: 8),
              cifra(ejercicios, ejercicios == 1 ? 'ejercicio' : 'ejercicios'),
            ],
          ),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Datos
  Widget _datos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _etiqueta('Nombre de la rutina *'),
        TextField(
          controller: _nombreCtrl,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(fontWeight: FontWeight.w600),
          decoration: _decoracion(hint: 'Ej. Semana quema grasa'),
        ),
        const SizedBox(height: 12),
        _etiqueta('Nivel'),
        _niveles(),
        const SizedBox(height: 12),
        _etiqueta('Objetivo'),
        TextField(
          controller: _objetivoCtrl,
          textCapitalization: TextCapitalization.sentences,
          decoration: _decoracion(hint: 'Ej. Resistencia, fuerza, bajar de peso', icono: Icons.track_changes_rounded),
        ),
        const SizedBox(height: 12),
        _etiqueta('Descripción'),
        TextField(
          controller: _descripcionCtrl,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 2,
          minLines: 1,
          decoration: _decoracion(hint: 'Opcional'),
        ),
      ],
    );
  }

  /// Principiante / Intermedio / Avanzado; tocar el elegido lo quita.
  Widget _niveles() {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          for (final n in nivelesRutina.entries)
            Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _rutina.nivel = _rutina.nivel == n.key ? null : n.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _rutina.nivel == n.key ? AppColores.superficie : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: _rutina.nivel == n.key
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                        : null,
                  ),
                  child: Text(
                    n.value,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _rutina.nivel == n.key ? AppColores.primario : AppColores.textoSecundario,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Semana
  Widget _semana() {
    final sesiones = {for (final s in _rutina.plan.sesiones) s.dia: s};
    final delDia = _bloquesDelDia;
    final sesion = sesiones[_dia];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            for (final d in diasSemana) ...[
              Expanded(child: _chipDia(d, sesiones[d]?.duracion ?? 0)),
              if (d != diasSemana.last) const SizedBox(width: 4),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Divider(height: 1, color: AppColores.borde),
        const SizedBox(height: 12),
        // Barra del día elegido.
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 6,
          children: [
            Text(
              _dia,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColores.primario),
            ),
            Text(
              sesion == null
                  ? 'Día de descanso: agrega un bloque abajo'
                  : '${delDia.length} ${delDia.length == 1 ? 'bloque' : 'bloques'} · ~${formatoDuracion(sesion.duracion)}',
              style: const TextStyle(fontSize: 13, color: AppColores.textoSecundario),
            ),
          ],
        ),
        if (delDia.isNotEmpty) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: PopupMenuButton<String>(
                  onSelected: _duplicarDia,
                  itemBuilder: (_) => [
                    for (final d in diasSemana.where((x) => x != _dia))
                      PopupMenuItem(value: d, child: Text(d)),
                  ],
                  child: _botonSuave(Icons.copy_all_rounded, 'Duplicar en…', AppColores.primario),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _rutina.dias.removeWhere((b) => b.diaSemana == _dia)),
                  child: _botonSuave(Icons.event_busy_rounded, 'Dejar de descanso', AppColores.error),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _botonSuave(IconData icono, String texto, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 15, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              texto,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// "1h38" o "26m": cabe en la tira de días del teléfono.
  static String _corto(int seg) {
    if (seg <= 0) return '';
    final min = (seg / 60).round();
    if (min < 60) return '${min}m';
    final m = min % 60;
    return '${min ~/ 60}h${m == 0 ? '' : m.toString().padLeft(2, '0')}';
  }

  Widget _chipDia(String d, int duracion) {
    final bloques = _rutina.dias.where((b) => b.diaSemana == d).toList();
    final activo = d == _dia;
    final vacio = bloques.isEmpty;
    final colorTexto = activo
        ? AppColores.sobreRelleno
        : vacio
        ? AppColores.textoSecundario
        : AppColores.primario;
    return GestureDetector(
      onTap: () => setState(() => _dia = d),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: activo ? AppColores.degradadoRelleno : null,
          color: activo ? null : (vacio ? AppColores.fondo : AppColores.superficie),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: activo ? Colors.transparent : AppColores.borde),
        ),
        child: Column(
          children: [
            Text(
              d.substring(0, 3),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: colorTexto),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 14,
              child: vacio
                  ? Icon(Icons.bedtime_outlined, size: 12, color: colorTexto.withValues(alpha: 0.6))
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (final b in bloques.take(3))
                          Icon(
                            b.metodologia.icono,
                            size: 12,
                            color: activo ? AppColores.sobreRelleno : b.metodologia.color,
                          ),
                      ],
                    ),
            ),
            const SizedBox(height: 2),
            Text(
              vacio ? 'Desc.' : _corto(duracion),
              style: TextStyle(fontSize: 10.5, color: colorTexto.withValues(alpha: 0.85)),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- Bloque
  Widget _tarjetaBloque(DiaAdmin b) {
    final m = b.metodologia;
    final delDia = _bloquesDelDia;
    final i = delDia.indexOf(b);
    final ultimo = i == delDia.length - 1;
    final duracion = MotorRutina.duracionBloque(b.plan);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(height: 4, color: m.color),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Número del bloque en el día y su duración.
                Row(
                  children: [
                    Text(
                      'BLOQUE ${i + 1}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.6,
                        color: m.color,
                      ),
                    ),
                    const Spacer(),
                    Icon(Icons.timer_outlined, size: 14, color: AppColores.primario),
                    const SizedBox(width: 3),
                    Text(
                      duracion > 0 ? '~${formatoDuracion(duracion)}' : '—',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColores.primario),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // Metodología y acciones.
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: m.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(m.icono, size: 18, color: m.color),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('${identityHashCode(b)}-tipo-$_version'),
                        initialValue: b.tipo,
                        isExpanded: true,
                        decoration: _decoracion(),
                        // Sobre el estilo del tema: el desplegable no lo hereda solo.
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: AppColores.primario,
                        ),
                        items: [
                          for (final t in Metodologia.todas)
                            DropdownMenuItem(
                              value: t.valor,
                              child: Row(
                                children: [
                                  Icon(t.icono, size: 16, color: t.color),
                                  const SizedBox(width: 8),
                                  Flexible(child: Text(t.texto, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                            ),
                        ],
                        onChanged: (t) {
                          if (t == null) return;
                          setState(() {
                            b.cambiarTipo(t);
                            _version++;
                          });
                        },
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert_rounded, color: AppColores.textoSecundario),
                      onSelected: (v) {
                        switch (v) {
                          case 'subir':
                            _moverBloque(b, -1);
                          case 'bajar':
                            _moverBloque(b, 1);
                          case 'duplicar':
                            setState(() {
                              final c = b.copia()..nombre = b.nombre == null ? null : '${b.nombre} (copia)';
                              _rutina.dias.insert(_rutina.dias.indexOf(b) + 1, c);
                            });
                          case 'quitar':
                            setState(() => _rutina.dias.remove(b));
                        }
                      },
                      itemBuilder: (_) => [
                        if (i > 0) const PopupMenuItem(value: 'subir', child: Text('Subir bloque')),
                        if (!ultimo) const PopupMenuItem(value: 'bajar', child: Text('Bajar bloque')),
                        const PopupMenuItem(value: 'duplicar', child: Text('Duplicar bloque')),
                        const PopupMenuItem(
                          value: 'quitar',
                          child: Text('Quitar bloque', style: TextStyle(color: AppColores.error)),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Nombre y día del bloque.
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        key: ValueKey('${identityHashCode(b)}-nombre'),
                        initialValue: b.nombre ?? '',
                        textCapitalization: TextCapitalization.sentences,
                        decoration: _decoracion(
                          hint: MotorRutina.nombreBloque(DiaAdmin.nuevo(b.diaSemana, b.tipo).plan, i),
                          icono: Icons.edit_outlined,
                        ),
                        onChanged: (v) => b.nombre = v.trim().isEmpty ? null : v.trim(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 128,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('${identityHashCode(b)}-dia-${b.diaSemana}'),
                        initialValue: b.diaSemana,
                        isExpanded: true,
                        decoration: _decoracion(icono: Icons.calendar_today_outlined),
                        items: [
                          for (final d in diasSemana) DropdownMenuItem(value: d, child: Text(d)),
                        ],
                        onChanged: (d) {
                          if (d != null) _moverADia(b, d);
                        },
                      ),
                    ),
                  ],
                ),
                // Reglas de la metodología.
                if (!m.esSeries || !ultimo) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      if (m.usa(CampoMetodologia.rondas))
                        _numero(b, 'rondas', m.etiquetaRondas, b.rondas, (v) => b.rondas = _ent(v) ?? 1, ancho: 96),
                      if (m.usa(CampoMetodologia.descansoRonda))
                        _numero(b, 'dr', 'Desc. entre rondas', b.descansoRondaSeg,
                            (v) => b.descansoRondaSeg = _ent(v), sufijo: 's', ancho: 120),
                      if (m.usa(CampoMetodologia.tiempoLimite))
                        _numero(b, 'tl', 'Tiempo límite', b.tiempoLimiteSeg == null ? null : b.tiempoLimiteSeg! ~/ 60,
                            (v) => b.tiempoLimiteSeg = _ent(v) == null ? null : _ent(v)! * 60, sufijo: 'min', ancho: 110),
                      if (m.usa(CampoMetodologia.intervalo))
                        _numero(b, 'int', 'Intervalo', b.intervaloSeg, (v) => b.intervaloSeg = _ent(v), sufijo: 's', ancho: 96),
                      if (!ultimo)
                        _numero(b, 'db', 'Desc. al terminar', b.descansoBloqueSeg,
                            (v) => b.descansoBloqueSeg = _ent(v), sufijo: 's', ancho: 120),
                    ],
                  ),
                ],
                if (m.usa(CampoMetodologia.trabajo)) ...[
                  const SizedBox(height: 10),
                  _aplicarATodosBarra(b),
                ],
                const SizedBox(height: 12),
                for (var k = 0; k < b.ejercicios.length; k++) ...[
                  _filaEjercicio(b, k),
                  const SizedBox(height: 8),
                ],
                if (b.ejercicios.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Center(
                      child: Text('Sin ejercicios. Agrega uno abajo.', style: TextStyle(color: AppColores.textoSecundario)),
                    ),
                  ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    side: BorderSide(color: AppColores.borde, width: 1.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => setState(() => b.ejercicios.add(EjercicioAdmin(nombre: '')..completarPara(m))),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text('Agregar ${m.etiquetaEjercicio.toLowerCase()}'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Trabajo y descanso iguales para todos los ejercicios del bloque.
  Widget _aplicarATodosBarra(DiaAdmin b) {
    final (trabajo, descanso) = _rapido[b] ?? (30, 15);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.end,
        spacing: 8,
        runSpacing: 6,
        children: [
          _numero(b, 'rt', 'Trabajo', trabajo, (v) => _rapido[b] = (_ent(v) ?? 0, descanso), sufijo: 's', ancho: 84),
          if (b.metodologia.usa(CampoMetodologia.descanso))
            _numero(b, 'rd', 'Descanso', descanso, (v) => _rapido[b] = (trabajo, _ent(v) ?? 0), sufijo: 's', ancho: 84),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => _aplicarATodos(b),
            icon: const Icon(Icons.flash_on_rounded, size: 16),
            label: const Text('Aplicar a todos'),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Ejercicio
  Widget _filaEjercicio(DiaAdmin b, int k) {
    final m = b.metodologia;
    final e = b.ejercicios[k];
    final grupo = _grupoDe(e);
    final ultimoDelCircuito = !m.esSeries && k == b.ejercicios.length - 1 && (b.descansoRondaSeg ?? 0) > 0;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppColores.fondo.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              SizedBox(
                width: 18,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    '${k + 1}',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w800, color: m.color),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _miniatura(e.imagenUrl),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Grupo muscular'),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('${identityHashCode(e)}-grupo-${grupo ?? ''}-${_grupos.length}'),
                      initialValue: _grupos.contains(grupo) ? grupo : null,
                      isExpanded: true,
                      decoration: _decoracion(),
                      hint: const Text('Todos', style: TextStyle(fontSize: 14)),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('Todos')),
                        for (final g in _grupos)
                          DropdownMenuItem<String?>(
                            value: g,
                            child: Row(
                              children: [
                                Expanded(child: Text(g, overflow: TextOverflow.ellipsis)),
                                Text(
                                  '${_cantidadEnGrupo(g)}',
                                  style: const TextStyle(fontSize: 11, color: AppColores.textoSecundario),
                                ),
                              ],
                            ),
                          ),
                      ],
                      selectedItemBuilder: (_) => [
                        const Text('Todos'),
                        for (final g in _grupos) Text(g, overflow: TextOverflow.ellipsis),
                      ],
                      onChanged: (g) => setState(() => _grupoFila[e] = g),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert_rounded, size: 20, color: AppColores.textoSecundario),
                onSelected: (v) => setState(() {
                  switch (v) {
                    case 'subir':
                      b.ejercicios.insert(k - 1, b.ejercicios.removeAt(k));
                    case 'bajar':
                      b.ejercicios.insert(k + 1, b.ejercicios.removeAt(k));
                    case 'duplicar':
                      b.ejercicios.insert(k + 1, e.copia());
                    case 'quitar':
                      b.ejercicios.removeAt(k);
                  }
                }),
                itemBuilder: (_) => [
                  if (k > 0) const PopupMenuItem(value: 'subir', child: Text('Subir')),
                  if (k < b.ejercicios.length - 1) const PopupMenuItem(value: 'bajar', child: Text('Bajar')),
                  const PopupMenuItem(value: 'duplicar', child: Text('Duplicar')),
                  const PopupMenuItem(value: 'quitar', child: Text('Quitar', style: TextStyle(color: AppColores.error))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          _etiqueta(m.etiquetaEjercicio),
          InkWell(
            onTap: () => _elegirEjercicio(b, e),
            borderRadius: BorderRadius.circular(10),
            child: InputDecorator(
              decoration: _decoracion(icono: Icons.search_rounded),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      e.nombre.isEmpty ? (grupo == null ? 'Buscar o escribir' : 'Buscar en $grupo') : e.nombre,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: e.nombre.isEmpty ? FontWeight.w400 : FontWeight.w600,
                        color: e.nombre.isEmpty ? AppColores.textoSecundario : AppColores.textoPrincipal,
                      ),
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down_rounded, color: AppColores.textoSecundario),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (m.usa(CampoMetodologia.series))
                _numero(e, 'series', 'Series', e.series, (v) => e.series = _ent(v) ?? 0, ancho: 70),
              if (m.usa(CampoMetodologia.trabajo))
                _numero(e, 'trabajo', 'Trabajo', e.trabajoSeg, (v) => e.trabajoSeg = _ent(v), sufijo: 's', ancho: 80),
              if (m.usa(CampoMetodologia.repeticiones))
                _numero(e, 'reps', 'Reps', e.repeticiones, (v) => e.repeticiones = _ent(v) ?? 0, ancho: 70),
              if (m.usa(CampoMetodologia.peso))
                _numero(e, 'peso', 'Peso', e.pesoKg, (v) {
                  final p = double.tryParse(v);
                  e.pesoKg = p == null || p <= 0 ? null : p;
                }, sufijo: 'kg', ancho: 84, decimal: true),
              if (m.usa(CampoMetodologia.descanso))
                Opacity(
                  opacity: ultimoDelCircuito ? 0.45 : 1,
                  child: _numero(
                    e,
                    'descanso',
                    // La unidad ya va como sufijo: "Descanso entre series (s)" -> "Descanso".
                    m.etiquetaDescanso.replaceAll(RegExp(r'\s*\(s(eg)?\)'), '').replaceAll(' entre series', ''),
                    e.descansoSeg,
                    (v) => e.descansoSeg = _ent(v),
                    sufijo: 's',
                    ancho: 92,
                  ),
                ),
              // Tempo de cada repetición: segundos al bajar y al subir.
              if (m.usa(CampoMetodologia.repeticiones))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Tempo'),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _numeroSinEtiqueta(e, 'baja', e.tempoBajadaSeg, (v) => e.tempoBajadaSeg = _ent(v), '↓ '),
                        const SizedBox(width: 4),
                        _numeroSinEtiqueta(e, 'sube', e.tempoSubidaSeg, (v) => e.tempoSubidaSeg = _ent(v), '↑ '),
                      ],
                    ),
                  ],
                ),
              SizedBox(
                width: 132,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _etiqueta('Velocidad'),
                    DropdownButtonFormField<String?>(
                      key: ValueKey('${identityHashCode(e)}-vel-$_version'),
                      initialValue: e.velocidad,
                      isExpanded: true,
                      decoration: _decoracion(),
                      hint: const Text('—'),
                      items: [
                        const DropdownMenuItem<String?>(value: null, child: Text('—')),
                        for (final v in Velocidad.valores)
                          DropdownMenuItem<String?>(value: v, child: Text(Velocidad.texto(v))),
                      ],
                      onChanged: (v) => setState(() => e.velocidad = v),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _etiqueta('Observaciones'),
          TextFormField(
            key: ValueKey('${identityHashCode(e)}-obs'),
            initialValue: e.observaciones ?? '',
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracion(hint: 'Opcional'),
            onChanged: (v) => e.observaciones = v.trim().isEmpty ? null : v.trim(),
          ),
        ],
      ),
    );
  }

  Widget _numeroSinEtiqueta(Object dueno, String campo, int? valor, ValueChanged<String> onChanged, String prefijo) {
    return SizedBox(
      width: 74,
      child: TextFormField(
        key: ValueKey('${identityHashCode(dueno)}-$campo-$_version'),
        initialValue: valor == null || valor == 0 ? '' : '$valor',
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        decoration: _decoracion(hint: '—', prefijo: prefijo, sufijo: 's'),
        onChanged: (v) {
          onChanged(v);
          setState(() {});
        },
      ),
    );
  }

  Widget _miniatura(String? url) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: AppColores.primario.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null
          ? Icon(Icons.fitness_center_rounded, size: 18, color: AppColores.primario.withValues(alpha: 0.5))
          : Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(Icons.fitness_center_rounded, size: 18, color: AppColores.primario.withValues(alpha: 0.5)),
            ),
    );
  }

  // ------------------------------------------------------- Agregar bloque
  Widget _tipos() {
    return LayoutBuilder(
      builder: (_, restr) {
        final ancho = (restr.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final t in Metodologia.todas)
              SizedBox(
                width: ancho,
                child: InkWell(
                  onTap: () => _agregarBloque(t.valor),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: AppColores.superficie,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColores.borde),
                    ),
                    child: IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(width: 4, color: t.color),
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: t.color.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Icon(t.icono, size: 16, color: t.color),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          t.texto,
                                          style: TextStyle(
                                            fontSize: 13.5,
                                            fontWeight: FontWeight.w700,
                                            color: AppColores.primario,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    t.ayuda,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 11.5, height: 1.3, color: AppColores.textoSecundario),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Lo que se elige en la hoja de ejercicios.
class _Elegido {
  final String nombre;
  final EjercicioCatalogo? catalogo;
  final bool crearNuevo;

  const _Elegido(this.nombre, {this.catalogo, this.crearNuevo = false});
}

/// Hoja para elegir un ejercicio del catálogo (ya filtrado por el grupo de la
/// fila) o escribir uno a mano.
class _HojaElegirEjercicio extends StatefulWidget {
  final List<EjercicioCatalogo> catalogo;
  final String? grupo;
  final String inicial;

  const _HojaElegirEjercicio({required this.catalogo, this.grupo, required this.inicial});

  @override
  State<_HojaElegirEjercicio> createState() => _HojaElegirEjercicioState();
}

class _HojaElegirEjercicioState extends State<_HojaElegirEjercicio> {
  late final _ctrl = TextEditingController(text: widget.inicial);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _ctrl.text.trim().toLowerCase();
    final lista = q.isEmpty
        ? widget.catalogo
        : widget.catalogo.where((e) => e.nombre.toLowerCase().contains(q)).toList();
    final exacto = widget.catalogo.any((e) => e.nombre.toLowerCase() == q);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  widget.grupo == null ? 'Elegir ejercicio' : 'Ejercicios de ${widget.grupo}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColores.textoPrincipal),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _ctrl,
                  autofocus: widget.inicial.isEmpty,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    isDense: true,
                    filled: true,
                    fillColor: AppColores.fondo,
                    hintText: 'Buscar o escribir el nombre',
                    prefixIcon: const Icon(Icons.search_rounded),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                  ),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  children: [
                    if (q.isNotEmpty && !exacto)
                      ListTile(
                        leading: const Icon(Icons.edit_rounded),
                        title: Text('Usar "${_ctrl.text.trim()}"'),
                        subtitle: const Text('Sin imágenes del catálogo'),
                        onTap: () => Navigator.pop(context, _Elegido(_ctrl.text.trim())),
                      ),
                    ListTile(
                      leading: Icon(Icons.add_a_photo_outlined, color: AppColores.primario),
                      title: Text(
                        'Crear ejercicio con fotos',
                        style: TextStyle(fontWeight: FontWeight.w700, color: AppColores.primario),
                      ),
                      onTap: () => Navigator.pop(context, const _Elegido('', crearNuevo: true)),
                    ),
                    const Divider(height: 1),
                    for (final e in lista)
                      ListTile(
                        leading: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: SizedBox(
                            width: 44,
                            height: 44,
                            child: e.imagenUrl == null
                                ? Container(
                                    color: AppColores.fondo,
                                    child: const Icon(Icons.fitness_center_rounded, size: 18),
                                  )
                                : Image.network(
                                    e.imagenUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, _, _) => const Icon(Icons.fitness_center_rounded, size: 18),
                                  ),
                          ),
                        ),
                        title: Text(e.nombre, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: e.grupoMuscular == null ? null : Text(e.grupoMuscular!),
                        onTap: () => Navigator.pop(context, _Elegido(e.nombre, catalogo: e)),
                      ),
                    if (lista.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(
                          child: Text('Sin coincidencias en el catálogo', style: TextStyle(color: AppColores.textoSecundario)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
