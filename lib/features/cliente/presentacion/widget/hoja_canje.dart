import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_promociones.dart';

/// Abre una hoja inferior con el catálogo de canje y permite redimir puntos.
/// Devuelve `true` si se realizó al menos un canje (para que el llamador
/// recargue su saldo).
Future<bool> mostrarHojaCanje(
  BuildContext context, {
  required ResumenPuntos resumen,
}) async {
  final resultado = await mostrarHojaModerna<bool>(
    context,
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
      mostrarMensaje(
        context,
        'No te alcanzan los puntos',
        tipo: TipoMensaje.advertencia,
      );
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
    mostrarMensaje(
      context,
      r.mensaje,
      tipo: r.exito ? TipoMensaje.exito : TipoMensaje.advertencia,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (hecho, _) {
        if (!hecho) Navigator.of(context).pop(_huboCanje);
      },
      child: HojaModerna(
        icono: Icons.card_giftcard_rounded,
        titulo: 'Canjear puntos',
        subtitulo: 'Elige tu premio',
        accion: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: AppColores.naranja.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.stars_rounded,
                size: 16,
                color: AppColores.naranja,
              ),
              const SizedBox(width: 4),
              Text(
                '$_saldo pts',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: AppColores.naranja,
                ),
              ),
            ],
          ),
        ),
        child: _items.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: EstadoVacio(
                  icono: Icons.card_giftcard_outlined,
                  mensaje: 'No hay premios para canjear por ahora',
                ),
              )
            : Column(children: [for (final it in _items) _fila(it)]),
      ),
    );
  }

  Widget _fila(LineaCanje item) {
    final alcanza = _saldo >= item.puntos;
    final procesando = _procesandoId == item.id;
    final avance = item.puntos == 0
        ? 1.0
        : (_saldo / item.puntos).clamp(0.0, 1.0);
    final color = item.esMembresia ? AppColores.morado : AppColores.primario;
    return Container(
      margin: const EdgeInsets.only(bottom: AppEspaciado.sm + 2),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColores.fondo,
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        border: Border.all(
          color: alcanza ? color.withValues(alpha: 0.35) : AppColores.borde,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                ),
                child: Icon(
                  item.esMembresia
                      ? Icons.card_membership_rounded
                      : Icons.redeem_rounded,
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.nombre,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    Text(
                      item.esMembresia ? 'Membresía' : 'Producto',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${item.puntos} pts',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: alcanza
                    ? const Text(
                        '¡Te alcanza!',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppColores.exito,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Te faltan ${item.puntos - _saldo} pts',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColores.textoSecundario,
                            ),
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
                            child: LinearProgressIndicator(
                              value: avance,
                              minHeight: 5,
                              color: color,
                              backgroundColor: color.withValues(alpha: 0.12),
                            ),
                          ),
                        ],
                      ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  onPressed: (!alcanza || procesando)
                      ? null
                      : () => _canjear(item),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                  ),
                  child: procesando
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColores.sobreRelleno,
                          ),
                        )
                      : const Text('Canjear', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
