import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/screen/datos_nutricion_screen.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Lo que se eligió en la hoja de cantidad.
class EleccionAlimento {
  final Alimento alimento;
  final String tiempo;
  final double gramos;

  const EleccionAlimento(this.alimento, this.tiempo, this.gramos);
}

double? _leerNumero(String texto) =>
    double.tryParse(texto.trim().replaceAll(',', '.'));

final _soloDecimales = FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'));

InputDecoration _decoracion(String etiqueta, {String? sufijo, String? ayuda}) =>
    InputDecoration(
      labelText: etiqueta,
      suffixText: sufijo,
      helperText: ayuda,
      filled: true,
      fillColor: AppColores.fondo,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        borderSide: BorderSide.none,
      ),
    );

/// Cuánto comió (en porciones o gramos) y en qué comida del día. Muestra lo
/// que aporta esa cantidad y sus etiquetas "Alto en …".
Future<EleccionAlimento?> elegirCantidad(
  BuildContext context,
  Alimento alimento, {
  String? tiempo,
  double? gramos,
  String textoBoton = 'Agregar',
}) {
  return mostrarHojaModerna<EleccionAlimento>(
    context,
    builder: (_) => _HojaCantidad(
      alimento: alimento,
      tiempo: tiempo ?? TiempoComida.segunHora().clave,
      gramos: gramos ?? alimento.porcionG,
      textoBoton: textoBoton,
    ),
  );
}

class _HojaCantidad extends StatefulWidget {
  final Alimento alimento;
  final String tiempo;
  final double gramos;
  final String textoBoton;

  const _HojaCantidad({
    required this.alimento,
    required this.tiempo,
    required this.gramos,
    required this.textoBoton,
  });

  @override
  State<_HojaCantidad> createState() => _HojaCantidadState();
}

class _HojaCantidadState extends State<_HojaCantidad> {
  late String _tiempo = widget.tiempo;
  late final _gramos = TextEditingController(text: _texto(widget.gramos));

  static String _texto(double v) =>
      v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);

  double get _valor => _leerNumero(_gramos.text) ?? 0;

  void _porciones(double cuantas) {
    setState(() => _gramos.text = _texto(widget.alimento.porcionG * cuantas));
  }

  @override
  void dispose() {
    _gramos.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.alimento;
    final aporte = a.aporte(_valor);
    return HojaModerna(
      cabecera: FotoAlimento(a, tamano: 52),
      titulo: a.nombre,
      subtitulo: [
        if (a.marca != null) a.marca!,
        if (a.porcionNombre != null)
          '${a.porcionNombre} = ${gramosTexto(a.porcionG)}',
      ].join(' · '),
      pie: BotonHoja(
        texto: widget.textoBoton,
        icono: Icons.check_rounded,
        onPressed: _valor > 0
            ? () => Navigator.pop(context, EleccionAlimento(a, _tiempo, _valor))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          EtiquetasAlimento(a.etiquetas, compactas: false),
          if (a.etiquetas.isNotEmpty) const SizedBox(height: AppEspaciado.md),
          const Text(
            '¿EN QUÉ COMIDA?',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in TiempoComida.todos)
                ChipApp(
                  texto: t.nombre,
                  icono: t.icono,
                  activo: _tiempo == t.clave,
                  onTap: () => setState(() => _tiempo = t.clave),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.lg),
          const Text(
            '¿CUÁNTO?',
            style: TextStyle(
              fontSize: 11.5,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w700,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: 8),
          // Opciones en 2 columnas: los gramos grandes y la porción en
          // palabras debajo ("150 g" / "1 filete"). El texto se parte si no
          // cabe (letra grande, pantalla angosta).
          for (final fila in const [
            [0.5, 1.0],
            [1.5, 2.0],
          ]) ...[
            Row(
              children: [
                for (final (k, p) in fila.indexed) ...[
                  if (k > 0) const SizedBox(width: 8),
                  Expanded(
                    child: _OpcionPorcion(
                      gramos: gramosTexto(a.porcionG * p),
                      porcion: a.porcionesDe(a.porcionG * p),
                      activa: (_valor - a.porcionG * p).abs() < 0.01,
                      onTap: () => _porciones(p),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: AppEspaciado.md),
          TextField(
            controller: _gramos,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [_soloDecimales],
            onChanged: (_) => setState(() {}),
            decoration: _decoracion(
              'Cantidad en gramos',
              sufijo: 'g',
              ayuda: a.porcionesDe(_valor) == null
                  ? 'O toca una de las opciones de arriba'
                  : 'Equivale a ${a.porcionesDe(_valor)}',
            ),
          ),
          const SizedBox(height: AppEspaciado.lg),
          // Lo que aporta esa cantidad.
          Row(
            children: [
              for (final n in [
                Nutriente.kcal,
                Nutriente.proteina,
                Nutriente.carbohidrato,
                Nutriente.grasa,
              ])
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        n.formato(aporte[n.clave] ?? 0),
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: ColoresNutricion.de(n.clave),
                        ),
                      ),
                      Text(
                        n.nombre,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Text(
            'Grasas saturadas ${Nutriente.grasaSaturada.formato(aporte['grasa_saturada'] ?? 0)}'
            ' · Azúcares ${Nutriente.azucar.formato(aporte['azucar'] ?? 0)}'
            ' · Sodio ${Nutriente.sodio.formato(aporte['sodio'] ?? 0)}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: AppColores.textoSecundario,
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
        ],
      ),
    );
  }
}

/// Abre "Tus datos" (altura, peso, sexo, objetivo y actividad). Con eso el
/// backend calcula las metas. Devuelve true si se guardó.
Future<bool> editarPerfilNutricion(
  BuildContext context, {
  required PerfilNutricion perfil,
  int? miembroId,
}) async {
  final r = await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) =>
          DatosNutricionScreen(perfil: perfil, miembroId: miembroId),
    ),
  );
  return r == true;
}

/// Alimento cargado a mano (valores por 100 g, como en la etiqueta).
Future<Alimento?> crearAlimentoManual(
  BuildContext context, {
  String nombre = '',
}) {
  return mostrarHojaModerna<Alimento>(
    context,
    builder: (_) => _HojaCrearAlimento(nombre: nombre),
  );
}

class _HojaCrearAlimento extends StatefulWidget {
  final String nombre;
  const _HojaCrearAlimento({required this.nombre});

  @override
  State<_HojaCrearAlimento> createState() => _HojaCrearAlimentoState();
}

class _HojaCrearAlimentoState extends State<_HojaCrearAlimento> {
  final _repo = RepositorioNutricion();
  late final _nombre = TextEditingController(text: widget.nombre);
  final _porcion = TextEditingController(text: '100');
  final _porcionNombre = TextEditingController();
  final _campos = {
    for (final n in Nutriente.todos) n.clave: TextEditingController(),
  };
  bool _guardando = false;

  @override
  void dispose() {
    _nombre.dispose();
    _porcion.dispose();
    _porcionNombre.dispose();
    for (final c in _campos.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    final kcal = _leerNumero(_campos['kcal']!.text);
    if (_nombre.text.trim().isEmpty || kcal == null) {
      mostrarMensaje(
        context,
        'Escribe al menos el nombre y las calorías',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    setState(() => _guardando = true);
    try {
      final alimento = await _repo.crearAlimento(
        nombre: _nombre.text.trim(),
        porcionG: _leerNumero(_porcion.text) ?? 100,
        porcionNombre: _porcionNombre.text.trim(),
        por100g: {
          for (final e in _campos.entries) e.key: _leerNumero(e.value.text),
        },
      );
      if (!mounted) return;
      Navigator.pop(context, alimento);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarMensaje(context, '$e', tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    return HojaModerna(
      icono: Icons.edit_note_rounded,
      titulo: 'Nuevo alimento',
      subtitulo: 'Copia la tabla nutricional (por 100 g)',
      pie: BotonHoja(
        texto: 'Crear',
        icono: Icons.check_rounded,
        cargando: _guardando,
        onPressed: _guardar,
      ),
      child: Column(
        children: [
          TextField(
            controller: _nombre,
            textCapitalization: TextCapitalization.sentences,
            decoration: _decoracion('Nombre'),
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _porcion,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_soloDecimales],
                  decoration: _decoracion('Porción', sufijo: 'g'),
                ),
              ),
              const SizedBox(width: AppEspaciado.sm + 4),
              Expanded(
                child: TextField(
                  controller: _porcionNombre,
                  decoration: _decoracion('Se llama', ayuda: 'Ej. 1 plato'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm + 4),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: AppEspaciado.sm + 4,
            crossAxisSpacing: AppEspaciado.sm + 4,
            childAspectRatio: 2.6,
            children: [
              for (final n in Nutriente.todos)
                TextField(
                  controller: _campos[n.clave],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [_soloDecimales],
                  decoration: _decoracion(n.nombre, sufijo: n.unidad),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.md),
        ],
      ),
    );
  }
}

/// Opción de cantidad: gramos en grande y su porción en palabras.
class _OpcionPorcion extends StatelessWidget {
  final String gramos;
  final String? porcion;
  final bool activa;
  final VoidCallback onTap;

  const _OpcionPorcion({
    required this.gramos,
    required this.porcion,
    required this.activa,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppEspaciado.radio);
    final tinta = activa ? Colors.white : AppColores.textoPrincipal;
    return Material(
      color: activa ? AppColores.primario : AppColores.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: radio,
        side: BorderSide(
          color: activa ? AppColores.primario : AppColores.borde,
        ),
      ),
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          child: Column(
            children: [
              Text(
                gramos,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: tinta,
                ),
              ),
              if (porcion != null)
                Text(
                  porcion!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: activa
                        ? Colors.white.withValues(alpha: 0.85)
                        : AppColores.textoSecundario,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
