import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';

class VentasScreen extends StatefulWidget {
  const VentasScreen({super.key});

  @override
  State<VentasScreen> createState() => _VentasScreenState();
}

class _VentasScreenState extends State<VentasScreen> {
  int _seccion = 0; // 0 = Reportes, 1 = Ajustes

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: Column(
        children: [
          // Selector de sección estandarizado
          Padding(
            padding: const EdgeInsets.all(AppEspaciado.md),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(
                  value: 0,
                  label: Text('Reportes'),
                  icon: Icon(Icons.bar_chart),
                ),
                ButtonSegment(
                  value: 1,
                  label: Text('Ajustes'),
                  icon: Icon(Icons.tune),
                ),
              ],
              selected: {_seccion},
              onSelectionChanged: (s) => setState(() => _seccion = s.first),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? AppColores.primario
                      : AppColores.superficie,
                ),
                foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.selected)
                      ? Colors.white
                      : AppColores.textoSecundario,
                ),
              ),
            ),
          ),
          Expanded(
            child: _seccion == 0 ? _vistaReportes() : _vistaAjustes(),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- Reportes
  Widget _vistaReportes() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, 0, AppEspaciado.md, AppEspaciado.lg),
      children: [
        Row(
          children: [
            Expanded(
              child: _tarjetaResumen(
                'Ventas de hoy',
                'S/ 1,240',
                Icons.today,
                AppColores.azul,
              ),
            ),
            const SizedBox(width: AppEspaciado.sm + 4),
            Expanded(
              child: _tarjetaResumen(
                'Ventas del mes',
                'S/ 28,950',
                Icons.calendar_month,
                AppColores.verde,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.sm + 4),
        Row(
          children: [
            Expanded(
              child: _tarjetaResumen(
                'Membresías',
                'S/ 19,400',
                Icons.card_membership,
                AppColores.morado,
              ),
            ),
            const SizedBox(width: AppEspaciado.sm + 4),
            Expanded(
              child: _tarjetaResumen(
                'Productos',
                'S/ 9,550',
                Icons.shopping_bag,
                AppColores.naranja,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        const EncabezadoSeccion(
          titulo: 'Generar reporte',
          subtitulo: 'Exporta la información de ventas por periodo',
        ),
        const SizedBox(height: AppEspaciado.md),
        _itemReporte('Reporte diario', 'Resumen de ventas del día',
            Icons.description_outlined),
        const SizedBox(height: AppEspaciado.sm + 4),
        _itemReporte('Reporte mensual', 'Consolidado del mes en curso',
            Icons.insert_chart_outlined),
        const SizedBox(height: AppEspaciado.sm + 4),
        _itemReporte('Reporte por membresías', 'Ingresos por tipo de plan',
            Icons.pie_chart_outline),
      ],
    );
  }

  Widget _tarjetaResumen(
      String titulo, String valor, IconData icono, Color color) {
    return TarjetaApp(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
            ),
            child: Icon(icono, color: color, size: 22),
          ),
          const SizedBox(height: AppEspaciado.md),
          Text(
            valor,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 12.5,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemReporte(String titulo, String subtitulo, IconData icono) {
    return TarjetaApp(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Generando: $titulo')),
        );
      },
      padding: const EdgeInsets.symmetric(
          horizontal: AppEspaciado.md, vertical: AppEspaciado.sm + 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColores.primario.withValues(alpha: 0.08),
            child: Icon(icono, color: AppColores.primario, size: 22),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitulo,
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.download_rounded, color: AppColores.textoSecundario),
        ],
      ),
    );
  }

  // ----------------------------------------------------------------- Ajustes
  Widget _vistaAjustes() {
    final ajustes = [
      (_AjusteItem('Métodos de pago', 'Efectivo, tarjeta, transferencia',
          Icons.payments_outlined)),
      (_AjusteItem('Impuestos (IGV)', 'Configura el porcentaje aplicado',
          Icons.percent)),
      (_AjusteItem('Descuentos', 'Promociones y cupones activos',
          Icons.local_offer_outlined)),
      (_AjusteItem('Comprobantes', 'Series de boletas y facturas',
          Icons.receipt_long_outlined)),
      (_AjusteItem('Anulaciones', 'Política de anulación de ventas',
          Icons.cancel_outlined)),
    ];

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
          AppEspaciado.md, 0, AppEspaciado.md, AppEspaciado.lg),
      itemCount: ajustes.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppEspaciado.sm + 4),
      itemBuilder: (_, i) {
        final a = ajustes[i];
        return TarjetaApp(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Abriendo: ${a.titulo}')),
            );
          },
          padding: const EdgeInsets.symmetric(
              horizontal: AppEspaciado.md, vertical: AppEspaciado.sm + 4),
          child: Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColores.acento.withValues(alpha: 0.10),
                child: Icon(a.icono, color: AppColores.acento, size: 22),
              ),
              const SizedBox(width: AppEspaciado.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      a.titulo,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      a.subtitulo,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColores.textoSecundario),
            ],
          ),
        );
      },
    );
  }
}

class _AjusteItem {
  final String titulo;
  final String subtitulo;
  final IconData icono;
  _AjusteItem(this.titulo, this.subtitulo, this.icono);
}
