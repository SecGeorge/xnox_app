import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Tarjeta de dos caras. Cada vez que sube [mediasVueltas] da media vuelta,
/// siempre en el mismo sentido: las pares muestran [frente] y las impares
/// [reverso].
class TarjetaGiratoria extends StatelessWidget {
  final int mediasVueltas;
  final Widget frente;
  final Widget reverso;

  const TarjetaGiratoria({
    super.key,
    required this.mediasVueltas,
    required this.frente,
    required this.reverso,
  });

  /// Lo que da profundidad al giro: sin perspectiva la tarjeta solo se
  /// angosta y se ensancha.
  static const _perspectiva = 0.0012;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: mediasVueltas.toDouble()),
      duration: const Duration(milliseconds: 850),
      curve: Curves.easeInOutCubic,
      builder: (context, valor, _) {
        final angulo = valor * math.pi;
        final deEspaldas = math.cos(angulo) < 0;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, _perspectiva)
            // De espaldas suma otra media vuelta para no verse en espejo.
            ..rotateY(angulo + (deEspaldas ? math.pi : 0)),
          // Las dos caras quedan montadas: al alternarlas no se recarga la foto.
          child: IndexedStack(
            index: deEspaldas ? 1 : 0,
            sizing: StackFit.expand,
            children: [frente, reverso],
          ),
        );
      },
    );
  }
}

/// Las dos caras de una tarjeta de [CuadriculaGiratoria].
class CarasTarjeta {
  final Widget frente;
  final Widget reverso;

  const CarasTarjeta({required this.frente, required this.reverso});
}

/// Tarjetas de dos en dos que giran por turnos: cada [intervalo] una vuelve a
/// su frente y la siguiente muestra el reverso. Girarlas todas a la vez marea.
///
/// Con [activa] en false se quedan quietas; también si hay otra pantalla
/// encima o el teléfono tiene las animaciones desactivadas.
class CuadriculaGiratoria extends StatefulWidget {
  final List<CarasTarjeta> tarjetas;
  final double alto;
  final double separacion;
  final bool activa;
  final Duration intervalo;

  const CuadriculaGiratoria({
    super.key,
    required this.tarjetas,
    required this.alto,
    required this.separacion,
    this.activa = true,
    this.intervalo = const Duration(milliseconds: 2800),
  });

  @override
  State<CuadriculaGiratoria> createState() => _CuadriculaGiratoriaState();
}

class _CuadriculaGiratoriaState extends State<CuadriculaGiratoria> {
  Timer? _temporizador;
  List<int> _mediasVueltas = const [];

  /// La tarjeta que está mostrando el reverso.
  int? _turno;

  @override
  void initState() {
    super.initState();
    _mediasVueltas = List.filled(widget.tarjetas.length, 0);
    _temporizador = Timer.periodic(widget.intervalo, (_) => _girar());
  }

  @override
  void didUpdateWidget(CuadriculaGiratoria oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tarjetas.length != widget.tarjetas.length) {
      _mediasVueltas = List.filled(widget.tarjetas.length, 0);
      _turno = null;
    }
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  bool get _puedeGirar =>
      widget.activa &&
      widget.tarjetas.isNotEmpty &&
      !MediaQuery.disableAnimationsOf(context) &&
      (ModalRoute.isCurrentOf(context) ?? true);

  void _girar() {
    if (!mounted || !_puedeGirar) return;
    setState(() {
      final anterior = _turno;
      if (anterior != null) _mediasVueltas[anterior]++;
      final siguiente = ((anterior ?? -1) + 1) % widget.tarjetas.length;
      _mediasVueltas[siguiente]++;
      _turno = siguiente;
    });
  }

  Widget _tarjeta(int i) => SizedBox(
    height: widget.alto,
    child: TarjetaGiratoria(
      mediasVueltas: _mediasVueltas[i],
      frente: widget.tarjetas[i].frente,
      reverso: widget.tarjetas[i].reverso,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final total = widget.tarjetas.length;
    return Column(
      children: [
        for (var i = 0; i < total; i += 2) ...[
          if (i > 0) SizedBox(height: widget.separacion),
          Row(
            children: [
              Expanded(child: _tarjeta(i)),
              SizedBox(width: widget.separacion),
              Expanded(
                child: i + 1 < total ? _tarjeta(i + 1) : const SizedBox(),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
