import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';

/// Pantalla del cliente para ver su saldo de puntos de fidelidad, el historial
/// de movimientos y las promociones vigentes (cómo ganar y qué se puede canjear).
class PromocionesScreen extends StatefulWidget {
  const PromocionesScreen({super.key});

  @override
  State<PromocionesScreen> createState() => _PromocionesScreenState();
}

class _PromocionesScreenState extends State<PromocionesScreen> {
  final _controlador = ControladorPromociones();
  ResumenPuntos _resumen = ResumenPuntos.vacio;
  bool _isLoading = true;

  /// Cuántos movimientos del historial se muestran por página.
  static const _porPagina = 10;

  /// Cantidad de movimientos visibles actualmente (crece con "Ver más").
  int _historialVisible = _porPagina;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    ResumenPuntos r;
    try {
      r = await _controlador.obtenerResumen();
    } catch (_) {
      r = ResumenPuntos.vacio;
    }
    if (!mounted) return;
    setState(() {
      _resumen = r;
      _historialVisible = _porPagina; // Reinicia la paginación al recargar.
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: ListView(
                padding: const EdgeInsets.all(AppEspaciado.md),
                children: [
                  const SizedBox(height: AppEspaciado.xs),
                  _buildTarjetaSaldo(_resumen.saldo),
                  const SizedBox(height: AppEspaciado.lg),
                  _buildSeccionPromociones(_resumen.promociones),
                  const SizedBox(height: AppEspaciado.lg),
                  _buildSeccionHistorial(_resumen.movimientos),
                  const SizedBox(height: AppEspaciado.xl),
                ],
              ),
            ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tarjeta de saldo (hero)
  // ---------------------------------------------------------------------------

  Widget _buildTarjetaSaldo(int saldo) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: AppEspaciado.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColores.primario, AppColores.acento],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: const Icon(Icons.stars_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: AppEspaciado.md),
          const Expanded(
            child: Text(
              'Saldo disponible',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                '$saldo',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              const Text(
                'pts',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Sección: promociones vigentes
  // ---------------------------------------------------------------------------

  Widget _buildSeccionPromociones(List<PromocionCliente> promociones) {
    if (promociones.isEmpty) {
      return const TarjetaApp(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: AppEspaciado.md),
          child: EstadoVacio(
            icono: Icons.card_giftcard_outlined,
            mensaje: 'No hay promociones vigentes por ahora',
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const EncabezadoSeccion(
          titulo: 'Promociones vigentes',
          subtitulo: 'Cómo ganar puntos y qué puedes canjear',
        ),
        const SizedBox(height: AppEspaciado.md),
        for (final p in promociones) ...[
          _buildTarjetaPromocion(p),
          const SizedBox(height: AppEspaciado.md),
        ],
      ],
    );
  }

  Widget _buildTarjetaPromocion(PromocionCliente p) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColores.acento.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                ),
                child: const Icon(Icons.local_offer_rounded,
                    color: AppColores.acento, size: 18),
              ),
              const SizedBox(width: AppEspaciado.sm + 2),
              Expanded(
                child: Text(
                  p.nombre,
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColores.textoPrincipal),
                ),
              ),
            ],
          ),
          if (p.descripcion != null && p.descripcion!.isNotEmpty) ...[
            const SizedBox(height: AppEspaciado.sm),
            Text(
              p.descripcion!,
              style: const TextStyle(
                  fontSize: 13,
                  height: 1.35,
                  color: AppColores.textoSecundario),
            ),
          ],
          if (p.gana.isNotEmpty)
            _bloqueReglas(
              titulo: 'Acumula puntos',
              icono: Icons.add_circle_rounded,
              color: AppColores.exito,
              reglas: [
                for (final g in p.gana)
                  _Regla(
                    texto: g.nombre,
                    puntos: '+${g.puntos} pts',
                    icono: Icons.shopping_bag_outlined,
                  ),
              ],
            ),
          if (p.canje.isNotEmpty)
            _bloqueReglas(
              titulo: 'Canjea por',
              icono: Icons.card_giftcard_rounded,
              color: AppColores.acento,
              reglas: [
                for (final c in p.canje)
                  _Regla(
                    texto: c.nombre,
                    puntos: '${c.puntos} pts',
                    icono: c.tipo == 2
                        ? Icons.card_membership_outlined
                        : Icons.redeem_outlined,
                  ),
              ],
            ),
        ],
      ),
    );
  }

  /// Bloque con fondo suave que agrupa un subtítulo y sus reglas.
  Widget _bloqueReglas({
    required String titulo,
    required IconData icono,
    required Color color,
    required List<_Regla> reglas,
  }) {
    return Container(
      margin: const EdgeInsets.only(top: AppEspaciado.md),
      padding: const EdgeInsets.all(AppEspaciado.sm + 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icono, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                titulo,
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          for (var i = 0; i < reglas.length; i++) ...[
            if (i > 0) const SizedBox(height: AppEspaciado.sm),
            _lineaRegla(regla: reglas[i], color: color),
          ],
        ],
      ),
    );
  }

  Widget _lineaRegla({required _Regla regla, required Color color}) {
    return Row(
      children: [
        Icon(regla.icono, size: 16, color: AppColores.textoSecundario),
        const SizedBox(width: AppEspaciado.sm),
        Expanded(
          child: Text(
            regla.texto,
            style: const TextStyle(
                fontSize: 13.5, color: AppColores.textoPrincipal),
          ),
        ),
        EtiquetaEstado(texto: regla.puntos, color: color),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Sección: historial de movimientos
  // ---------------------------------------------------------------------------

  Widget _buildSeccionHistorial(List<MovimientoPuntos> movimientos) {
    if (movimientos.isEmpty) {
      return const SizedBox.shrink();
    }
    // Solo renderizamos los primeros [_historialVisible] para no construir
    // cientos de filas de golpe; el resto se revela con "Ver más".
    final visibles = _historialVisible.clamp(0, movimientos.length);
    final hayMas = visibles < movimientos.length;
    final restantes = movimientos.length - visibles;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        EncabezadoSeccion(
          titulo: 'Historial',
          subtitulo: '${movimientos.length} '
              'movimiento${movimientos.length == 1 ? '' : 's'}',
        ),
        const SizedBox(height: AppEspaciado.md),
        TarjetaApp(
          padding: const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
          child: Column(
            children: [
              for (var i = 0; i < visibles; i++) ...[
                if (i > 0)
                  const Divider(color: AppColores.borde, height: 1),
                _filaMovimiento(movimientos[i]),
              ],
            ],
          ),
        ),
        if (hayMas) ...[
          const SizedBox(height: AppEspaciado.sm + 4),
          Center(
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _historialVisible += _porPagina),
              icon: const Icon(Icons.expand_more, size: 18),
              label: Text(
                'Ver más (${restantes > _porPagina ? _porPagina : restantes})',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColores.primario,
                side: const BorderSide(color: AppColores.borde),
                padding: const EdgeInsets.symmetric(
                    horizontal: AppEspaciado.lg, vertical: 10),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _filaMovimiento(MovimientoPuntos m) {
    final color = m.esGanancia ? AppColores.exito : AppColores.acento;
    final signo = m.esGanancia ? '+' : '';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppEspaciado.sm + 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              m.esGanancia
                  ? Icons.arrow_upward_rounded
                  : Icons.redeem_rounded,
              size: 18,
              color: color,
            ),
          ),
          const SizedBox(width: AppEspaciado.sm + 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.concepto,
                  style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColores.textoPrincipal),
                ),
                if (m.fecha.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatearFecha(m.fecha),
                    style: const TextStyle(
                        fontSize: 12, color: AppColores.textoSecundario),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$signo${m.puntos} pts',
            style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, color: color),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(String fecha) {
    // Backend entrega 'YYYY-MM-DD HH:MM:SS'; mostramos 'DD/MM/YYYY'.
    final soloFecha = fecha.split(' ').first;
    final partes = soloFecha.split('-');
    if (partes.length == 3) {
      return '${partes[2]}/${partes[1]}/${partes[0]}';
    }
    return fecha;
  }
}

/// Regla de una promoción (una forma de ganar o de canjear puntos).
class _Regla {
  final String texto;
  final String puntos;
  final IconData icono;

  const _Regla({
    required this.texto,
    required this.puntos,
    required this.icono,
  });
}
