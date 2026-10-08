import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/asistencia_cliente.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_asistencias.dart';
import 'package:xnox_app/core/widgets/foto_tarjeta.dart';

/// Historial de visitas del socio: portada con las del mes, filtro por plan,
/// calendario mensual (los días que vino van con el color de la marca) y la
/// lista de visitas del día elegido o las más recientes.
class AsistenciasScreen extends StatefulWidget {
  const AsistenciasScreen({super.key});

  @override
  State<AsistenciasScreen> createState() => _AsistenciasScreenState();
}

class _AsistenciasScreenState extends State<AsistenciasScreen> {
  /// Fotos de entrenamiento para las miniaturas de cada visita.
  static const _fotos = [
    'assets/imagenes/sesiones/piernas.jpg',
    'assets/imagenes/sesiones/pecho.jpg',
    'assets/imagenes/sesiones/espalda.jpg',
    'assets/imagenes/sesiones/hombros.jpg',
    'assets/imagenes/sesiones/brazos.jpg',
    'assets/imagenes/sesiones/gluteos.jpg',
    'assets/imagenes/sesiones/core.jpg',
  ];

  final _controlador = ControladorAsistencias();

  bool _isLoading = true;
  List<AsistenciaCliente> _asistencias = [];
  List<OpcionMembresia> _membresias = [];
  int _filtroMembresia = 0;

  // Mes visible en el calendario (siempre normalizado al día 1).
  late DateTime _mes;
  // Día seleccionado dentro del calendario (para ver el detalle de visitas).
  DateTime? _diaSeleccionado;

  @override
  void initState() {
    super.initState();
    final ahora = DateTime.now();
    _mes = DateTime(ahora.year, ahora.month);
    _cargarInicial();
  }

  Future<void> _cargarInicial() async {
    setState(() => _isLoading = true);
    final data = await _controlador.cargarInicial();
    if (!mounted) return;
    setState(() {
      _membresias = data.membresias;
      _asistencias = data.asistencias;
      _filtroMembresia = 0;
      _isLoading = false;
    });
  }

  Future<void> _cambiarFiltro(int membresiaId) async {
    setState(() {
      _filtroMembresia = membresiaId;
      _isLoading = true;
      _diaSeleccionado = null;
    });
    final lista = await _controlador.obtenerAsistencias(
      membresiaId: membresiaId,
    );
    if (!mounted) return;
    setState(() {
      _asistencias = lista;
      _isLoading = false;
      // Posicionamos el calendario en el mes de la última asistencia.
      if (lista.isNotEmpty) {
        final ultima = _ordenadas.first.fecha;
        _mes = DateTime(ultima.year, ultima.month);
      }
    });
  }

  // ── Datos derivados ──────────────────────────────────────────────
  Map<String, List<AsistenciaCliente>> get _porDia {
    final mapa = <String, List<AsistenciaCliente>>{};
    for (final a in _asistencias) {
      mapa.putIfAbsent(a.claveDia, () => []).add(a);
    }
    return mapa;
  }

  /// De la más reciente a la más antigua.
  List<AsistenciaCliente> get _ordenadas {
    final lista = [..._asistencias];
    lista.sort((a, b) {
      final f = b.fecha.compareTo(a.fecha);
      return f != 0 ? f : b.hora.compareTo(a.hora);
    });
    return lista;
  }

  String _clave(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  int get _visitasEsteMes {
    final ahora = DateTime.now();
    return _asistencias
        .where(
          (a) => a.fecha.year == ahora.year && a.fecha.month == ahora.month,
        )
        .map((a) => a.claveDia)
        .toSet()
        .length;
  }

  int get _promedioSemanal {
    if (_asistencias.isEmpty) return 0;
    final dias = _asistencias.map((a) => a.claveDia).toSet().toList()..sort();
    if (dias.length < 2) return dias.length;
    final primera = DateTime.parse(dias.first);
    final ultima = DateTime.parse(dias.last);
    final difDias = ultima.difference(primera).inDays.abs().clamp(1, 1 << 30);
    final semanas = (difDias / 7).clamp(1, double.infinity);
    return (dias.length / semanas).round();
  }

  /// Días seguidos viniendo, contando hasta hoy (o ayer, si hoy aún no vino).
  int get _racha {
    final dias = _asistencias.map((a) => a.claveDia).toSet();
    final hoy = DateTime.now();
    var d = DateTime(hoy.year, hoy.month, hoy.day);
    if (!dias.contains(_clave(d))) d = d.subtract(const Duration(days: 1));
    var n = 0;
    while (dias.contains(_clave(d))) {
      n++;
      d = d.subtract(const Duration(days: 1));
    }
    return n;
  }

  // ── UI ───────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _cargarInicial,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              AppEspaciado.md,
              AppEspaciado.md,
              AppEspaciado.md,
              AppEspaciado.xl,
            ),
            children: [
              _cabecera(),
              const SizedBox(height: AppEspaciado.md + 4),
              _portada(),
              if (_membresias.isNotEmpty) ...[
                const SizedBox(height: AppEspaciado.md),
                _filtros(),
              ],
              const SizedBox(height: AppEspaciado.md),
              if (_isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                _calendario(),
                const SizedBox(height: AppEspaciado.lg),
                _listaVisitas(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _cabecera() {
    return Row(
      children: [
        Material(
          color: AppColores.superficie,
          shape: CircleBorder(side: BorderSide(color: AppColores.borde)),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () => Navigator.of(context).maybePop(),
            child: SizedBox(
              width: 46,
              height: 46,
              child: Icon(Icons.arrow_back_rounded, color: AppColores.primario),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Mis asistencias',
                style: TextStyle(
                  fontSize: 25,
                  height: 1.15,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.4,
                  color: AppColores.textoPrincipal,
                ),
              ),
              const Text(
                'Historial de tus visitas al gimnasio',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _portada() {
    final mes = _visitasEsteMes;
    final nombreMes = DateFormat('MMMM', 'es').format(DateTime.now());
    return SizedBox(
      height: 178,
      child: FotoTarjeta(
        foto: 'assets/imagenes/inicio/progreso.jpg',
        alineacion: const Alignment(0.4, -0.2),
        radio: AppEspaciado.radio + 6,
        degradadoHorizontal: true,
        child: Padding(
          padding: const EdgeInsets.all(AppEspaciado.md + 2),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'EN ${nombreMes.toUpperCase()}',
                style: TextStyle(
                  fontSize: 11.5,
                  letterSpacing: 1.3,
                  fontWeight: FontWeight.w800,
                  color: AppColores.destacado,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                mes == 1 ? '1 visita' : '$mes visitas',
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _datoPortada(
                    Icons.local_fire_department_rounded,
                    '$_racha',
                    _racha == 1 ? 'día seguido' : 'días seguidos',
                  ),
                  const SizedBox(width: 18),
                  _datoPortada(
                    Icons.show_chart_rounded,
                    '$_promedioSemanal',
                    'por semana',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _datoPortada(IconData icono, String valor, String pie) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(icono, size: 18, color: AppColores.destacado),
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                height: 1.1,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
            Text(
              pie,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.white.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Chips: "Recientes" y uno por cada plan que tuvo el socio.
  Widget _filtros() {
    Widget chip(int id, String texto) {
      final activo = _filtroMembresia == id;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Material(
          color: activo ? AppColores.primario : AppColores.superficie,
          shape: StadiumBorder(
            side: BorderSide(
              color: activo ? AppColores.primario : AppColores.borde,
            ),
          ),
          child: InkWell(
            customBorder: const StadiumBorder(),
            onTap: activo ? null : () => _cambiarFiltro(id),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
              child: Text(
                texto,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: activo ? Colors.white : AppColores.textoPrincipal,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          chip(0, 'Recientes'),
          for (final m in _membresias) chip(m.id, m.nombre),
        ],
      ),
    );
  }

  Widget _calendario() {
    final porDia = _porDia;
    final hoyClave = _clave(DateTime.now());

    // Lunes como primer día de la semana.
    final primerDia = DateTime(_mes.year, _mes.month, 1);
    final blancosIniciales = primerDia.weekday - 1; // 0 = lunes
    final diasEnMes = DateTime(_mes.year, _mes.month + 1, 0).day;
    final visitasMes = porDia.keys
        .where((k) => k.startsWith(_clave(primerDia).substring(0, 7)))
        .length;

    final celdas = <Widget>[
      for (var i = 0; i < blancosIniciales; i++) const SizedBox(),
      for (var dia = 1; dia <= diasEnMes; dia++)
        Builder(
          builder: (_) {
            final fecha = DateTime(_mes.year, _mes.month, dia);
            final clave = _clave(fecha);
            final tieneVisita = porDia.containsKey(clave);
            return _celdaDia(
              dia: dia,
              tieneVisita: tieneVisita,
              esHoy: clave == hoyClave,
              seleccionado:
                  _diaSeleccionado != null &&
                  _clave(_diaSeleccionado!) == clave,
              onTap: tieneVisita
                  ? () => setState(
                      () => _diaSeleccionado =
                          _diaSeleccionado != null &&
                              _clave(_diaSeleccionado!) == clave
                          ? null
                          : fecha,
                    )
                  : null,
            );
          },
        ),
    ];

    const labels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          // Cabecera con foto: mes, días entrenados y flechas.
          SizedBox(
            height: 96,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.asset(
                  'assets/imagenes/inicio/rutinas.jpg',
                  fit: BoxFit.cover,
                  alignment: const Alignment(0, -0.2),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(
                      AppColores.primario,
                      Colors.black,
                      0.35,
                    )!.withValues(alpha: 0.78),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      _botonMes(Icons.chevron_left_rounded, -1),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              toBeginningOfSentenceCase(
                                DateFormat('MMMM yyyy', 'es').format(_mes),
                              ),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              visitasMes == 0
                                  ? 'Sin visitas'
                                  : visitasMes == 1
                                  ? '1 día entrenado'
                                  : '$visitasMes días entrenados',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: AppColores.destacado,
                              ),
                            ),
                          ],
                        ),
                      ),
                      _botonMes(Icons.chevron_right_rounded, 1),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
            child: Column(
              children: [
                Row(
                  children: [
                    for (final l in labels)
                      Expanded(
                        child: Center(
                          child: Text(
                            l,
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
                const SizedBox(height: 6),
                GridView.count(
                  crossAxisCount: 7,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  children: celdas,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _botonMes(IconData icono, int delta) {
    return Material(
      color: Colors.white.withValues(alpha: 0.16),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => setState(() {
          _mes = DateTime(_mes.year, _mes.month + delta);
          _diaSeleccionado = null;
        }),
        child: SizedBox(
          width: 38,
          height: 38,
          child: Icon(icono, color: Colors.white),
        ),
      ),
    );
  }

  Widget _celdaDia({
    required int dia,
    required bool tieneVisita,
    required bool esHoy,
    required bool seleccionado,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          gradient: tieneVisita ? AppColores.degradadoRelleno : null,
          color: tieneVisita ? null : Colors.transparent,
          shape: BoxShape.circle,
          border: seleccionado
              ? Border.all(color: AppColores.naranja, width: 2.5)
              : esHoy
              ? Border.all(color: AppColores.primario, width: 1.6)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          '$dia',
          style: TextStyle(
            fontSize: 13,
            fontWeight: tieneVisita || esHoy
                ? FontWeight.w800
                : FontWeight.w500,
            color: tieneVisita
                ? AppColores.sobreRelleno
                : esHoy
                ? AppColores.primario
                : AppColores.textoPrincipal,
          ),
        ),
      ),
    );
  }

  /// Visitas del día elegido en el calendario o, si no hay, las recientes.
  Widget _listaVisitas() {
    final dia = _diaSeleccionado;
    final visitas = dia == null
        ? _ordenadas.take(10).toList()
        : (_porDia[_clave(dia)] ?? []);
    final titulo = dia == null
        ? 'Últimas visitas'
        : toBeginningOfSentenceCase(
            DateFormat("EEEE d 'de' MMMM", 'es').format(dia),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
          child: Row(
            children: [
              Icon(
                dia == null ? Icons.history_rounded : Icons.event_note_rounded,
                color: AppColores.primario,
                size: 24,
              ),
              const SizedBox(width: AppEspaciado.sm),
              Expanded(
                child: Text(
                  titulo,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              if (dia != null)
                InkWell(
                  onTap: () => setState(() => _diaSeleccionado = null),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      'Ver recientes',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: AppColores.primario,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (visitas.isEmpty)
          _sinVisitas()
        else
          Container(
            decoration: BoxDecoration(
              color: AppColores.superficie,
              borderRadius: BorderRadius.circular(AppEspaciado.radio),
              border: Border.all(color: AppColores.borde),
            ),
            child: Column(
              children: [
                for (var i = 0; i < visitas.length; i++) ...[
                  if (i > 0)
                    Divider(height: 1, indent: 72, color: AppColores.borde),
                  _filaVisita(visitas[i]),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _filaVisita(AsistenciaCliente v) {
    final mes = DateFormat(
      'MMM',
      'es',
    ).format(v.fecha).replaceAll('.', '').toUpperCase();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Foto del gimnasio con la fecha encima.
          ClipRRect(
            borderRadius: BorderRadius.circular(AppEspaciado.radioSm + 2),
            child: SizedBox(
              width: 56,
              height: 56,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.asset(
                    _fotos[v.fecha.weekday % _fotos.length],
                    fit: BoxFit.cover,
                    cacheWidth: 200,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColores.primario.withValues(alpha: 0.25),
                          Color.lerp(
                            AppColores.primario,
                            Colors.black,
                            0.4,
                          )!.withValues(alpha: 0.9),
                        ],
                      ),
                    ),
                  ),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '${v.fecha.day}',
                        style: const TextStyle(
                          fontSize: 19,
                          height: 1,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        mes,
                        style: TextStyle(
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: AppColores.destacado,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  toBeginningOfSentenceCase(
                    DateFormat('EEEE', 'es').format(v.fecha),
                  ),
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                Text(
                  v.membresia,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.07),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.login_rounded, size: 14, color: AppColores.primario),
                const SizedBox(width: 4),
                Text(
                  v.hora.isEmpty ? '—' : v.hora,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColores.primario,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sinVisitas() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: AppColores.primario.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.qr_code_scanner_rounded,
              size: 30,
              color: AppColores.primario,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Aún no hay visitas',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Muestra tu QR en recepción y cada ingreso aparecerá aquí.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              height: 1.35,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}
