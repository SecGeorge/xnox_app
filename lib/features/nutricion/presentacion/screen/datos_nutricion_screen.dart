import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/cliente/datos/almacen_medidas.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Tus datos: altura, peso, sexo, objetivo y actividad. Con ellos el backend
/// calcula las metas. La portada muestra el IMC en vivo mientras se edita.
/// Devuelve true si se guardó. Con [miembroId] la usa el personal (el peso
/// solo lo registra el socio).
class DatosNutricionScreen extends StatefulWidget {
  final PerfilNutricion perfil;
  final int? miembroId;

  const DatosNutricionScreen({super.key, required this.perfil, this.miembroId});

  @override
  State<DatosNutricionScreen> createState() => _DatosNutricionScreenState();
}

class _DatosNutricionScreenState extends State<DatosNutricionScreen> {
  final _repo = RepositorioNutricion();
  late double? _altura = widget.perfil.alturaCm;
  late double? _peso = widget.perfil.peso;
  late String? _sexo = widget.perfil.sexo;
  late String _objetivo = widget.perfil.objetivo;
  late int _actividad = widget.perfil.actividad;
  bool _guardando = false;

  bool get _esSocio => widget.miembroId == null;

  double? get _imc {
    final a = _altura, p = _peso;
    if (a == null || p == null || a <= 0) return null;
    return (p / ((a / 100) * (a / 100)) * 10).round() / 10;
  }

  String _categoria(double imc) {
    if (imc < 18.5) return 'Bajo peso';
    if (imc < 25) return 'Normal';
    if (imc < 30) return 'Sobrepeso';
    return 'Obesidad';
  }

  static const _objetivos = [
    ('perder', 'Bajar de peso', Icons.trending_down_rounded),
    ('mantener', 'Mantener', Icons.balance_rounded),
    ('ganar', 'Ganar músculo', Icons.trending_up_rounded),
  ];

  static const _actividades = {
    1: ('Sedentario', 'Casi no hago ejercicio'),
    2: ('Ligero', '1 a 3 días por semana'),
    3: ('Moderado', '3 a 5 días por semana'),
    4: ('Intenso', '6 a 7 días por semana'),
    5: ('Muy intenso', 'Entreno 2 veces al día'),
  };

  Future<void> _guardar() async {
    final altura = _altura;
    if (altura == null || altura < 100 || altura > 250) {
      mostrarMensaje(
        context,
        'Indica tu altura (entre 100 y 250 cm)',
        tipo: TipoMensaje.advertencia,
      );
      return;
    }
    final peso = _peso;
    if (_esSocio && peso != null && (peso < 25 || peso > 350)) {
      mostrarMensaje(context, 'Revisa tu peso', tipo: TipoMensaje.advertencia);
      return;
    }
    setState(() => _guardando = true);
    try {
      // El peso va primero: el cálculo de metas usa el último registrado.
      if (_esSocio && peso != null && peso != widget.perfil.peso) {
        await AlmacenMedidas.instancia.registrar('peso', peso);
      }
      await _repo.guardarPerfil(
        miembroId: widget.miembroId,
        alturaCm: altura,
        sexo: _sexo,
        objetivo: _objetivo,
        actividad: _actividad,
      );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _guardando = false);
      mostrarMensaje(context, '$e', tipo: TipoMensaje.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final imc = _imc;
    return PantallaApp(
      espacioAbajo: AppEspaciado.lg,
      pie: PieBoton(
        texto: 'Guardar',
        icono: Icons.check_rounded,
        cargando: _guardando,
        onPressed: _guardar,
      ),
      children: [
        CabeceraApp(
          titulo: _esSocio ? 'Tus datos' : 'Datos del socio',
          subtitulo: 'Con esto se calculan las metas del día',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        PortadaNutricion(
          foto: FotosNutricion.metas,
          icono: Icons.monitor_weight_rounded,
          chip: 'Tu cuerpo',
          alto: 150,
          titulo: imc == null ? 'Completa tus datos' : 'IMC $imc',
          detalle: imc == null
              ? 'Con altura y peso calculamos tu IMC y tus metas'
              : '${_categoria(imc)} · ${PerfilNutricion.objetivos[_objetivo]}',
        ),
        const SizedBox(height: AppEspaciado.lg),
        Row(
          children: [
            Expanded(
              child: _Medida(
                icono: Icons.height_rounded,
                etiqueta: 'Altura',
                unidad: 'cm',
                valor: _altura,
                paso: 1,
                minimo: 100,
                maximo: 250,
                inicial: 165,
                onCambio: (v) => setState(() => _altura = v),
              ),
            ),
            const SizedBox(width: AppEspaciado.sm + 4),
            Expanded(
              child: _Medida(
                icono: Icons.scale_rounded,
                etiqueta: 'Peso',
                unidad: 'kg',
                valor: _peso,
                paso: 0.5,
                minimo: 25,
                maximo: 350,
                inicial: 70,
                habilitado: _esSocio,
                ayuda: _esSocio ? null : 'Lo registra el socio',
                onCambio: (v) => setState(() => _peso = v),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(icono: Icons.wc_rounded, titulo: 'Sexo'),
        Row(
          children: [
            Expanded(
              child: _Opcion(
                icono: Icons.female_rounded,
                texto: 'Mujer',
                activo: _sexo == 'F',
                onTap: () => setState(() => _sexo = 'F'),
              ),
            ),
            const SizedBox(width: AppEspaciado.sm + 4),
            Expanded(
              child: _Opcion(
                icono: Icons.male_rounded,
                texto: 'Hombre',
                activo: _sexo == 'M',
                onTap: () => setState(() => _sexo = 'M'),
              ),
            ),
          ],
        ),
        Center(
          child: TextButton(
            onPressed: () => setState(() => _sexo = null),
            child: Text(
              _sexo == null ? '✓ Prefiero no decirlo' : 'Prefiero no decirlo',
            ),
          ),
        ),
        const SizedBox(height: AppEspaciado.sm),
        const TituloSeccion(icono: Icons.flag_rounded, titulo: 'Tu objetivo'),
        Row(
          children: [
            for (final (i, (clave, texto, icono)) in _objetivos.indexed) ...[
              if (i > 0) const SizedBox(width: AppEspaciado.sm),
              Expanded(
                child: _Opcion(
                  icono: icono,
                  texto: texto,
                  activo: _objetivo == clave,
                  onTap: () => setState(() => _objetivo = clave),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: AppEspaciado.lg),
        const TituloSeccion(
          icono: Icons.directions_run_rounded,
          titulo: 'Actividad física',
        ),
        _actividadSelector(),
      ],
    );
  }

  /// Cinco barras que suben como un medidor; abajo, el nivel elegido.
  Widget _actividadSelector() {
    final (nombre, detalle) = _actividades[_actividad]!;
    return TarjetaPlana(
      child: Column(
        children: [
          SizedBox(
            height: 70,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var n = 1; n <= 5; n++) ...[
                  if (n > 1) const SizedBox(width: 8),
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => setState(() => _actividad = n),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          height: 18.0 + n * 10,
                          decoration: BoxDecoration(
                            color: n <= _actividad
                                ? AppColores.primario
                                : AppColores.primario.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            nombre,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColores.textoPrincipal,
            ),
          ),
          Text(
            detalle,
            style: const TextStyle(
              fontSize: 13,
              color: AppColores.textoSecundario,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta de una medida: número grande (tocarlo deja escribirlo) y botones
/// − / +. El número se achica si no cabe (letra grande, pantalla angosta).
class _Medida extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String unidad;
  final double? valor;
  final double paso;
  final double minimo;
  final double maximo;

  /// Valor con el que arranca el − / + si aún no hay ninguno.
  final double inicial;
  final bool habilitado;
  final String? ayuda;
  final ValueChanged<double?> onCambio;

  const _Medida({
    required this.icono,
    required this.etiqueta,
    required this.unidad,
    required this.valor,
    required this.paso,
    required this.minimo,
    required this.maximo,
    required this.inicial,
    required this.onCambio,
    this.habilitado = true,
    this.ayuda,
  });

  static String _formato(double? v) => v == null
      ? '—'
      : v == v.roundToDouble()
      ? '${v.toInt()}'
      : v.toStringAsFixed(1);

  void _sumar(double signo) {
    final nuevo = ((valor ?? inicial) + paso * signo).clamp(minimo, maximo);
    onCambio(nuevo.toDouble());
  }

  Future<void> _escribir(BuildContext context) async {
    final texto = TextEditingController(
      text: valor == null ? '' : _formato(valor),
    );
    final r = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(etiqueta),
        content: TextField(
          controller: texto,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
          ],
          decoration: InputDecoration(suffixText: unidad),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              ctx,
              double.tryParse(texto.text.trim().replaceAll(',', '.')),
            ),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
    texto.dispose();
    if (r != null) onCambio(r.clamp(minimo, maximo).toDouble());
  }

  @override
  Widget build(BuildContext context) {
    Widget boton(IconData icono, double signo) => Material(
      color: AppColores.primario.withValues(alpha: 0.08),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: habilitado ? () => _sumar(signo) : null,
        child: SizedBox(
          width: 34,
          height: 34,
          child: Icon(icono, size: 20, color: AppColores.primario),
        ),
      ),
    );

    return TarjetaPlana(
      onTap: habilitado ? () => _escribir(context) : null,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icono, size: 18, color: AppColores.primario),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  etiqueta.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w800,
                    color: AppColores.textoSecundario,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 44,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: _formato(valor),
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    TextSpan(
                      text: ' $unidad',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          if (ayuda != null)
            Text(
              ayuda!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11.5,
                color: AppColores.textoSecundario,
              ),
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                boton(Icons.remove_rounded, -1),
                boton(Icons.add_rounded, 1),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tarjeta seleccionable con ícono grande (sexo, objetivo).
class _Opcion extends StatelessWidget {
  final IconData icono;
  final String texto;
  final bool activo;
  final VoidCallback onTap;

  const _Opcion({
    required this.icono,
    required this.texto,
    required this.activo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radio = BorderRadius.circular(AppEspaciado.radio + 2);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: radio,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 6),
          decoration: BoxDecoration(
            gradient: activo ? AppColores.degradadoRelleno : null,
            color: activo ? null : AppColores.superficie,
            borderRadius: radio,
            border: activo
                ? AppColores.bordeCabecera
                : Border.all(color: AppColores.borde),
          ),
          child: Column(
            children: [
              Icon(
                icono,
                size: 30,
                color: activo ? AppColores.sobreRelleno : AppColores.primario,
              ),
              const SizedBox(height: 6),
              Text(
                texto,
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: activo
                      ? AppColores.sobreRelleno
                      : AppColores.textoPrincipal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
