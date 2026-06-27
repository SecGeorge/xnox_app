import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/pagos/dominio/entidades/resumen_pagos.dart';
import 'package:xnox_app/features/pagos/presentacion/controlador/controlador_pagos.dart';
import 'package:xnox_app/features/pagos/presentacion/widget/grafico_barra.dart';

/// Pantalla de Pagos (membresías del gimnasio): KPIs de cobranza y gráficos,
/// equivalente al dashboard web `InicioComponent.vue`.
class PagosScreen extends StatefulWidget {
  const PagosScreen({super.key});

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  final _controlador = ControladorPagos();
  ResumenPagos? _resumen;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _cargando = true);
    try {
      final resumen = await _controlador.obtenerResumen();
      if (!mounted) return;
      setState(() {
        _resumen = resumen;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _cargando = false);
      mostrarMensaje(context, 'No se pudieron cargar los pagos',
          tipo: TipoMensaje.error);
    }
  }

  String _soles(double valor) =>
      'S/ ${NumberFormat('#,##0', 'es').format(valor)}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColores.fondo,
      appBar: AppBar(title: const Text('Pagos')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargarDatos,
              child: _resumen == null ? _vistaError() : _vistaContenido(_resumen!),
            ),
    );
  }

  Widget _vistaError() {
    return ListView(
      children: const [
        SizedBox(height: 120),
        EstadoVacio(
          icono: Icons.error_outline,
          mensaje: 'No se pudo cargar la información de pagos.\nDesliza para reintentar.',
        ),
      ],
    );
  }

  Widget _vistaContenido(ResumenPagos r) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, AppEspaciado.lg),
      children: [
        _gridKpis(r),
        const SizedBox(height: AppEspaciado.md),
        _tarjetaGrafico(
          titulo: 'Pagos de la semana',
          subtitulo: 'Pagos registrados por día en la semana actual',
          child: GraficoBarra(
            datos: r.serieSemana,
            colorInicio: const Color(0xFF34D399),
            colorFin: AppColores.verde,
            formatoValor: _soles,
          ),
        ),
        const SizedBox(height: AppEspaciado.md),
        _tarjetaGrafico(
          titulo: 'Pagos por mes',
          subtitulo: 'Evolución de ingresos durante el año',
          child: GraficoBarra(
            datos: r.serieMeses,
            colorInicio: const Color(0xFFFBBF24),
            colorFin: AppColores.naranja,
            formatoValor: _soles,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------------- KPIs
  Widget _gridKpis(ResumenPagos r) {
    final tarjetas = [
      _Kpi('Total pagos', _soles(r.totalPagos), Icons.account_balance_wallet,
          AppColores.azul),
      _Kpi('Pagos hoy', _soles(r.pagosHoy), Icons.today, AppColores.acento),
      _Kpi('Pagos semana', _soles(r.pagosSemana), Icons.date_range,
          AppColores.verde),
      _Kpi('Pagos mes', _soles(r.pagosMes), Icons.calendar_month,
          AppColores.naranja),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: AppEspaciado.sm + 4,
      crossAxisSpacing: AppEspaciado.sm + 4,
      childAspectRatio: 1.35,
      children: tarjetas.map(_tarjetaKpi).toList(),
    );
  }

  Widget _tarjetaKpi(_Kpi kpi) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: kpi.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Icon(kpi.icono, color: kpi.color, size: 22),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  kpi.valor,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoPrincipal,
                  ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                kpi.titulo,
                style: const TextStyle(
                  fontSize: 12.5,
                  color: AppColores.textoSecundario,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ Charts
  Widget _tarjetaGrafico({
    required String titulo,
    required String subtitulo,
    required Widget child,
  }) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EncabezadoSeccion(titulo: titulo, subtitulo: subtitulo),
          const SizedBox(height: AppEspaciado.md),
          child,
        ],
      ),
    );
  }
}

class _Kpi {
  final String titulo;
  final String valor;
  final IconData icono;
  final Color color;
  _Kpi(this.titulo, this.valor, this.icono, this.color);
}
