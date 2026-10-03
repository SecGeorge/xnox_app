import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xnox_app/core/tema/app_tema.dart';

/// Atajo de la hoja: un valor de un toque ("Última vez · 55 kg").
class AtajoNumero {
  final String etiqueta;
  final double valor;

  const AtajoNumero(this.etiqueta, this.valor);
}

/// Hoja inferior para capturar un número durante el entrenamiento (carga en
/// kg, repeticiones): el valor en grande —se puede escribir directo—, botones
/// − / + y atajos de un toque. Devuelve el valor o null si se cancela.
Future<double?> pedirNumero(
  BuildContext context, {
  required String titulo,
  String? subtitulo,
  required IconData icono,
  required String unidad,
  double? inicial,
  double paso = 1,
  double minimo = 0,
  bool decimales = false,
  List<AtajoNumero> atajos = const [],
  String textoGuardar = 'Guardar',
}) {
  return showModalBottomSheet<double>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColores.superficie,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => _HojaNumero(
      titulo: titulo,
      subtitulo: subtitulo,
      icono: icono,
      unidad: unidad,
      inicial: inicial,
      paso: paso,
      minimo: minimo,
      decimales: decimales,
      atajos: atajos,
      textoGuardar: textoGuardar,
    ),
  );
}

class _HojaNumero extends StatefulWidget {
  final String titulo;
  final String? subtitulo;
  final IconData icono;
  final String unidad;
  final double? inicial;
  final double paso;
  final double minimo;
  final bool decimales;
  final List<AtajoNumero> atajos;
  final String textoGuardar;

  const _HojaNumero({
    required this.titulo,
    required this.subtitulo,
    required this.icono,
    required this.unidad,
    required this.inicial,
    required this.paso,
    required this.minimo,
    required this.decimales,
    required this.atajos,
    required this.textoGuardar,
  });

  @override
  State<_HojaNumero> createState() => _HojaNumeroState();
}

class _HojaNumeroState extends State<_HojaNumero> {
  late final _ctrl = TextEditingController(
    text: widget.inicial == null ? '' : _texto(widget.inicial!),
  );

  String _texto(double v) => widget.decimales
      ? (v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1))
      : v.round().toString();

  double? get _valor => double.tryParse(_ctrl.text.trim().replaceAll(',', '.'));

  bool get _valido => (_valor ?? -1) > widget.minimo;

  void _poner(double v) {
    final limpio = v < widget.minimo ? widget.minimo : v;
    setState(() => _ctrl.text = _texto(limpio));
    HapticFeedback.selectionClick();
  }

  void _sumar(double delta) => _poner((_valor ?? 0) + delta);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final teclado = MediaQuery.of(context).viewInsets.bottom;
    final pasoTexto = _texto(widget.paso);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppEspaciado.lg,
        10,
        AppEspaciado.lg,
        teclado + AppEspaciado.lg,
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColores.borde,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppEspaciado.md + 2),
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColores.primario.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(widget.icono, color: AppColores.primario),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.titulo,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColores.textoPrincipal,
                        ),
                      ),
                      if (widget.subtitulo != null)
                        Text(
                          widget.subtitulo!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColores.textoSecundario,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppEspaciado.lg),
            // Valor en grande con − / + a los lados.
            Row(
              children: [
                _botonPaso(
                  '−$pasoTexto',
                  Icons.remove_rounded,
                  () => _sumar(-widget.paso),
                ),
                Expanded(
                  child: Column(
                    children: [
                      IntrinsicWidth(
                        child: TextField(
                          controller: _ctrl,
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: widget.decimales,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(widget.decimales ? r'[0-9.,]' : r'[0-9]'),
                            ),
                          ],
                          onChanged: (_) => setState(() {}),
                          style: TextStyle(
                            fontSize: 52,
                            height: 1.05,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            color: AppColores.textoPrincipal,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            hintText: '0',
                            hintStyle: TextStyle(
                              color: AppColores.textoSecundario.withValues(
                                alpha: 0.4,
                              ),
                            ),
                          ),
                        ),
                      ),
                      Text(
                        widget.unidad,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColores.textoSecundario,
                        ),
                      ),
                    ],
                  ),
                ),
                _botonPaso(
                  '+$pasoTexto',
                  Icons.add_rounded,
                  () => _sumar(widget.paso),
                ),
              ],
            ),
            if (widget.atajos.isNotEmpty) ...[
              const SizedBox(height: AppEspaciado.lg),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final a in widget.atajos)
                    _atajo(a, (_valor ?? -1) == a.valor),
                ],
              ),
            ],
            const SizedBox(height: AppEspaciado.lg),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _valido
                    ? () => Navigator.pop(context, _valor)
                    : null,
                child: Text(widget.textoGuardar),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColores.textoSecundario),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonPaso(String etiqueta, IconData icono, VoidCallback onTap) {
    return Column(
      children: [
        Material(
          color: AppColores.primario.withValues(alpha: 0.08),
          shape: CircleBorder(
            side: BorderSide(color: AppColores.primario.withValues(alpha: 0.2)),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: SizedBox(
              width: 58,
              height: 58,
              child: Icon(icono, size: 28, color: AppColores.primario),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          etiqueta,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColores.textoSecundario,
          ),
        ),
      ],
    );
  }

  Widget _atajo(AtajoNumero a, bool activo) {
    return GestureDetector(
      onTap: () => _poner(a.valor),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: activo
              ? AppColores.primario
              : AppColores.primario.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: activo
                ? AppColores.primario
                : AppColores.primario.withValues(alpha: 0.18),
          ),
        ),
        child: Text.rich(
          TextSpan(
            children: [
              TextSpan(text: '${a.etiqueta} · '),
              TextSpan(
                text: '${_texto(a.valor)} ${widget.unidad}',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
          style: TextStyle(
            fontSize: 12.5,
            color: activo ? Colors.white : AppColores.primario,
          ),
        ),
      ),
    );
  }
}
