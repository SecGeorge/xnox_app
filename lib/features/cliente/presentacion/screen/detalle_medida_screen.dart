import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/datos/almacen_medidas.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/medida.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/grafico_evolucion.dart';
import 'package:xnox_app/features/cliente/presentacion/widget/hoja_numero.dart';

/// Una zona del cuerpo: foto, medida actual, gráfico de evolución e historial.
class DetalleMedidaScreen extends StatefulWidget {
  final ZonaMedida zona;

  const DetalleMedidaScreen({super.key, required this.zona});

  @override
  State<DetalleMedidaScreen> createState() => _DetalleMedidaScreenState();
}

class _DetalleMedidaScreenState extends State<DetalleMedidaScreen> {
  List<Medida> _registros = const [];

  ZonaMedida get _zona => widget.zona;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final todas = await AlmacenMedidas.instancia.listar();
    if (!mounted) return;
    setState(() {
      _registros = todas.where((m) => m.zona == _zona.clave).toList();
    });
  }

  Future<void> _registrar() async {
    final ultima = _registros.isEmpty ? null : _registros.last.valor;
    final valor = await pedirNumero(
      context,
      titulo: _zona.nombre,
      subtitulo: 'Nueva medida de hoy',
      icono: _zona.icono,
      unidad: _zona.unidad,
      inicial: ultima,
      paso: 0.5,
      decimales: true,
      atajos: [if (ultima != null) AtajoNumero('Última', ultima)],
      textoGuardar: 'Guardar medida',
    );
    if (valor == null) return;
    await AlmacenMedidas.instancia.registrar(_zona.clave, valor);
    await _cargar();
  }

  Future<void> _eliminar(Medida m) async {
    final ok = await confirmarDialog(
      context,
      titulo: 'Eliminar medida',
      mensaje:
          '¿Eliminar ${numeroMedida(m.valor)} ${_zona.unidad} del '
          '${DateFormat("d 'de' MMMM", 'es').format(m.fecha)}?',
      icono: Icons.delete_outline_rounded,
      textoConfirmar: 'Eliminar',
      peligro: true,
    );
    if (!ok) return;
    await AlmacenMedidas.instancia.eliminar(m.id);
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    final actual = _registros.isEmpty ? null : _registros.last;
    final primera = _registros.isEmpty ? null : _registros.first;
    final cambio = _registros.length < 2
        ? null
        : _registros.last.valor - _registros.first.valor;

    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: AppEspaciado.lg,
      pie: PieBoton(
        texto: 'Registrar medida',
        icono: Icons.straighten_rounded,
        onPressed: _registrar,
      ),
      children: [
        CabeceraApp(
          titulo: _zona.nombre,
          subtitulo: 'Medida en ${_zona.unidad == 'kg' ? 'kilos' : 'centímetros'}',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: _zona.foto,
          alineacion: _zona.alineacion,
          altura: 180,
          etiqueta: 'Medida actual',
          titulo: actual == null
              ? 'Sin medir'
              : '${numeroMedida(actual.valor)} ${_zona.unidad}',
          pie: Row(
            children: [
              DatoPortada(
                icono: Icons.flag_rounded,
                valor: primera == null
                    ? '—'
                    : '${numeroMedida(primera.valor)} ${_zona.unidad}',
                pie: 'al inicio',
              ),
              const SizedBox(width: 18),
              // Solo dos datos: con un tercero la fila se desbordaba en
              // pantallas angostas.
              DatoPortada(
                icono: (cambio ?? 0) < 0
                    ? Icons.trending_down_rounded
                    : Icons.trending_up_rounded,
                valor: cambio == null
                    ? '—'
                    : '${cambio > 0 ? '+' : ''}${numeroMedida(cambio)} ${_zona.unidad}',
                pie: 'cambio total',
              ),
            ],
          ),
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.show_chart_rounded,
          titulo: 'Tu evolución',
        ),
        GraficoEvolucion(
          puntos: [for (final m in _registros) PuntoEvolucion(m.fecha, m.valor)],
          unidad: _zona.unidad,
          mejorSiSube: switch (_zona.tendencia) {
            TendenciaMedida.subir => true,
            TendenciaMedida.bajar => false,
            TendenciaMedida.neutral => null,
          },
          textoVacio: 'Registra tu primera medida y aparecerá aquí',
          textoUnPunto: 'Registra otra medida para ver tu curva',
        ),
        const SizedBox(height: AppEspaciado.lg),
        TituloSeccion(
          icono: Icons.history_rounded,
          titulo: 'Historial',
          detalle: _registros.isEmpty ? null : '${_registros.length}',
        ),
        if (_registros.isEmpty)
          VacioApp(
            icono: _zona.icono,
            titulo: 'Aún no tienes medidas',
            texto:
                'Mídete con cinta métrica y toca "Registrar medida". '
                'Repite cada 2 a 4 semanas.',
          )
        else
          GrupoFilas(
            filas: [
              // La más reciente arriba.
              for (var i = _registros.length - 1; i >= 0; i--)
                _fila(_registros[i], i == 0 ? null : _registros[i - 1]),
            ],
          ),
      ],
    );
  }

  Widget _fila(Medida m, Medida? anterior) {
    final diferencia = anterior == null ? null : m.valor - anterior.valor;
    return FilaApp(
      inicio: IconoSuave(_zona.icono),
      titulo: '${numeroMedida(m.valor)} ${_zona.unidad}',
      subtitulo: [
        DateFormat("d 'de' MMMM yyyy", 'es').format(m.fecha),
        if (diferencia != null && diferencia != 0)
          '${diferencia > 0 ? '+' : ''}${numeroMedida(diferencia)} ${_zona.unidad}',
      ].join(' · '),
      fin: IconButton(
        tooltip: 'Eliminar',
        onPressed: () => _eliminar(m),
        icon: const Icon(
          Icons.delete_outline_rounded,
          color: AppColores.textoSecundario,
        ),
      ),
    );
  }
}
