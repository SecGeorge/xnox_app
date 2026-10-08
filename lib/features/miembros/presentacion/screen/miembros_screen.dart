import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';
import 'package:xnox_app/features/miembros/presentacion/controlador/controlador_miembros.dart';

/// Qué lista se ve. Arranca en [atencion]: los que están por vencer y los
/// vencidos a recuperar, que son a quienes hay que llamar primero.
enum _Vista {
  atencion('Atención'),
  activos('Activos'),
  vencidos('Vencidos'),
  sinMembresia('Sin membresía'),
  deudores('Deudores'),
  morosos('Morosos'),
  todos('Todos');

  final String texto;
  const _Vista(this.texto);
}

class MiembrosScreen extends StatefulWidget {
  const MiembrosScreen({super.key});

  @override
  State<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends State<MiembrosScreen> {
  final _controlador = ControladorMiembros();

  List<Miembro> _miembros = [];
  List<MiembroAlerta> _porVencer = [];
  List<MiembroAlerta> _aRecuperar = [];

  /// Foto por id de miembro: los reportes no la traen, la lista sí.
  Map<int, String> _fotos = {};

  /// Teléfono por id de miembro, por si el reporte no lo trae.
  Map<int, String> _telefonos = {};
  bool _cargando = true;
  String? _error;

  _Vista _vista = _Vista.atencion;
  String _busqueda = '';

  @override
  void initState() {
    super.initState();
    _cargarMiembros();
  }

  Future<void> _cargarMiembros() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      // Los reportes son secundarios: si fallan, la lista igual se ve.
      final resultados = await Future.wait([
        _controlador.buscarMiembros(),
        _controlador.proximosVencer().catchError((_) => <MiembroAlerta>[]),
        _controlador.vencidosRecuperar().catchError((_) => <MiembroAlerta>[]),
      ]);
      if (!mounted) return;
      final miembros = resultados[0] as List<Miembro>;
      setState(() {
        _miembros = miembros;
        _porVencer = resultados[1] as List<MiembroAlerta>;
        _aRecuperar = resultados[2] as List<MiembroAlerta>;
        _fotos = {
          for (final m in miembros)
            if (m.id != null && m.imagen.isNotEmpty) m.id!: m.imagen,
        };
        _telefonos = {
          for (final m in miembros)
            if (m.id != null && m.telefono.trim().isNotEmpty) m.id!: m.telefono,
        };
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'No se pudieron cargar los miembros';
        _cargando = false;
      });
      mostrarMensaje(
        context,
        'Error al cargar miembros: $e',
        tipo: TipoMensaje.error,
      );
    }
  }

  // ---------------------------------------------------------------- Filtros

  bool _coincide(String nombre, String codigo) {
    if (_busqueda.isEmpty) return true;
    return nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
        codigo.contains(_busqueda);
  }

  bool _deVista(Miembro m, _Vista v) => switch (v) {
    _Vista.atencion || _Vista.todos => true,
    _Vista.activos => m.estado == EstadoMiembro.activo,
    _Vista.vencidos => m.estado == EstadoMiembro.vencido && !m.sinMembresia,
    _Vista.sinMembresia => m.sinMembresia,
    _Vista.deudores => m.estado == EstadoMiembro.deudor,
    _Vista.morosos => m.estado == EstadoMiembro.moroso,
  };

  int _conteo(_Vista v) => v == _Vista.atencion
      ? _porVencer.length + _aRecuperar.length
      : _miembros.where((m) => _deVista(m, v)).length;

  List<Miembro> get _filtrados => _miembros
      .where((m) => _deVista(m, _vista) && _coincide(m.nombre, m.documento))
      .toList();

  List<MiembroAlerta> _filtrarAlertas(List<MiembroAlerta> l) =>
      l.where((a) => _coincide(a.nombre, a.codigo)).toList();

  /// URL de la foto; la imagen por defecto cuenta como "sin foto".
  String? _urlFoto(String? ruta) {
    if (ruta == null || ruta.isEmpty || ruta.endsWith('usuario.png')) {
      return null;
    }
    if (ruta.startsWith('http')) return ruta;
    return Uri.parse(HttpService().rutaActual).resolve(ruta).toString();
  }

  // ------------------------------------------------------------------ Vista

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: _cargarMiembros,
      children: [
        const CabeceraApp(
          titulo: 'Miembros',
          subtitulo: 'Socios del gimnasio y su estado',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.hombros,
          alineacion: const Alignment(0.3, -0.4),
          altura: 170,
          etiqueta: 'Socios',
          titulo: _cargando ? '…' : '${_miembros.length} miembros',
          pie: Row(
            children: [
              DatoPortada(
                icono: Icons.check_circle_rounded,
                valor: '${_conteo(_Vista.activos)}',
                pie: 'activos',
              ),
              const SizedBox(width: 16),
              DatoPortada(
                icono: Icons.schedule_rounded,
                valor: '${_porVencer.length}',
                pie: 'por vencer',
              ),
              const SizedBox(width: 16),
              DatoPortada(
                icono: Icons.replay_rounded,
                valor: '${_aRecuperar.length}',
                pie: 'a recuperar',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        BuscadorApp(
          hint: 'Buscar por nombre o documento',
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: AppEspaciado.sm + 4),
        FilaChips(
          chips: [
            for (final v in _Vista.values)
              ChipApp(
                texto: v.texto,
                icono: v == _Vista.atencion
                    ? Icons.notifications_active_rounded
                    : null,
                activo: _vista == v,
                contador: _cargando ? null : _conteo(v),
                onTap: () => setState(() => _vista = v),
              ),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        ..._contenido(),
      ],
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error != null) {
      return const [
        VacioApp(
          icono: Icons.cloud_off_rounded,
          titulo: 'No se pudieron cargar los miembros',
          texto: 'Desliza hacia abajo para reintentar.',
        ),
      ];
    }
    if (_vista == _Vista.atencion) return _atencion();

    final filtrados = _filtrados;
    return [
      TituloSeccion(
        icono: Icons.people_alt_rounded,
        titulo: _vista == _Vista.todos ? 'Todos los socios' : _vista.texto,
        detalle: '${filtrados.length} socios',
      ),
      if (filtrados.isEmpty)
        const VacioApp(
          icono: Icons.people_outline_rounded,
          titulo: 'No hay miembros aquí',
          texto: 'Prueba con otro filtro o búsqueda.',
        )
      else
        for (final m in filtrados) ...[
          _tarjetaMiembro(m),
          const SizedBox(height: AppEspaciado.sm + 2),
        ],
    ];
  }

  /// Primero los que vencen en 7 días; después los vencidos del último mes.
  List<Widget> _atencion() {
    final porVencer = _filtrarAlertas(_porVencer);
    final aRecuperar = _filtrarAlertas(_aRecuperar);
    return [
      TituloSeccion(
        icono: Icons.schedule_rounded,
        titulo: 'Por vencer',
        detalle: 'próximos 7 días · ${porVencer.length}',
      ),
      if (porVencer.isEmpty)
        const VacioApp(
          icono: Icons.event_available_rounded,
          titulo: 'Nadie vence esta semana',
          texto:
              'Las membresías que venzan en los próximos 7 días '
              'aparecerán aquí.',
        )
      else
        for (final a in porVencer) ...[
          _tarjetaAlerta(a, recuperar: false),
          const SizedBox(height: AppEspaciado.sm + 2),
        ],
      const SizedBox(height: AppEspaciado.lg),
      TituloSeccion(
        icono: Icons.replay_rounded,
        titulo: 'Vencidos a recuperar',
        detalle: 'últimos 30 días · ${aRecuperar.length}',
      ),
      if (aRecuperar.isEmpty)
        const VacioApp(
          icono: Icons.emoji_events_rounded,
          titulo: 'Nadie por recuperar',
          texto: 'Ningún socio dejó vencer su membresía en el último mes.',
        )
      else
        for (final a in aRecuperar) ...[
          _tarjetaAlerta(a, recuperar: true),
          const SizedBox(height: AppEspaciado.sm + 2),
        ],
    ];
  }

  // ---------------------------------------------------------------- Tarjetas

  Widget _avatar(String? ruta, String iniciales, {double tamano = 52}) {
    final url = _urlFoto(ruta);
    final inicial = Text(
      iniciales,
      style: TextStyle(
        fontSize: tamano * 0.32,
        color: AppColores.sobreRelleno,
        fontWeight: FontWeight.w800,
      ),
    );
    return Container(
      width: tamano,
      height: tamano,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        shape: BoxShape.circle,
      ),
      child: url == null
          ? inicial
          : Image.network(
              url,
              width: tamano,
              height: tamano,
              fit: BoxFit.cover,
              cacheWidth: 200,
              errorBuilder: (_, _, _) => inicial,
            ),
    );
  }

  Widget _tarjetaAlerta(MiembroAlerta a, {required bool recuperar}) {
    final d = a.dias;
    final String cuando;
    final Color color;
    if (recuperar) {
      cuando = d <= 0
          ? 'Venció hoy'
          : d == 1
          ? 'Venció ayer'
          : 'Venció hace $d días';
      color = AppColores.moroso;
    } else {
      cuando = d <= 0
          ? 'Vence hoy'
          : d == 1
          ? 'Vence mañana'
          : 'Vence en $d días';
      color = d <= 1 ? AppColores.moroso : AppColores.naranja;
    }
    final fecha = a.fechaFin == null
        ? ''
        : DateFormat("d MMM", 'es').format(a.fechaFin!);

    return TarjetaPlana(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _avatar(_fotos[a.miembroId], a.iniciales),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  a.nombre.isEmpty ? 'Sin nombre' : a.nombre,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (a.membresia.isNotEmpty) a.membresia,
                    if (fecha.isNotEmpty) fecha,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _pildora(cuando, color, Icons.schedule_rounded),
                    if (a.deuda > 0)
                      _pildora(
                        'Debe S/ ${a.deuda.toStringAsFixed(0)}',
                        AppColores.deudor,
                        Icons.account_balance_wallet_rounded,
                      ),
                  ],
                ),
              ],
            ),
          ),
          // Siempre visible: sin teléfono queda gris y avisa al tocarlo.
          const SizedBox(width: AppEspaciado.sm),
          _botonWhatsApp(a, recuperar: recuperar, cuando: cuando),
        ],
      ),
    );
  }

  Widget _pildora(String texto, Color color, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icono, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            texto,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  /// Abre WhatsApp con un mensaje listo para renovar o para volver.
  Widget _botonWhatsApp(
    MiembroAlerta a, {
    required bool recuperar,
    required String cuando,
  }) {
    final tieneTelefono = _telefonoDe(a).isNotEmpty;
    final verde = tieneTelefono
        ? const Color(0xFF25D366)
        : AppColores.textoSecundario;
    return Tooltip(
      message: tieneTelefono ? 'Escribir por WhatsApp' : 'Sin teléfono',
      child: Material(
        color: verde.withValues(alpha: 0.12),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => _abrirWhatsApp(a, recuperar: recuperar, cuando: cuando),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(Icons.chat_rounded, color: verde, size: 22),
          ),
        ),
      ),
    );
  }

  /// Solo dígitos; si el reporte no trae teléfono se usa el de la ficha.
  String _telefonoDe(MiembroAlerta a) {
    final propio = a.telefono.replaceAll(RegExp(r'\D'), '');
    if (propio.isNotEmpty) return propio;
    return (_telefonos[a.miembroId] ?? '').replaceAll(RegExp(r'\D'), '');
  }

  Future<void> _abrirWhatsApp(
    MiembroAlerta a, {
    required bool recuperar,
    required String cuando,
  }) async {
    var tel = _telefonoDe(a);
    if (tel.isEmpty) {
      mostrarMensaje(
        context,
        'Este socio no tiene teléfono registrado',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    if (tel.length == 9) tel = '51$tel';
    final nombre = a.nombre.split(' ').first;
    final plan = a.membresia.isEmpty ? '' : ' ${a.membresia}';
    final mensaje = recuperar
        ? 'Hola $nombre, ¡te extrañamos en el gimnasio! Tu membresía$plan '
              '${cuando.toLowerCase()}. Renueva y retoma tu entrenamiento.'
        : 'Hola $nombre, tu membresía$plan ${cuando.toLowerCase()}. '
              'Renueva a tiempo y sigue entrenando sin pausas.';
    final url = Uri.parse(
      'https://wa.me/$tel?text=${Uri.encodeComponent(mensaje)}',
    );
    var ok = false;
    try {
      ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
    if (!ok && mounted) {
      mostrarMensaje(
        context,
        'No se pudo abrir WhatsApp',
        tipo: TipoMensaje.error,
      );
    }
  }

  Widget _tarjetaMiembro(Miembro m) {
    final fecha = m.fechaVencimiento != null
        ? DateFormat('dd MMM yyyy', 'es').format(m.fechaVencimiento!)
        : 'Sin contrato';
    return TarjetaPlana(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          _avatar(m.imagen, m.iniciales),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${m.plan} · DNI ${m.documento}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                // Wrap y no Row: con nombres largos la columna se estrecha y
                // "Vence + saldo" no entraban en una línea (desbordaba). Así el
                // saldo baja a la siguiente línea en vez de recortarse.
                Wrap(
                  spacing: 10,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.event,
                          size: 14,
                          color: AppColores.textoSecundario,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          m.sinMembresia ? 'Sin contrato' : 'Vence: $fecha',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                      ],
                    ),
                    if (m.saldoPendiente > 0)
                      Text(
                        'S/ ${m.saldoPendiente.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: m.estado.color,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          EtiquetaEstado(
            texto: m.etiquetaEstado,
            color: m.sinMembresia ? AppColores.textoSecundario : m.estado.color,
          ),
        ],
      ),
    );
  }
}
