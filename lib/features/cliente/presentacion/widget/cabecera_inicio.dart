import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Saludo según la hora del teléfono.
String saludoPorHora(DateTime ahora) {
  if (ahora.hour < 5 || ahora.hour >= 19) return 'Buenas noches';
  return ahora.hour < 12 ? 'Buenos días' : 'Buenas tardes';
}

/// Un dato del socio para la franja de la cabecera.
class MensajeCabecera {
  final String emoji;
  final String texto;
  final VoidCallback onTap;

  const MensajeCabecera(this.emoji, this.texto, this.onTap);
}

/// Franja que va pasando los datos del socio (racha, membresía, puntos...).
/// Tocarla lleva a lo que dice el mensaje de ese momento.
///
/// Con [activa] en false se queda en el mensaje actual; también si hay otra
/// pantalla encima o el teléfono tiene las animaciones desactivadas.
class FranjaMensajes extends StatefulWidget {
  final List<MensajeCabecera> mensajes;
  final bool activa;
  final Duration intervalo;

  const FranjaMensajes({
    super.key,
    required this.mensajes,
    this.activa = true,
    this.intervalo = const Duration(seconds: 4),
  });

  @override
  State<FranjaMensajes> createState() => _FranjaMensajesState();
}

class _FranjaMensajesState extends State<FranjaMensajes> {
  Timer? _temporizador;
  int _turno = 0;

  // La lista cambia cuando llegan los datos: el turno puede quedar fuera.
  int get _indice => _turno % widget.mensajes.length;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(widget.intervalo, (_) => _pasar());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    super.dispose();
  }

  void _pasar() {
    if (!mounted ||
        !widget.activa ||
        widget.mensajes.length < 2 ||
        MediaQuery.disableAnimationsOf(context) ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    setState(() => _turno = _indice + 1);
  }

  /// El que entra sube desde abajo y el que sale se va por arriba.
  Widget _transicion(
    Widget hijo,
    Animation<double> animacion,
    Key claveActual,
  ) {
    final desde = Offset(0, hijo.key == claveActual ? 0.8 : -0.8);
    return FadeTransition(
      opacity: animacion,
      child: SlideTransition(
        position: Tween(begin: desde, end: Offset.zero).animate(animacion),
        child: hijo,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mensaje = widget.mensajes[_indice];
    final clave = ValueKey(mensaje.texto);
    final radio = BorderRadius.circular(AppEspaciado.radioSm + 2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radio,
        onTap: mensaje.onTap,
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            gradient: AppColores.degradadoRelleno,
            border: AppColores.bordeCabecera,
            borderRadius: radio,
          ),
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Row(
            children: [
              Expanded(
                child: ClipRect(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 380),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (hijo, animacion) =>
                        _transicion(hijo, animacion, clave),
                    layoutBuilder: (actual, anteriores) => Stack(
                      alignment: Alignment.centerLeft,
                      children: [...anteriores, ?actual],
                    ),
                    child: _Mensaje(mensaje, key: clave),
                  ),
                ),
              ),
              if (widget.mensajes.length > 1) ...[
                const SizedBox(width: AppEspaciado.sm),
                for (var i = 0; i < widget.mensajes.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: 5,
                    height: i == _indice ? 14 : 5,
                    margin: const EdgeInsets.only(left: 3),
                    decoration: BoxDecoration(
                      color: AppColores.sobreRelleno.withValues(
                        alpha: i == _indice ? 1 : 0.3,
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
              Icon(
                Icons.chevron_right_rounded,
                size: 22,
                color: AppColores.sobreRelleno,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Mensaje extends StatelessWidget {
  final MensajeCabecera mensaje;

  const _Mensaje(this.mensaje, {super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(mensaje.emoji, style: const TextStyle(fontSize: 18)),
        const SizedBox(width: AppEspaciado.sm + 2),
        Expanded(
          child: Text(
            mensaje.texto,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: AppColores.sobreRelleno,
            ),
          ),
        ),
      ],
    );
  }
}
