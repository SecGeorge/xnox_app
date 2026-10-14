import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/core/widgets/widgets_comunes.dart';
import 'package:xnox_app/features/asistencia/presentacion/screen/escaner_qr_screen.dart';
import 'package:xnox_app/features/nutricion/datos/repositorio_nutricion.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/hojas_nutricion.dart';
import 'package:xnox_app/features/nutricion/presentacion/widget/piezas_nutricion.dart';

/// Buscar un alimento: primero el catálogo del gimnasio (comidas comunes) y,
/// si no alcanza, Open Food Facts (productos envasados con sus nutrientes).
/// También se puede escanear el código de barras del empaque. Al elegir uno
/// se pide la cantidad y la comida del día; devuelve [EleccionAlimento].
class BuscarAlimentoScreen extends StatefulWidget {
  final String? tiempo;
  final String textoBoton;

  const BuscarAlimentoScreen({
    super.key,
    this.tiempo,
    this.textoBoton = 'Agregar',
  });

  @override
  State<BuscarAlimentoScreen> createState() => _BuscarAlimentoScreenState();
}

class _BuscarAlimentoScreenState extends State<BuscarAlimentoScreen> {
  final _repo = RepositorioNutricion();
  final _texto = TextEditingController();
  Timer? _espera;
  List<Alimento> _resultados = const [];
  bool _buscando = false;
  String? _error;
  String _buscado = '';

  /// Atajos para empezar sin escribir.
  static const _sugerencias = [
    'Pollo',
    'Arroz',
    'Huevo',
    'Avena',
    'Atún',
    'Palta',
    'Plátano',
    'Yogur',
  ];

  @override
  void dispose() {
    _espera?.cancel();
    _texto.dispose();
    super.dispose();
  }

  void _alEscribir(String v) {
    _espera?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        _resultados = const [];
        _buscado = '';
        _error = null;
      });
      return;
    }
    _espera = Timer(const Duration(milliseconds: 450), () => _buscar(v));
  }

  Future<void> _buscar(String v) async {
    final texto = v.trim();
    setState(() {
      _buscando = true;
      _error = null;
    });
    try {
      final lista = await _repo.buscar(texto);
      // Si escribió algo más mientras tanto, esta respuesta ya no sirve.
      if (!mounted || texto != _texto.text.trim()) return;
      setState(() {
        _resultados = lista;
        _buscado = texto;
        _buscando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = '$e';
        _buscando = false;
      });
    }
  }

  Future<void> _escanear() async {
    final codigo = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const EscanerQrScreen(
          formatos: [
            BarcodeFormat.ean13,
            BarcodeFormat.ean8,
            BarcodeFormat.upcA,
            BarcodeFormat.upcE,
          ],
          titulo: 'Escanea el código de barras',
          ayuda: 'Del empaque del producto',
        ),
      ),
    );
    if (codigo == null || !mounted) return;
    setState(() => _buscando = true);
    try {
      final alimento = await _repo.porCodigo(codigo);
      if (!mounted) return;
      setState(() => _buscando = false);
      if (alimento == null) {
        mostrarMensaje(
          context,
          'Ese producto no está en la base. Puedes crearlo a mano.',
          tipo: TipoMensaje.advertencia,
        );
        return;
      }
      await _elegir(alimento);
    } catch (e) {
      if (!mounted) return;
      setState(() => _buscando = false);
      mostrarMensaje(context, '$e', tipo: TipoMensaje.error);
    }
  }

  Future<void> _elegir(Alimento alimento) async {
    final eleccion = await elegirCantidad(
      context,
      alimento,
      tiempo: widget.tiempo,
      textoBoton: widget.textoBoton,
    );
    if (eleccion == null || !mounted) return;
    Navigator.pop(context, eleccion);
  }

  Future<void> _crear() async {
    final alimento = await crearAlimentoManual(
      context,
      nombre: _texto.text.trim(),
    );
    if (alimento == null || !mounted) return;
    await _elegir(alimento);
  }

  @override
  Widget build(BuildContext context) {
    return PantallaApp(
      espacioAbajo: AppEspaciado.lg,
      children: [
        CabeceraApp(
          titulo: 'Agregar alimento',
          subtitulo: 'Busca por nombre o escanea el empaque',
          acciones: [
            BotonRedondo(
              icono: Icons.qr_code_scanner_rounded,
              tooltip: 'Escanear código de barras',
              onTap: _escanear,
            ),
          ],
        ),
        const SizedBox(height: AppEspaciado.md),
        BuscadorApp(
          controller: _texto,
          hint: 'Ej. pechuga de pollo, yogurt Gloria…',
          onChanged: _alEscribir,
        ),
        const SizedBox(height: AppEspaciado.md),
        if (_texto.text.trim().length < 2) ...[
          PortadaNutricion(
            foto: FotosNutricion.de(
              widget.tiempo ?? TiempoComida.segunHora().clave,
            ),
            icono: TiempoComida.de(
              widget.tiempo ?? TiempoComida.segunHora().clave,
            ).icono,
            chip: TiempoComida.de(
              widget.tiempo ?? TiempoComida.segunHora().clave,
            ).nombre,
            alto: 160,
            titulo: '¿Qué comiste?',
            detalle: 'Escribe arriba o escanea el código del empaque',
            accion: BotonFoto(
              'Escanear código',
              icono: Icons.qr_code_scanner_rounded,
              onTap: _escanear,
            ),
          ),
          const SizedBox(height: AppEspaciado.md),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in _sugerencias)
                ChipApp(
                  texto: s,
                  activo: false,
                  onTap: () {
                    _texto.text = s;
                    _alEscribir(s);
                  },
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.lg),
          Center(
            child: TextButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Crear alimento a mano'),
            ),
          ),
        ] else if (_buscando && _resultados.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          VacioApp(
            icono: Icons.cloud_off_rounded,
            titulo: 'No se pudo buscar',
            texto: _error,
          )
        else if (_resultados.isEmpty && _buscado.isNotEmpty)
          VacioApp(
            icono: Icons.search_off_rounded,
            titulo: 'Sin resultados para «$_buscado»',
            texto: 'Prueba con otra palabra o créalo con su tabla nutricional.',
            accion: TextButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Crear alimento a mano'),
            ),
          )
        else ...[
          if (_buscando) const LinearProgressIndicator(minHeight: 2),
          GrupoFilas(
            filas: [
              for (final a in _resultados)
                InkWell(
                  onTap: () => _elegir(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        FotoAlimento(a),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.nombre,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColores.textoPrincipal,
                                ),
                              ),
                              Text(
                                '${a.marca != null ? '${a.marca} · ' : ''}'
                                '${Nutriente.kcal.formato(a.de('kcal'))} · '
                                'P ${Nutriente.proteina.formato(a.de('proteina'))} · '
                                'G ${Nutriente.grasa.formato(a.de('grasa'))} '
                                'por 100 g'
                                '${a.porcionNombre == null ? '' : '\n${a.porcionNombre} = ${gramosTexto(a.porcionG)}'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColores.textoSecundario,
                                ),
                              ),
                              const SizedBox(height: 4),
                              EtiquetasAlimento(a.etiquetas),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.add_circle_rounded,
                          color: AppColores.primario,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppEspaciado.sm),
          Center(
            child: TextButton.icon(
              onPressed: _crear,
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('¿No está? Créalo a mano'),
            ),
          ),
          const Text(
            'Datos de productos: Open Food Facts (openfoodfacts.org).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppColores.textoSecundario),
          ),
        ],
      ],
    );
  }
}
