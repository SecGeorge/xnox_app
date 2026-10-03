import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/hoja_canje.dart';

/// Hoja inferior "Mis puntos": saldo, acceso al canje e historial de
/// movimientos. Concentra en un solo lugar el detalle de fidelidad del
/// cliente (reemplaza la antigua pantalla de Promociones).
Future<void> mostrarHojaMisPuntos(
  BuildContext context, {
  required ResumenPuntos resumen,
}) async {
  await mostrarHojaModerna<void>(
    context,
    builder: (_) => _HojaMisPuntos(resumenInicial: resumen),
  );
}

class _HojaMisPuntos extends StatefulWidget {
  final ResumenPuntos resumenInicial;

  const _HojaMisPuntos({required this.resumenInicial});

  @override
  State<_HojaMisPuntos> createState() => _HojaMisPuntosState();
}

class _HojaMisPuntosState extends State<_HojaMisPuntos> {
  final _controlador = ControladorPromociones();
  late ResumenPuntos _resumen;

  @override
  void initState() {
    super.initState();
    _resumen = widget.resumenInicial;
  }

  Future<void> _refrescar() async {
    try {
      final r = await _controlador.obtenerResumen();
      if (!mounted) return;
      setState(() => _resumen = r);
    } catch (_) {
      /* silencioso */
    }
  }

  Future<void> _abrirCanje() async {
    await mostrarHojaCanje(context, resumen: _resumen);
    await _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final movimientos = _resumen.movimientos;
    return HojaModerna(
      icono: Icons.stars_rounded,
      titulo: 'Mis puntos',
      subtitulo: 'Gana con cada compra y canjéalos por premios',
      accion: IconButton(
        onPressed: () => Navigator.pop(context),
        icon: const Icon(
          Icons.close_rounded,
          color: AppColores.textoSecundario,
        ),
      ),
      pie: _resumen.canje.isEmpty
          ? null
          : BotonHoja(
              texto: 'Canjear mis puntos',
              icono: Icons.card_giftcard_rounded,
              onPressed: _abrirCanje,
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _tarjetaSaldo(_resumen.saldo),
          const SizedBox(height: AppEspaciado.lg),
          Text(
            'HISTORIAL',
            style: const TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.3,
              fontWeight: FontWeight.w700,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          if (movimientos.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: EstadoVacio(
                icono: Icons.history,
                mensaje: 'Aún no tienes movimientos de puntos',
              ),
            )
          else
            Container(
              decoration: BoxDecoration(
                color: AppColores.fondo,
                borderRadius: BorderRadius.circular(AppEspaciado.radio),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Column(
                children: [
                  for (var i = 0; i < movimientos.length; i++) ...[
                    if (i > 0) Divider(color: AppColores.borde, height: 1),
                    _filaMovimiento(movimientos[i]),
                  ],
                ],
              ),
            ),
          const SizedBox(height: AppEspaciado.sm),
        ],
      ),
    );
  }

  Widget _tarjetaSaldo(int saldo) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppEspaciado.md,
        vertical: AppEspaciado.md,
      ),
      decoration: BoxDecoration(
        gradient: AppColores.degradadoRelleno,
        border: AppColores.bordeCabecera,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColores.sobreRelleno.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Icon(
              Icons.stars_rounded,
              color: AppColores.sobreRelleno,
              size: 24,
            ),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Text(
              'Saldo disponible',
              style: TextStyle(
                color: AppColores.sobreRellenoSuave,
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
                style: TextStyle(
                  color: AppColores.sobreRelleno,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                'pts',
                style: TextStyle(
                  color: AppColores.sobreRellenoSuave,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ],
      ),
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
              m.esGanancia ? Icons.arrow_upward_rounded : Icons.redeem_rounded,
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
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                if (m.fecha.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _formatearFecha(m.fecha),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Text(
            '$signo${m.puntos} pts',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: color,
            ),
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
