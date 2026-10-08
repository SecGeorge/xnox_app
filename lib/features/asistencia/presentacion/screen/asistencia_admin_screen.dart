import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/asistencia/datos/repositorio_asistencia.dart';
import 'package:xnox_app/features/asistencia/presentacion/screen/escaner_qr_screen.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';
import 'package:xnox_app/features/pagos/presentacion/widget/grafico_barra.dart';

/// Registro de asistencia desde el móvil (solo personal del gimnasio): la
/// versión de bolsillo del "Registro rápido" del panel web (`Asistencia.vue`).
/// Se marca la entrada escaneando el pase del socio o escribiendo su DNI (o
/// buscándolo por nombre).
class AsistenciaAdminScreen extends StatefulWidget {
  const AsistenciaAdminScreen({super.key});

  @override
  State<AsistenciaAdminScreen> createState() => _AsistenciaAdminScreenState();
}

class _AsistenciaAdminScreenState extends State<AsistenciaAdminScreen> {
  final _repo = RepositorioAsistencia();
  final _codigo = TextEditingController();
  final _foco = FocusNode();

  List<Miembro> _miembros = const [];
  List<HorarioDia> _horario = const [];
  AsistenciasDia? _dia;
  ResultadoAsistencia? _ultimo;
  bool _cargando = true;
  bool _registrando = false;
  DateTime _fecha = _soloFecha(DateTime.now());

  static DateTime _soloFecha(DateTime d) => DateTime(d.year, d.month, d.day);

  bool get _esHoy => _fecha == _soloFecha(DateTime.now());

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _codigo.dispose();
    _foco.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    // Socios (fotos y búsqueda por nombre) y horario son secundarios.
    final socios = ControladorMiembros().buscarMiembros().catchError(
      (_) => <Miembro>[],
    );
    final horario = _repo.horario().catchError((_) => <HorarioDia>[]);
    try {
      final dia = await _repo.obtener(_fecha);
      final lista = await socios;
      final horas = await horario;
      if (!mounted) return;
      setState(() {
        _dia = dia;
        _miembros = lista;
        _horario = horas;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(
        context,
        'No se pudo cargar la asistencia',
        tipo: TipoMensaje.error,
      );
    }
  }

  Future<void> _recargarDia() async {
    try {
      final dia = await _repo.obtener(_fecha);
      if (mounted) setState(() => _dia = dia);
    } catch (_) {}
  }

  void _cambiarDia(int dias) {
    final nueva = _fecha.add(Duration(days: dias));
    if (nueva.isAfter(_soloFecha(DateTime.now()))) return;
    setState(() {
      _fecha = nueva;
      _dia = null;
    });
    _recargarDia();
  }

  // ---------------------------------------------------------------- Registro

  Future<void> _escanear() async {
    final leido = await Navigator.of(
      context,
    ).push<String>(MaterialPageRoute(builder: (_) => const EscanerQrScreen()));
    if (leido == null || !mounted) return;
    await _registrar(leido);
  }

  Future<void> _registrar([String? codigo]) async {
    final valor = (codigo ?? _codigo.text).trim();
    if (valor.isEmpty || _registrando) return;
    FocusScope.of(context).unfocus();
    setState(() => _registrando = true);
    final r = await _repo.registrar(valor);
    if (!mounted) return;
    if (r.ingreso) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.heavyImpact();
    }
    setState(() {
      _registrando = false;
      _ultimo = r;
      _codigo.clear();
    });
    mostrarMensaje(
      context,
      r.mensaje,
      tipo: r.exito == 1
          ? TipoMensaje.exito
          : r.exito == 2
          ? TipoMensaje.advertencia
          : TipoMensaje.error,
    );
    // La entrada nueva se ve en el gráfico y la lista de hoy.
    if (!_esHoy) _fecha = _soloFecha(DateTime.now());
    await _recargarDia();
  }

  /// Con letras en el campo, sugiere socios por nombre.
  List<Miembro> get _sugerencias {
    final t = _codigo.text.trim().toLowerCase();
    if (t.length < 2 || RegExp(r'^\d+$').hasMatch(t)) return const [];
    return _miembros
        .where((m) => m.nombre.toLowerCase().contains(t))
        .take(4)
        .toList();
  }

  // ------------------------------------------------------------------ Datos

  String? _urlFoto(String? ruta) {
    if (ruta == null || ruta.isEmpty || ruta.endsWith('usuario.png')) {
      return null;
    }
    if (ruta.startsWith('http')) return ruta;
    return Uri.parse(HttpService().rutaActual).resolve(ruta).toString();
  }

  String? _fotoDe(String codigo) {
    for (final m in _miembros) {
      if (m.documento == codigo) return m.imagen;
    }
    return null;
  }

  HorarioDia? get _horarioDia {
    for (final h in _horario) {
      if (h.diaSemana == _fecha.weekday) return h;
    }
    return null;
  }

  // ------------------------------------------------------------------ Vista

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: _cargar,
      children: [
        const CabeceraApp(
          titulo: 'Asistencia',
          subtitulo: 'Registra la entrada de tus socios',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        _portada(),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.how_to_reg_rounded,
          titulo: 'Registro rápido',
        ),
        _registro(),
        if (_ultimo != null) ...[
          const SizedBox(height: AppEspaciado.lg),
          const TituloSeccion(
            icono: Icons.person_pin_rounded,
            titulo: 'Último ingreso',
          ),
          _tarjetaUltimo(_ultimo!),
        ],
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.bar_chart_rounded,
          titulo: 'Horas de ingreso',
        ),
        _selectorFecha(),
        const SizedBox(height: AppEspaciado.sm + 4),
        _grafico(),
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.format_list_bulleted_rounded,
          titulo: _esHoy ? 'Entradas de hoy' : 'Entradas del día',
          detalle: _dia == null ? null : '${_dia!.entradas.length}',
        ),
        ..._listaEntradas(),
      ],
    );
  }

  Widget _portada() {
    final h = _horarioDia;
    final abierto = _esHoy && (h?.abiertoA(DateTime.now()) ?? false);
    final entradas = _dia?.entradas.length ?? 0;
    final activos = _dia?.miembrosActivos ?? 0;
    return PortadaFoto(
      foto: FotosApp.inicio,
      altura: 175,
      etiqueta: _esHoy
          ? 'En el gimnasio hoy'
          : 'Asistencias del ${DateFormat("d 'de' MMMM", 'es').format(_fecha)}',
      titulo: _cargando && _dia == null
          ? '…'
          : '$entradas ${entradas == 1 ? 'socio' : 'socios'}',
      texto: activos > 0 ? 'de $activos miembros activos' : null,
      pie: Row(
        children: [
          // Día sin atención: un solo dato, no "Cerrado" dos veces.
          if (h != null && !h.abierto)
            DatoPortada(
              icono: Icons.event_busy_rounded,
              valor: 'Cerrado',
              pie: _esHoy ? 'hoy no se atiende' : 'ese día no se atiende',
            )
          else ...[
            DatoPortada(
              icono: Icons.schedule_rounded,
              valor: h?.texto ?? '—',
              pie: 'horario',
            ),
            if (_esHoy && h != null) ...[
              const SizedBox(width: 18),
              DatoPortada(
                icono: abierto
                    ? Icons.lock_open_rounded
                    : Icons.lock_outline_rounded,
                valor: abierto ? 'Abierto' : 'Cerrado',
                pie: 'ahora',
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _registro() {
    final radio = BorderRadius.circular(AppEspaciado.radio + 4);
    final sugerencias = _sugerencias;
    return TarjetaPlana(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Escanear: la acción principal en el mostrador.
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: radio,
              onTap: _registrando ? null : _escanear,
              child: Ink(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: AppColores.degradadoRelleno,
                  border: AppColores.bordeCabecera,
                  borderRadius: radio,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColores.sobreRelleno.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        Icons.qr_code_scanner_rounded,
                        size: 28,
                        color: AppColores.sobreRelleno,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Escanear QR',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColores.sobreRelleno,
                            ),
                          ),
                          Text(
                            'El pase de la app del socio',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColores.sobreRellenoSuave,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      color: AppColores.sobreRelleno,
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: AppColores.borde)),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Text(
                  'o escribe su DNI',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ),
              Expanded(child: Divider(color: AppColores.borde)),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _codigo,
            focusNode: _foco,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _registrar(),
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
            ),
            decoration: InputDecoration(
              hintText: 'DNI o nombre del socio',
              hintStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                letterSpacing: 0,
              ),
              prefixIcon: const Icon(Icons.badge_outlined),
              suffixIcon: _codigo.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => setState(_codigo.clear),
                    ),
              filled: true,
              fillColor: AppColores.fondo,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppEspaciado.radio),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          for (final m in sugerencias)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                color: AppColores.fondo,
                borderRadius: BorderRadius.circular(AppEspaciado.radio),
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppEspaciado.radio),
                  onTap: () => _registrar(m.documento),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Row(
                      children: [
                        _avatar(m.imagen, m.nombre, tamano: 38),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                m.nombre,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColores.textoPrincipal,
                                ),
                              ),
                              Text(
                                'DNI ${m.documento} · ${m.plan}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.textoSecundario,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.login_rounded,
                          size: 20,
                          color: AppColores.primario,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton.icon(
              onPressed: _registrando || _codigo.text.trim().isEmpty
                  ? null
                  : () => _registrar(),
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppEspaciado.radio),
                ),
              ),
              icon: _registrando
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColores.sobreRelleno,
                      ),
                    )
                  : const Icon(Icons.login_rounded),
              label: const Text('Registrar entrada'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _avatar(String? ruta, String nombre, {double tamano = 46}) {
    final url = _urlFoto(ruta);
    final inicial = Text(
      Miembro.inicialesDe(nombre),
      style: TextStyle(
        fontSize: tamano * 0.34,
        fontWeight: FontWeight.w800,
        color: AppColores.sobreRelleno,
      ),
    );
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? inicial
          : Image.network(
              url,
              width: tamano,
              height: tamano,
              fit: BoxFit.cover,
              cacheWidth: 240,
              errorBuilder: (_, _, _) => inicial,
            ),
    );
  }

  /// Quién acaba de marcar: foto, estado, plan y días que le quedan.
  Widget _tarjetaUltimo(ResultadoAsistencia r) {
    final color = r.exito == 1
        ? AppColores.exito
        : r.exito == 2
        ? AppColores.naranja
        : AppColores.moroso;
    final estado = r.exito == 1
        ? 'Ingresó'
        : r.exito == 2
        ? 'Ingresó con aviso'
        : 'No ingresó';
    final dias = r.diasRestantes;
    final nombre = r.nombre.isEmpty ? 'Código ${r.codigo}' : r.nombre;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 6),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.4),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withValues(alpha: 0.12), AppColores.superficie],
              ),
            ),
            child: Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: color, width: 2.5),
                      ),
                      child: _avatar(
                        r.imagen.isNotEmpty ? r.imagen : _fotoDe(r.codigo),
                        nombre,
                        tamano: 62,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColores.superficie,
                            width: 2,
                          ),
                        ),
                        child: Icon(
                          r.ingreso ? Icons.check_rounded : Icons.close_rounded,
                          size: 14,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _pildora(estado, color, solido: true),
                          const Spacer(),
                          Text(
                            DateFormat('HH:mm').format(r.hora),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        nombre,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          height: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          if (r.codigo.isNotEmpty)
                            _pildora(
                              'DNI ${r.codigo}',
                              AppColores.textoSecundario,
                            ),
                          if (r.membresia.isNotEmpty)
                            _pildora(r.membresia, AppColores.primario),
                          if (r.fechaFin != null)
                            _pildora(
                              '${(dias ?? 0) < 0 ? 'Venció' : 'Vence'} '
                              '${DateFormat('d MMM', 'es').format(r.fechaFin!)}',
                              AppColores.textoSecundario,
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        r.mensaje,
                        style: const TextStyle(
                          fontSize: 12.5,
                          height: 1.35,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                if (dias != null) ...[
                  const SizedBox(width: 12),
                  _cajaDias(dias, r.visitasRestantes),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _cajaDias(int dias, int? visitas) {
    final color = dias < 0
        ? AppColores.moroso
        : dias <= 3
        ? AppColores.moroso
        : dias <= 7
        ? AppColores.naranja
        : AppColores.exito;
    final texto = dias < 0
        ? 'días vencido'
        : dias == 0
        ? 'vence hoy'
        : dias == 1
        ? 'día queda'
        : 'días quedan';
    return Container(
      width: 84,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
      ),
      child: Column(
        children: [
          Text(
            '${dias.abs()}',
            style: TextStyle(
              fontSize: 28,
              height: 1,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            texto.toUpperCase(),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 9.5,
              letterSpacing: 0.4,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          if (visitas != null) ...[
            const SizedBox(height: 4),
            Text(
              '$visitas visita${visitas == 1 ? '' : 's'}',
              style: TextStyle(fontSize: 10.5, color: color),
            ),
          ],
        ],
      ),
    );
  }

  Widget _pildora(String texto, Color color, {bool solido = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: solido ? color : color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          color: solido ? Colors.white : color,
        ),
      ),
    );
  }

  Widget _selectorFecha() {
    final etiqueta = _esHoy
        ? 'Hoy · ${DateFormat("d 'de' MMMM", 'es').format(_fecha)}'
        : toBeginningOfSentenceCase(
            DateFormat("EEEE d 'de' MMMM", 'es').format(_fecha),
          );
    return Row(
      children: [
        BotonRedondo(
          icono: Icons.chevron_left_rounded,
          tooltip: 'Día anterior',
          onTap: () => _cambiarDia(-1),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColores.superficie,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: AppColores.borde),
            ),
            child: Text(
              etiqueta,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColores.textoPrincipal,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        BotonRedondo(
          icono: Icons.chevron_right_rounded,
          tooltip: 'Día siguiente',
          onTap: _esHoy ? null : () => _cambiarDia(1),
        ),
      ],
    );
  }

  /// Entradas por hora dentro del horario del día (como el gráfico del web).
  Widget _grafico() {
    final dia = _dia;
    if (dia == null) {
      return const TarjetaPlana(
        child: SizedBox(
          height: 120,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    final porHora = List<int>.filled(24, 0);
    for (final e in dia.entradas) {
      final h = e.horaDelDia;
      if (e.tipo.toUpperCase() == 'ENTRADA' && h != null && h >= 0 && h < 24) {
        porHora[h]++;
      }
    }
    final h = _horarioDia;
    var desde = (h != null && h.abierto) ? (h.horaApertura ?? 7) : 7;
    var hasta = (h != null && h.abierto) ? (h.horaCierre ?? 22) : 22;
    if (hasta <= desde) {
      desde = 0;
      hasta = 23;
    }
    // En el móvil caben pocas barras: se agrupan de a dos horas si hace falta.
    final paso = (hasta - desde) > 9 ? 2 : 1;
    final barras = <BarraPago>[];
    int? resaltado;
    final ahora = DateTime.now().hour;
    for (var i = desde; i <= hasta; i += paso) {
      var total = 0;
      for (var j = i; j < i + paso && j <= hasta; j++) {
        total += porHora[j];
      }
      if (_esHoy && ahora >= i && ahora < i + paso) resaltado = barras.length;
      barras.add(
        BarraPago('${i.toString().padLeft(2, '0')}h', total.toDouble()),
      );
    }
    // Como en el panel web: las entradas fuera del horario no se pierden, se
    // suman en una barra al extremo.
    final antes = porHora.take(desde).fold<int>(0, (a, b) => a + b);
    final despues = porHora.skip(hasta + 1).fold<int>(0, (a, b) => a + b);
    if (antes > 0) {
      barras.insert(0, BarraPago('Antes', antes.toDouble()));
      if (resaltado != null) resaltado++;
      if (_esHoy && ahora < desde) resaltado = 0;
    }
    if (despues > 0) {
      if (_esHoy && ahora > hasta) resaltado = barras.length;
      barras.add(BarraPago('Desp.', despues.toDouble()));
    }
    return TarjetaPlana(
      child: GraficoBarra(
        textoVacio: 'Sin entradas este día',
        datos: barras,
        resaltado: resaltado,
        color: AppColores.azul,
        altura: 170,
        formatoValor: (v) => v.toStringAsFixed(0),
      ),
    );
  }

  List<Widget> _listaEntradas() {
    final dia = _dia;
    if (dia == null) return const [];
    if (dia.entradas.isEmpty) {
      return [
        VacioApp(
          icono: Icons.door_front_door_outlined,
          titulo: _esHoy ? 'Nadie ha entrado todavía' : 'Sin entradas ese día',
          texto: _esHoy ? 'Las entradas que registres aparecerán aquí.' : null,
        ),
      ];
    }
    return [
      GrupoFilas(
        filas: [
          for (final e in dia.entradas)
            FilaApp(
              inicio: _avatar(_fotoDe(e.codigo), e.nombre, tamano: 42),
              titulo: e.nombre.isEmpty ? 'Sin nombre' : e.nombre,
              subtitulo: 'DNI ${e.codigo}',
              fin: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColores.primario.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  e.hora.length >= 5 ? e.hora.substring(0, 5) : e.hora,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: AppColores.primario,
                  ),
                ),
              ),
            ),
        ],
      ),
    ];
  }
}
