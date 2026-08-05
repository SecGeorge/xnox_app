import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/recomendaciones/datos/repositorio_recomendaciones.dart';
import 'package:xnox_app/features/recomendaciones/dominio/entidades/recomendacion.dart';

/// Bandeja de recomendaciones de la sede. Solo el personal llega aquí: el
/// backend responde 403 si la pide un cliente.
///
/// Las no leídas van primero y se resaltan; tocar una la marca como leída.
class RecomendacionesScreen extends StatefulWidget {
  const RecomendacionesScreen({super.key});

  @override
  State<RecomendacionesScreen> createState() => _RecomendacionesScreenState();
}

class _RecomendacionesScreenState extends State<RecomendacionesScreen> {
  final _repositorio = RepositorioRecomendaciones();

  List<Recomendacion> _recomendaciones = [];
  DestinoRecomendacion? _filtro;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    try {
      final lista = await _repositorio.listar(destino: _filtro);
      if (!mounted) return;
      setState(() {
        _recomendaciones = lista;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudieron cargar las recomendaciones',
          tipo: TipoMensaje.error);
    }
  }

  Future<void> _cambiarFiltro(DestinoRecomendacion? destino) async {
    setState(() => _filtro = destino);
    await _cargar();
  }

  /// Alterna leída / no leída. Se pinta primero y se revierte si el servidor
  /// falla: marcar es una acción muy frecuente y esperar la red se nota.
  Future<void> _alternarLeido(Recomendacion r) async {
    final indice = _recomendaciones.indexWhere((x) => x.id == r.id);
    if (indice == -1) return;

    setState(() => _recomendaciones[indice] = _copiaConLeido(r, !r.leido));

    final ok = await _repositorio.marcarLeido(r.id, leido: !r.leido);
    if (!mounted) return;
    if (!ok) {
      setState(() => _recomendaciones[indice] = r);
      mostrarMensaje(context, 'No se pudo actualizar la recomendación',
          tipo: TipoMensaje.error);
    }
  }

  Future<void> _eliminar(Recomendacion r) async {
    final confirmar = await confirmarDialog(
      context,
      titulo: 'Eliminar recomendación',
      mensaje: 'Se quitará de la bandeja. Esta acción no se puede deshacer.',
      icono: Icons.delete_outline,
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!confirmar) return;

    final ok = await _repositorio.eliminar(r.id);
    if (!mounted) return;
    if (ok) {
      setState(() => _recomendaciones.removeWhere((x) => x.id == r.id));
      mostrarMensaje(context, 'Recomendación eliminada',
          tipo: TipoMensaje.exito);
    } else {
      mostrarMensaje(context, 'No se pudo eliminar', tipo: TipoMensaje.error);
    }
  }

  Recomendacion _copiaConLeido(Recomendacion r, bool leido) => Recomendacion(
        id: r.id,
        destino: r.destino,
        mensaje: r.mensaje,
        anonimo: r.anonimo,
        leido: leido,
        fechaCreacion: r.fechaCreacion,
        autor: r.autor,
        autorRol: r.autorRol,
        autorTelefono: r.autorTelefono,
      );

  int get _pendientes => _recomendaciones.where((r) => !r.leido).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(
        title: const Text('Recomendaciones'),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _barraFiltros(),
            Expanded(
              child: _cargando
                  ? const Center(child: CircularProgressIndicator())
                  : _recomendaciones.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.all(AppEspaciado.lg),
                          child: EstadoVacio(
                            icono: Icons.rate_review_outlined,
                            mensaje:
                                'Todavía no hay recomendaciones para mostrar',
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _cargar,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(
                                AppEspaciado.md,
                                AppEspaciado.sm,
                                AppEspaciado.md,
                                AppEspaciado.lg),
                            itemCount: _recomendaciones.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: AppEspaciado.sm + 4),
                            itemBuilder: (_, i) =>
                                _tarjeta(_recomendaciones[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barraFiltros() {
    return Container(
      color: AppColores.superficie,
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, AppEspaciado.sm, AppEspaciado.md, AppEspaciado.sm),
      child: Row(
        children: [
          _chipFiltro('Todas', null),
          const SizedBox(width: AppEspaciado.sm),
          _chipFiltro('Gimnasio', DestinoRecomendacion.gimnasio),
          const SizedBox(width: AppEspaciado.sm),
          _chipFiltro('App', DestinoRecomendacion.app),
          const Spacer(),
          if (_pendientes > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColores.moroso.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_pendientes sin leer',
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: AppColores.moroso,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chipFiltro(String texto, DestinoRecomendacion? destino) {
    final activo = _filtro == destino;
    return InkWell(
      onTap: () => _cambiarFiltro(destino),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: activo ? AppColores.primario : AppColores.fondo,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: activo ? AppColores.primario : AppColores.borde),
        ),
        child: Text(
          texto,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w600,
            color: activo ? Colors.white : AppColores.textoSecundario,
          ),
        ),
      ),
    );
  }

  Widget _tarjeta(Recomendacion r) {
    final esApp = r.destino == DestinoRecomendacion.app;
    final colorDestino = esApp ? AppColores.morado : AppColores.azul;

    return TarjetaApp(
      onTap: () => _alternarLeido(r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: colorDestino.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(esApp ? Icons.phone_iphone : Icons.fitness_center,
                        size: 12, color: colorDestino),
                    const SizedBox(width: 4),
                    Text(
                      r.destino.etiqueta,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colorDestino,
                      ),
                    ),
                  ],
                ),
              ),
              if (!r.leido) ...[
                const SizedBox(width: AppEspaciado.sm),
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColores.moroso,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              const Spacer(),
              Text(
                _fecha(r.fechaCreacion),
                style: const TextStyle(
                    fontSize: 11.5, color: AppColores.textoSecundario),
              ),
              InkWell(
                onTap: () => _eliminar(r),
                borderRadius: BorderRadius.circular(20),
                child: const Padding(
                  padding: EdgeInsets.all(6),
                  child: Icon(Icons.delete_outline,
                      size: 18, color: AppColores.vencido),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Text(
            r.mensaje,
            style: TextStyle(
              fontSize: 14,
              height: 1.35,
              fontWeight: r.leido ? FontWeight.w400 : FontWeight.w600,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Row(
            children: [
              Icon(
                r.anonimo ? Icons.visibility_off_outlined : Icons.person_outline,
                size: 14,
                color: AppColores.textoSecundario,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  r.anonimo
                      ? 'Anónimo'
                      : [r.autor, if (r.autorRol.isNotEmpty) r.autorRol]
                          .join(' · '),
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 12, color: AppColores.textoSecundario),
                ),
              ),
              Text(
                r.leido ? 'Leída' : 'Marcar como leída',
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: r.leido ? AppColores.vencido : AppColores.primario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fecha(DateTime? fecha) =>
      fecha == null ? '' : DateFormat('dd/MM/yyyy HH:mm').format(fecha);
}
