import 'package:flutter/material.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/recomendaciones/datos/repositorio_recomendaciones.dart';
import 'package:xnox_app/features/recomendaciones/presentacion/screen/recomendaciones_screen.dart';

/// Acceso al buzón de recomendaciones con el contador de las no leídas, para
/// el encabezado de las secciones del administrador. Mismo tratamiento que la
/// campana de avisos: es autónomo, carga su propio conteo y lo refresca al
/// volver de la bandeja.
///
/// Quien lo coloque debe comprobar antes el permiso `mobile_recomendaciones`:
/// el widget no lo valida.
class BuzonRecomendaciones extends StatefulWidget {
  /// Color del ícono. En un AppBar (fondo oscuro) se deja `null` para heredar
  /// el blanco; en encabezados claros se pasa el color primario.
  final Color? color;

  const BuzonRecomendaciones({super.key, this.color});

  @override
  State<BuzonRecomendaciones> createState() => _BuzonRecomendacionesState();
}

class _BuzonRecomendacionesState extends State<BuzonRecomendaciones> {
  final _repositorio = RepositorioRecomendaciones();
  int _pendientes = 0;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final pendientes = await _repositorio.pendientes();
      if (!mounted) return;
      setState(() => _pendientes = pendientes);
    } catch (_) {
      // El contador es secundario: si falla, el acceso sigue funcionando.
    }
  }

  Future<void> _abrir() async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RecomendacionesScreen()),
    );
    await _cargar();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: _abrir,
      tooltip: 'Recomendaciones',
      color: widget.color,
      icon: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(_pendientes > 0
              ? Icons.rate_review
              : Icons.rate_review_outlined),
          if (_pendientes > 0)
            Positioned(
              right: -4,
              top: -4,
              child: Container(
                padding: const EdgeInsets.all(3),
                constraints:
                    const BoxConstraints(minWidth: 16, minHeight: 16),
                decoration: const BoxDecoration(
                  color: AppColores.moroso,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  _pendientes > 9 ? '9+' : '$_pendientes',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    height: 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
