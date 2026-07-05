import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';

/// Abre una hoja inferior con el catálogo de canje y permite redimir puntos.
/// Devuelve `true` si se realizó al menos un canje (para que el llamador
/// recargue su saldo).
Future<bool> mostrarHojaCanje(
  BuildContext context, {
  required ResumenPuntos resumen,
}) async {
  final resultado = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColores.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaCanje(resumenInicial: resumen),
  );
  return resultado ?? false;
}

class _HojaCanje extends StatefulWidget {
  final ResumenPuntos resumenInicial;

  const _HojaCanje({required this.resumenInicial});

  @override
  State<_HojaCanje> createState() => _HojaCanjeState();
}

class _HojaCanjeState extends State<_HojaCanje> {
  final _controlador = ControladorPromociones();

  late int _saldo;
  late List<LineaCanje> _items;
  int? _procesandoId;
  bool _huboCanje = false;

  @override
  void initState() {
    super.initState();
    _saldo = widget.resumenInicial.saldo;
    _items = widget.resumenInicial.canje;
  }

  Future<void> _canjear(LineaCanje item) async {
    if (_saldo < item.puntos) {
      mostrarMensaje(context, 'No te alcanzan los puntos',
          tipo: TipoMensaje.advertencia);
      return;
    }
    setState(() => _procesandoId = item.id);
    final r = await _controlador.canjear(item.id);
    if (!mounted) return;
    setState(() {
      _procesandoId = null;
      if (r.exito) {
        _huboCanje = true;
        if (r.saldo != null) _saldo = r.saldo!;
      }
    });
    mostrarMensaje(context, r.mensaje,
        tipo: r.exito ? TipoMensaje.exito : TipoMensaje.advertencia);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: AppEspaciado.md,
        right: AppEspaciado.md,
        top: AppEspaciado.md,
        bottom: MediaQuery.of(context).viewInsets.bottom + AppEspaciado.md,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Encabezado con saldo.
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColores.acento.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                ),
                child: const Icon(Icons.card_giftcard_rounded,
                    color: AppColores.acento, size: 20),
              ),
              const SizedBox(width: AppEspaciado.sm + 2),
              const Expanded(
                child: Text(
                  'Canjear con puntos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              EtiquetaEstado(texto: '$_saldo pts', color: AppColores.primario),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),

          if (_items.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: EstadoVacio(
                icono: Icons.card_giftcard_outlined,
                mensaje: 'No hay items para canjear por ahora',
              ),
            )
          else
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(height: 16),
                itemBuilder: (_, i) => _fila(_items[i]),
              ),
            ),

          const SizedBox(height: AppEspaciado.sm),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.of(context).pop(_huboCanje),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fila(LineaCanje item) {
    final alcanza = _saldo >= item.puntos;
    final procesando = _procesandoId == item.id;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: (item.esMembresia ? AppColores.morado : AppColores.acento)
                .withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(
            item.esMembresia
                ? Icons.card_membership_outlined
                : Icons.redeem_outlined,
            size: 18,
            color: item.esMembresia ? AppColores.morado : AppColores.acento,
          ),
        ),
        const SizedBox(width: AppEspaciado.sm + 2),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.nombre,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.puntos} pts',
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: AppColores.acento),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppEspaciado.sm),
        SizedBox(
          height: 34,
          child: ElevatedButton(
            onPressed: (!alcanza || procesando) ? null : () => _canjear(item),
            style: ElevatedButton.styleFrom(
              padding:
                  const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
              backgroundColor: AppColores.acento,
              disabledBackgroundColor: AppColores.borde,
            ),
            child: procesando
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Text(alcanza ? 'Canjear' : 'Faltan pts',
                    style: const TextStyle(fontSize: 12.5)),
          ),
        ),
      ],
    );
  }
}
