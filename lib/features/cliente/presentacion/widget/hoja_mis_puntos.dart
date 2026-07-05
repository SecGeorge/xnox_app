import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
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
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColores.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
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
    } catch (_) {/* silencioso */}
  }

  Future<void> _abrirCanje() async {
    await mostrarHojaCanje(context, resumen: _resumen);
    await _refrescar();
  }

  @override
  Widget build(BuildContext context) {
    final movimientos = _resumen.movimientos;
    return ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          left: AppEspaciado.md,
          right: AppEspaciado.md,
          top: AppEspaciado.sm,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppEspaciado.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Asa de la hoja.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppEspaciado.md),
                decoration: BoxDecoration(
                  color: AppColores.borde,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),

            _tarjetaSaldo(_resumen.saldo),

            if (_resumen.canje.isNotEmpty) ...[
              const SizedBox(height: AppEspaciado.sm + 4),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _abrirCanje,
                  icon: const Icon(Icons.card_giftcard_rounded, size: 18),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColores.acento,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  label: const Text('Canjear mis puntos'),
                ),
              ),
            ],

            const SizedBox(height: AppEspaciado.lg),
            const Text(
              'Historial',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColores.textoPrincipal,
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
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: movimientos.length,
                  separatorBuilder: (_, _) =>
                      const Divider(color: AppColores.borde, height: 1),
                  itemBuilder: (_, i) => _filaMovimiento(movimientos[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _tarjetaSaldo(int saldo) {
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
            child:
                const Icon(Icons.stars_rounded, color: Colors.white, size: 24),
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
              const Text('pts',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
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
