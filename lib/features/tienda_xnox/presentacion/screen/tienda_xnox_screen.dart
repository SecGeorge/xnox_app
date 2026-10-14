import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/campana_avisos.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/tienda_xnox/datos/repositorio_tienda_xnox.dart';
import 'package:xnox_app/features/tienda_xnox/dominio/producto_xnox.dart';
import 'package:xnox_app/features/tienda_xnox/presentacion/widget/piezas_tienda_xnox.dart';

/// Sección "Tienda XNOX" del personal: productos que XNOX ofrece a los
/// gimnasios (equipos, accesorios, servicios…). No es la tienda del gimnasio:
/// se piden a XNOX por WhatsApp o por su enlace.
class TiendaXnoxScreen extends StatefulWidget {
  const TiendaXnoxScreen({super.key});

  @override
  State<TiendaXnoxScreen> createState() => _TiendaXnoxScreenState();
}

class _TiendaXnoxScreenState extends State<TiendaXnoxScreen> {
  List<ProductoXnox> _productos = const [];
  bool _cargando = true;
  bool _error = false;
  String _busqueda = '';
  String? _categoria; // null = todas

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = false;
    });
    try {
      final productos = await RepositorioTiendaXnox.instancia.productos(
        PublicoTiendaXnox.admin,
      );
      if (!mounted) return;
      setState(() {
        _productos = productos;
        _cargando = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _cargando = false;
      });
    }
  }

  List<String> get _categorias {
    final set = <String>{
      for (final p in _productos)
        if (p.categoria.isNotEmpty) p.categoria,
    };
    return set.toList()..sort();
  }

  List<ProductoXnox> get _filtrados {
    final q = _busqueda.trim().toLowerCase();
    return _productos
        .where((p) => _categoria == null || p.categoria == _categoria)
        .where(
          (p) =>
              q.isEmpty ||
              p.nombre.toLowerCase().contains(q) ||
              p.categoria.toLowerCase().contains(q) ||
              p.descripcion.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      onRefresh: _cargar,
      children: [
        const CabeceraApp(
          titulo: 'Tienda XNOX',
          subtitulo: 'Productos de XNOX para tu gimnasio',
          acciones: [CampanaAvisos(redonda: true)],
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaFoto(
          foto: FotosApp.tienda,
          alineacion: const Alignment(0.4, 0.2),
          etiqueta: 'Solo para el gimnasio',
          titulo: _cargando
              ? '…'
              : '${_productos.length} '
                    '${_productos.length == 1 ? 'producto' : 'productos'}',
          texto:
              'Equipos y más, que XNOX ofrece a los gimnasios. '
              'Se piden directo a XNOX.',
        ),
        const SizedBox(height: AppEspaciado.md),
        if (_productos.isNotEmpty) ...[
          BuscadorApp(
            hint: 'Buscar producto',
            onChanged: (v) => setState(() => _busqueda = v),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
        ],
        if (_categorias.length > 1) ...[
          FilaChips(
            chips: [
              for (final c in <String?>[null, ..._categorias])
                ChipApp(
                  texto: c ?? 'Todo',
                  activo: c == _categoria,
                  onTap: () => setState(() => _categoria = c),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
        ],
        ..._contenido(),
      ],
    );
  }

  List<Widget> _contenido() {
    if (_cargando) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: Center(child: CircularProgressIndicator()),
        ),
      ];
    }
    if (_error) {
      return const [
        VacioApp(
          icono: Icons.cloud_off_rounded,
          titulo: 'No se pudo cargar la tienda',
          texto: 'Revisa tu conexión y desliza hacia abajo para reintentar.',
        ),
      ];
    }
    if (_productos.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.local_mall_outlined,
          titulo: 'Aún no hay productos',
          texto: 'Cuando XNOX publique productos para tu gimnasio, aparecerán aquí.',
        ),
      ];
    }
    final filtrados = _filtrados;
    if (filtrados.isEmpty) {
      return const [
        VacioApp(
          icono: Icons.search_off_rounded,
          titulo: 'Sin coincidencias',
          texto: 'No hay productos que coincidan con la búsqueda.',
        ),
      ];
    }
    return [
      TituloSeccion(
        icono: Icons.local_mall_rounded,
        titulo: _categoria ?? 'Productos',
        detalle:
            '${filtrados.length} '
            '${filtrados.length == 1 ? 'producto' : 'productos'}',
      ),
      GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        itemCount: filtrados.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: AppEspaciado.sm + 6,
          crossAxisSpacing: AppEspaciado.sm + 6,
          childAspectRatio: 0.64,
        ),
        itemBuilder: (_, i) => TarjetaProductoXnox(
          producto: filtrados[i],
          onTap: () => mostrarFichaProductoXnox(
            context,
            filtrados[i],
            PublicoTiendaXnox.admin,
          ),
        ),
      ),
    ];
  }
}
