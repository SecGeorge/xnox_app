import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
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

  @override
  void initState() {
    super.initState();
    _cargarPublicidades();
  }

  Future<void> _cargarPublicidades() async {
    setState(() => _isLoading = true);
    try {
      final data = await _controlador.fetchPublicidades();
      setState(() {
        _publicidades = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar publicidades: $e')),
        );
      }
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
        mostrarMensaje(context, 'Publicidad actualizada',
            tipo: TipoMensaje.exito);
      }
      _cargarPublicidades();
    }
  }

  Future<void> _eliminar(Publicidad pub) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar publicidad'),
        content: Text('¿Seguro que deseas eliminar "${pub.titulo}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColores.moroso),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmar != true || pub.id == null) return;

    final ok = await _controlador.eliminarPublicidad(pub.id!);
    if (!mounted) return;
    if (ok) {
      mostrarMensaje(context, 'Publicidad eliminada', tipo: TipoMensaje.exito);
      _cargarPublicidades();
    } else {
      mostrarMensaje(context, 'No se pudo eliminar la publicidad',
          tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Publicidad')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _publicidades.isEmpty
              ? const EstadoVacio(
                  icono: Icons.campaign_outlined,
                  mensaje: 'Aún no hay campañas registradas.\nCrea la primera con el botón +',
                )
              : RefreshIndicator(
                  onRefresh: _cargarPublicidades,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppEspaciado.md,
                        AppEspaciado.md, AppEspaciado.md, 96),
                    itemCount: _publicidades.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppEspaciado.sm + 4),
                    itemBuilder: (_, i) => _tarjetaPublicidad(_publicidades[i]),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.of(context).push(
            MaterialPageRoute(
                builder: (context) => const FormularioPublicidadScreen()),
          );
          if (result == true) {
            _cargarPublicidades();
          }
        },
        backgroundColor: AppColores.primario,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva'),
      ),
    );
  }

  Widget _tarjetaPublicidad(Publicidad pub) {
    final vigente = _estaVigente(pub);
    final fmt = DateFormat('dd MMM yyyy', 'es');
    return TarjetaApp(
      onTap: () {},
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(AppEspaciado.radio)),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: pub.imagenUrl != null
                  ? Image.network(
                      pub.imagenUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => _placeholderImagen(),
                    )
                  : _placeholderImagen(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(AppEspaciado.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pub.titulo,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                    ),
                    EtiquetaEstado(
                      texto: vigente ? 'Vigente' : 'Inactiva',
                      color: vigente ? AppColores.activo : AppColores.vencido,
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(Icons.more_vert,
                          color: AppColores.textoSecundario),
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
                              Icon(Icons.delete_outline,
                                  size: 20, color: AppColores.moroso),
                              SizedBox(width: AppEspaciado.sm),
                              Text('Eliminar',
                                  style: TextStyle(color: AppColores.moroso)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  pub.descripcion,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: AppEspaciado.sm + 4),
                Row(
                  children: [
                    const Icon(Icons.date_range,
                        size: 15, color: AppColores.textoSecundario),
                    const SizedBox(width: 6),
                    Text(
                      '${fmt.format(pub.fechaInicio)} — ${fmt.format(pub.fechaFin)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _placeholderImagen() {
    return Container(
      color: AppColores.fondo,
      child: const Center(
        child: Icon(Icons.image_outlined, size: 40, color: AppColores.vencido),
      ),
    );
  }
}
