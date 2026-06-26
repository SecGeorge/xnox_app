import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/miembros/dominio/entidades/miembro.dart';

class MiembrosScreen extends StatefulWidget {
  const MiembrosScreen({super.key});

  @override
  State<MiembrosScreen> createState() => _MiembrosScreenState();
}

class _MiembrosScreenState extends State<MiembrosScreen> {
  // Datos de demostración. Reemplazar por la respuesta del endpoint de miembros.
  final List<Miembro> _miembros = [
    Miembro(
      id: 1,
      nombre: 'Carlos Ramírez',
      documento: '45872136',
      plan: 'Premium Anual',
      estado: EstadoMiembro.activo,
      fechaVencimiento: DateTime(2026, 12, 1),
    ),
    Miembro(
      id: 2,
      nombre: 'María Fernández',
      documento: '70114589',
      plan: 'Mensual',
      estado: EstadoMiembro.deudor,
      fechaVencimiento: DateTime(2026, 7, 5),
      saldoPendiente: 80,
    ),
    Miembro(
      id: 3,
      nombre: 'Jorge Castillo',
      documento: '40258963',
      plan: 'Mensual',
      estado: EstadoMiembro.moroso,
      fechaVencimiento: DateTime(2026, 5, 20),
      saldoPendiente: 240,
    ),
    Miembro(
      id: 4,
      nombre: 'Lucía Torres',
      documento: '48963201',
      plan: 'Trimestral',
      estado: EstadoMiembro.vencido,
      fechaVencimiento: DateTime(2026, 6, 1),
    ),
    Miembro(
      id: 5,
      nombre: 'Andrés Salazar',
      documento: '71203654',
      plan: 'Premium Anual',
      estado: EstadoMiembro.activo,
      fechaVencimiento: DateTime(2027, 1, 15),
    ),
    Miembro(
      id: 6,
      nombre: 'Paola Mendoza',
      documento: '46985210',
      plan: 'Mensual',
      estado: EstadoMiembro.deudor,
      fechaVencimiento: DateTime(2026, 7, 2),
      saldoPendiente: 80,
    ),
  ];

  // null = "Todos"
  EstadoMiembro? _filtro;
  String _busqueda = '';

  List<Miembro> get _filtrados {
    return _miembros.where((m) {
      final coincideEstado = _filtro == null || m.estado == _filtro;
      final coincideBusqueda = _busqueda.isEmpty ||
          m.nombre.toLowerCase().contains(_busqueda.toLowerCase()) ||
          m.documento.contains(_busqueda);
      return coincideEstado && coincideBusqueda;
    }).toList();
  }

  int _conteo(EstadoMiembro? estado) {
    if (estado == null) return _miembros.length;
    return _miembros.where((m) => m.estado == estado).length;
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _filtrados;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Miembros'),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.person_add_alt_1),
            tooltip: 'Nuevo miembro',
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(
                AppEspaciado.md, AppEspaciado.md, AppEspaciado.md, AppEspaciado.sm),
            child: TextField(
              onChanged: (v) => setState(() => _busqueda = v),
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre o documento',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          // Filtros de estado
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding:
                  const EdgeInsets.symmetric(horizontal: AppEspaciado.md),
              children: [
                _chipFiltro('Todos', null),
                _chipFiltro('Activos', EstadoMiembro.activo),
                _chipFiltro('Deudores', EstadoMiembro.deudor),
                _chipFiltro('Morosos', EstadoMiembro.moroso),
                _chipFiltro('Vencidos', EstadoMiembro.vencido),
              ],
            ),
          ),
          const SizedBox(height: AppEspaciado.sm),
          Expanded(
            child: filtrados.isEmpty
                ? const EstadoVacio(
                    icono: Icons.people_outline,
                    mensaje: 'No hay miembros en esta categoría',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(AppEspaciado.md, 0,
                        AppEspaciado.md, AppEspaciado.lg),
                    itemCount: filtrados.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: AppEspaciado.sm + 4),
                    itemBuilder: (_, i) => _tarjetaMiembro(filtrados[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chipFiltro(String etiqueta, EstadoMiembro? estado) {
    final seleccionado = _filtro == estado;
    final color = estado?.color ?? AppColores.primario;
    return Padding(
      padding: const EdgeInsets.only(right: AppEspaciado.sm),
      child: ChoiceChip(
        label: Text('$etiqueta (${_conteo(estado)})'),
        selected: seleccionado,
        onSelected: (_) => setState(() => _filtro = estado),
        showCheckmark: false,
        labelStyle: TextStyle(
          color: seleccionado ? Colors.white : AppColores.textoSecundario,
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
        backgroundColor: AppColores.superficie,
        selectedColor: color,
        side: BorderSide(
          color: seleccionado ? color : AppColores.borde,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _tarjetaMiembro(Miembro m) {
    final fecha = DateFormat('dd MMM yyyy', 'es').format(m.fechaVencimiento);
    return TarjetaApp(
      onTap: () {},
      child: Row(
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: m.estado.color.withValues(alpha: 0.15),
            child: Text(
              m.iniciales,
              style: TextStyle(
                color: m.estado.color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: AppEspaciado.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  m.nombre,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColores.textoPrincipal,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${m.plan} · DNI ${m.documento}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColores.textoSecundario,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.event,
                        size: 14, color: AppColores.textoSecundario),
                    const SizedBox(width: 4),
                    Text(
                      'Vence: $fecha',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                    if (m.saldoPendiente > 0) ...[
                      const SizedBox(width: 10),
                      Text(
                        'S/ ${m.saldoPendiente.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: m.estado.color,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppEspaciado.sm),
          EtiquetaEstado(texto: m.estado.etiqueta, color: m.estado.color),
        ],
      ),
    );
  }
}
