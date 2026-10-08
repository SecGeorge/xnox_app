import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/permisos/permisos.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/publicidad/presentacion/controlador/controlador_publicidad.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';
import 'package:xnox_app/features/publicidad/presentacion/screen/formulario_publicidad_screen.dart';

class PublicidadScreen extends StatefulWidget {
  const PublicidadScreen({super.key});

  @override
  State<PublicidadScreen> createState() => _PublicidadScreenState();
}

class _PublicidadScreenState extends State<PublicidadScreen> {
  final _controlador = ControladorPublicidad();
  List<Publicidad> _publicidades = [];
  bool _isLoading = true;

  /// Crear/editar/eliminar publicidad requiere el permiso de gestión. Sin él la
  /// pantalla es de solo lectura (se ocultan el botón "Nueva" y el menú ⋮).
  bool _puedeGestionar = false;

  @override
  void initState() {
    super.initState();
    _cargarPublicidades();
    _cargarPermisos();
  }

  Future<void> _cargarPermisos() async {
    final permisos = await Permisos.cargar();
    if (!mounted) return;
    setState(
      () => _puedeGestionar = permisos.tiene(PermisosMovil.publicidadGestion),
    );
  }

  Future<void> _cargarPublicidades() async {
    setState(() => _isLoading = true);
    try {
      final data = await _controlador.fetchPublicidades();
      if (!mounted) return;
      setState(() {
        _publicidades = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar publicidades: $e')),
      );
    }
  }

  bool _estaVigente(Publicidad p) {
    final hoy = DateTime.now();
    return !hoy.isBefore(p.fechaInicio) && !hoy.isAfter(p.fechaFin);
  }

  Future<void> _editar(Publicidad pub) async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FormularioPublicidadScreen(publicidad: pub),
      ),
    );
    if (result == true) {
      if (mounted) {
        mostrarMensaje(
          context,
          'Publicidad actualizada',
          tipo: TipoMensaje.exito,
        );
      }
      _cargarPublicidades();
    }
  }

  Future<void> _eliminar(Publicidad pub) async {
    final confirmar = await confirmarDialog(
      context,
      titulo: 'Eliminar publicidad',
      mensaje: '¿Seguro que deseas eliminar "${pub.titulo}"?',
      icono: Icons.delete_outline_rounded,
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (confirmar != true || pub.id == null) return;

    final ok = await _controlador.eliminarPublicidad(pub.id!);
    if (!mounted) return;
    if (ok) {
      mostrarMensaje(context, 'Publicidad eliminada', tipo: TipoMensaje.exito);
      _cargarPublicidades();
    } else {
      mostrarMensaje(
        context,
        'No se pudo eliminar la publicidad',
        tipo: TipoMensaje.error,
      );
    }
  }

  /// null = todas.
  bool? _filtroVigente;

  Future<void> _nueva() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => const FormularioPublicidadScreen(),
      ),
    );
    if (result == true) _cargarPublicidades();
  }

  @override
  Widget build(BuildContext context) {
    final vigentes = _publicidades.where(_estaVigente).length;
    final lista = _publicidades
        .where(
          (p) => _filtroVigente == null || _estaVigente(p) == _filtroVigente,
        )
        .toList();
    return PantallaApp(
      onRefresh: _cargarPublicidades,
      espacioAbajo: 110,
      botonFlotante: _puedeGestionar
          ? FloatingActionButton.extended(
              onPressed: _nueva,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Nueva'),
            )
          : null,
      children: [
        const CabeceraApp(
          titulo: 'Publicidad',
          subtitulo: 'Novedades y promociones que ven tus socios',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.tienda,
          alineacion: const Alignment(0.4, 0.2),
          etiqueta: 'En la app de tus socios',
          titulo: _isLoading
              ? '…'
              : vigentes == 1
              ? '1 campaña vigente'
              : '$vigentes campañas vigentes',
          texto: 'Salen como novedades al abrir la app del cliente.',
        ),
        const SizedBox(height: AppEspaciado.md),
        FilaChips(
          chips: [
            ChipApp(
              texto: 'Todas',
              activo: _filtroVigente == null,
              contador: _isLoading ? null : _publicidades.length,
              onTap: () => setState(() => _filtroVigente = null),
            ),
            ChipApp(
              texto: 'Vigentes',
              activo: _filtroVigente == true,
              contador: _isLoading ? null : vigentes,
              onTap: () => setState(() => _filtroVigente = true),
            ),
            ChipApp(
              texto: 'Inactivas',
              activo: _filtroVigente == false,
              contador: _isLoading ? null : _publicidades.length - vigentes,
              onTap: () => setState(() => _filtroVigente = false),
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.campaign_rounded,
          titulo: 'Campañas',
          detalle: _isLoading ? null : '${lista.length}',
        ),
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (lista.isEmpty)
          VacioApp(
            icono: Icons.campaign_outlined,
            titulo: _publicidades.isEmpty
                ? 'Aún no hay campañas'
                : 'No hay campañas en este filtro',
            texto: _publicidades.isEmpty && _puedeGestionar
                ? 'Crea la primera con el botón "Nueva".'
                : null,
          )
        else
          for (final p in lista) ...[
            _tarjetaPublicidad(p),
            const SizedBox(height: AppEspaciado.md),
          ],
      ],
    );
  }

  Widget _tarjetaPublicidad(Publicidad pub) {
    final vigente = _estaVigente(pub);
    final fmt = DateFormat('d MMM yyyy', 'es');
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: AppColores.superficie,
        borderRadius: BorderRadius.circular(AppEspaciado.radio + 4),
        border: Border.all(color: AppColores.borde),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 160,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                pub.imagenUrl != null
                    ? Image.network(
                        pub.imagenUrl!,
                        fit: BoxFit.cover,
                        alignment: pub.alineacion,
                        cacheWidth: 900,
                        errorBuilder: (c, e, s) => _placeholderImagen(),
                      )
                    : _placeholderImagen(),
                // Degradado para que se lean las etiquetas sobre la imagen.
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.35),
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.45),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: vigente ? AppColores.activo : AppColores.vencido,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      vigente ? 'VIGENTE' : 'INACTIVA',
                      style: const TextStyle(
                        fontSize: 10.5,
                        letterSpacing: 0.8,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                if (_puedeGestionar)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert_rounded,
                        color: Colors.white,
                      ),
                      onSelected: (op) {
                        if (op == 'editar') _editar(pub);
                        if (op == 'eliminar') _eliminar(pub);
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'editar',
                          child: Row(
                            children: [
                              Icon(Icons.edit_outlined, size: 20),
                              SizedBox(width: AppEspaciado.sm),
                              Text('Editar'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'eliminar',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 20,
                                color: AppColores.moroso,
                              ),
                              SizedBox(width: AppEspaciado.sm),
                              Text(
                                'Eliminar',
                                style: TextStyle(color: AppColores.moroso),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                Positioned(
                  left: 12,
                  bottom: 10,
                  child: Row(
                    children: [
                      const Icon(
                        Icons.date_range_rounded,
                        size: 15,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${fmt.format(pub.fechaInicio)} — ${fmt.format(pub.fechaFin)}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: _puedeGestionar ? () => _editar(pub) : null,
            child: Padding(
              padding: const EdgeInsets.all(AppEspaciado.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pub.titulo,
                    style: TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColores.textoPrincipal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    pub.descripcion,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImagen() {
    return Container(
      decoration: BoxDecoration(gradient: AppColores.degradadoRelleno),
      child: Center(
        child: Icon(
          Icons.campaign_rounded,
          size: 44,
          color: AppColores.sobreRellenoSuave,
        ),
      ),
    );
  }
}
