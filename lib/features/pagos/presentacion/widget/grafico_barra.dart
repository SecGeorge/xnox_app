import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';

/// Gráfico de barras con widgets: cada barra va sobre un carril tenue, con el
/// valor encima y la etiqueta abajo. La barra [resaltado] (hoy, el mes actual)
/// va en color sólido; el resto, en el mismo color más suave.
class GraficoBarra extends StatelessWidget {
  final List<BarraPago> datos;
  final Color color;
  final double altura;

  /// Índice de la barra a destacar (o null).
  final int? resaltado;

  /// Mensaje cuando no hay valores.
  final String textoVacio;

  /// Formatea el valor mostrado encima de cada barra (p. ej. "S/ 540").
  final String Function(double) formatoValor;

  const GraficoBarra({
    super.key,
    required this.datos,
    required this.formatoValor,
    this.color = AppColores.verde,
    this.altura = 180,
    this.resaltado,
    this.textoVacio = 'Sin pagos en el periodo',
  });

  @override
  Widget build(BuildContext context) {
    final sinDatos = datos.isEmpty || datos.every((d) => d.total <= 0);
    if (sinDatos) {
      return SizedBox(
        height: altura * 0.6,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bar_chart_rounded,
              size: 34,
              color: color.withValues(alpha: 0.35),
            ),
            const SizedBox(height: 6),
            Text(
              textoVacio,
              style: TextStyle(fontSize: 13, color: AppColores.textoSecundario),
            ),
          ],
        ),
      );
    }

    final maximo = datos
        .map((d) => d.total)
        .fold<double>(0, (a, b) => b > a ? b : a);
    return SizedBox(
      height: altura,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < datos.length; i++)
            Expanded(child: _barra(datos[i], maximo, i == resaltado)),
        ],
      ),
    );
  }

  Widget _barra(BarraPago d, double maximo, bool activo) {
    final fraccion = maximo <= 0 ? 0.0 : (d.total / maximo).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 3),
      child: Column(
        children: [
          SizedBox(
            height: 16,
            child: d.total > 0
                ? FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      formatoValor(d.total),
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: activo ? FontWeight.w800 : FontWeight.w600,
                        color: activo ? color : AppColores.textoSecundario,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Container(
              width: double.infinity,
              alignment: Alignment.bottomCenter,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: FractionallySizedBox(
                heightFactor: d.total > 0 ? fraccion.clamp(0.06, 1.0) : 0,
                widthFactor: 1,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: activo
                          ? [color.withValues(alpha: 0.75), color]
                          : [
                              color.withValues(alpha: 0.28),
                              color.withValues(alpha: 0.42),
                            ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          // FittedBox: "Antes" o "Desp." no caben en barras angostas.
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              d.etiqueta,
              maxLines: 1,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: activo ? FontWeight.w800 : FontWeight.w500,
                color: activo
                    ? AppColores.textoPrincipal
                    : AppColores.textoSecundario,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
