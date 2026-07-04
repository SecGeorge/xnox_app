import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_membresia.dart';
import 'package:xnox_app/features/pago_yape/presentacion/pago_yape_screen.dart';

/// Muestra la membresía del cliente: plan, estado, vencimiento y saldo.
class MembresiaScreen extends StatefulWidget {
  const MembresiaScreen({super.key});

  @override
  State<MembresiaScreen> createState() => _MembresiaScreenState();
}

class _MembresiaScreenState extends State<MembresiaScreen> {
  final _controlador = ControladorMembresia();
  MembresiaCliente? _membresia;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _isLoading = true);
    final m = await _controlador.obtenerMembresia();
    if (!mounted) return;
    setState(() {
      _membresia = m;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final m = _membresia;
    return SafeArea(
      child: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: m == null
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        EstadoVacio(
                          icono: Icons.card_membership_outlined,
                          mensaje: 'No tienes una membresía registrada',
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(AppEspaciado.md),
                      children: [
                        const SizedBox(height: AppEspaciado.sm),
                        const Text(
                          'Mi Membresía',
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: AppColores.textoPrincipal),
                        ),
                        const SizedBox(height: AppEspaciado.lg),
                        _buildTarjetaPlan(m),
                        const SizedBox(height: AppEspaciado.md),
                        _buildDetalles(m),
                        if (m.tieneDeuda) ...[
                          const SizedBox(height: AppEspaciado.md),
                          _buildBotonPagar(m),
                        ],
                      ],
                    ),
            ),
    );
  }

  Widget _buildTarjetaPlan(MembresiaCliente m) {
    return Container(
      padding: const EdgeInsets.all(AppEspaciado.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColores.primario, AppColores.primarioClaro],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        boxShadow: AppSombras.tarjeta,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Plan actual',
                  style: TextStyle(color: Colors.white70, fontSize: 13)),
              EtiquetaEstado(
                  texto: m.estado.etiqueta, color: m.estado.color),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.plan,
            style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(m.nombre,
              style: const TextStyle(color: Colors.white70, fontSize: 14)),
          const SizedBox(height: AppEspaciado.lg),
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Text(
                m.diasRestantes >= 0
                    ? 'Vence en ${m.diasRestantes} días'
                    : 'Venció hace ${m.diasRestantes.abs()} días',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBotonPagar(MembresiaCliente m) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PagoYapeScreen(
                monto: m.saldoPendiente,
                concepto: 'Membresía: ${m.plan}',
                contratoId: m.contratoId,
              ),
            ),
          );
          // Al volver, refrescamos por si el gimnasio ya confirmó el pago.
          _cargar();
        },
        icon: const Icon(Icons.account_balance_wallet),
        label: Text('Pagar por Yape  ·  ${NumberFormat('#,##0.00', 'es').format(m.saldoPendiente)}'),
      ),
    );
  }

  Widget _buildDetalles(MembresiaCliente m) {
    final f = DateFormat('d MMM yyyy', 'es');
    return TarjetaApp(
      child: Column(
        children: [
          _fila(Icons.event_available_outlined, 'Inicio',
              f.format(m.fechaInicio)),
          const Divider(height: AppEspaciado.lg, color: AppColores.borde),
          _fila(Icons.event_busy_outlined, 'Vencimiento',
              f.format(m.fechaVencimiento)),
          const Divider(height: AppEspaciado.lg, color: AppColores.borde),
          _fila(
            Icons.account_balance_wallet_outlined,
            'Saldo pendiente',
            m.tieneDeuda
                ? 'S/ ${NumberFormat('#,##0.00', 'es').format(m.saldoPendiente)}'
                : 'Al día',
            valorColor: m.tieneDeuda ? AppColores.moroso : AppColores.activo,
          ),
        ],
      ),
    );
  }

  Widget _fila(IconData icono, String titulo, String valor,
      {Color? valorColor}) {
    return Row(
      children: [
        Icon(icono, size: 20, color: AppColores.textoSecundario),
        const SizedBox(width: AppEspaciado.md),
        Expanded(
          child: Text(titulo,
              style: const TextStyle(
                  fontSize: 14, color: AppColores.textoSecundario)),
        ),
        Text(
          valor,
          style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w700,
              color: valorColor ?? AppColores.textoPrincipal),
        ),
      ],
    );
  }
}
