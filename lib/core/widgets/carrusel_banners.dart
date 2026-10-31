import 'dart:async';

import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Banners que pasan solos y se pueden deslizar con el dedo. Del último vuelve
/// al primero, y con uno solo no hay nada que pasar.
///
/// Con [activo] en false se detiene; también mientras el socio lo desliza, si
/// hay otra pantalla encima o el teléfono tiene las animaciones desactivadas.
class CarruselBanners extends StatefulWidget {
  final int cantidad;
  final double alto;
  final IndexedWidgetBuilder constructor;
  final bool activo;
  final Duration intervalo;

  const CarruselBanners({
    super.key,
    required this.cantidad,
    required this.alto,
    required this.constructor,
    this.activo = true,
    this.intervalo = const Duration(seconds: 5),
  });

  @override
  State<CarruselBanners> createState() => _CarruselBannersState();
}

class _CarruselBannersState extends State<CarruselBanners> {
  // Algo menos que el ancho: asoma el siguiente y se nota que hay más.
  final _paginas = PageController(viewportFraction: 0.93);
  Timer? _temporizador;
  int _pagina = 0;
  bool _arrastrando = false;

  @override
  void initState() {
    super.initState();
    _temporizador = Timer.periodic(widget.intervalo, (_) => _pasar());
  }

  @override
  void dispose() {
    _temporizador?.cancel();
    _paginas.dispose();
    super.dispose();
  }

  void _pasar() {
    if (!mounted ||
        !widget.activo ||
        widget.cantidad < 2 ||
        _arrastrando ||
        !_paginas.hasClients ||
        MediaQuery.disableAnimationsOf(context) ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    _paginas.animateToPage(
      (_pagina + 1) % widget.cantidad,
      duration: const Duration(milliseconds: 550),
      curve: Curves.easeInOutCubic,
    );
  }

  bool _alDeslizar(ScrollNotification n) {
    if (n is ScrollStartNotification && n.dragDetails != null) {
      _arrastrando = true;
    } else if (n is ScrollEndNotification) {
      _arrastrando = false;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.cantidad == 1) {
      return SizedBox(
        height: widget.alto,
        child: widget.constructor(context, 0),
      );
    }
    return Column(
      children: [
        SizedBox(
          height: widget.alto,
          child: NotificationListener<ScrollNotification>(
            onNotification: _alDeslizar,
            child: PageView.builder(
              controller: _paginas,
              itemCount: widget.cantidad,
              padEnds: false,
              onPageChanged: (p) => setState(() => _pagina = p),
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(right: AppEspaciado.sm + 2),
                child: widget.constructor(context, i),
              ),
            ),
          ),
        ),
        const SizedBox(height: AppEspaciado.sm + 4),
        _indicador(),
      ],
    );
  }

  /// Barritas inclinadas como las letras del logo.
  Widget _indicador() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < widget.cantidad; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.skewX(-0.4),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: i == _pagina ? 22 : 10,
                height: 4,
                color: i == _pagina
                    ? AppColores.primario
                    : AppColores.primario.withValues(alpha: 0.2),
              ),
            ),
          ),
      ],
    );
  }
}
