import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/membresia_cliente.dart';
import 'package:xnox_app/features/publicidad/dominio/entidades/publicidad.dart';

/// Días antes del vencimiento en que se avisa al socio.
const diasAvisoVencimiento = 7;

/// Si a [m] le toca el aviso: tiene contrato y vence hoy o dentro de los
/// próximos 7 días. Sin contrato la fecha de vencimiento es "hoy" de relleno,
/// por eso se exige el contrato.
bool debeAvisarVencimiento(MembresiaCliente m) =>
    m.contratoId != null &&
    m.diasRestantes >= 0 &&
    m.diasRestantes <= diasAvisoVencimiento;

/// Sale al abrir la app (tras las novedades) y al cerrar los avisos: una sola
/// vez por sesión para no insistir.
bool _mostradoEnSesion = false;

/// Modal que avisa cuántos días le quedan a la membresía y lo invita a ver
/// las novedades del gimnasio (puede haber una promoción para renovar).
Future<void> mostrarAvisoVencimiento(
  BuildContext context, {
  required MembresiaCliente membresia,
  required List<Publicidad> novedades,
  required VoidCallback onRenovar,
  required VoidCallback onVerNovedades,
}) async {
  if (_mostradoEnSesion) return;
  _mostradoEnSesion = true;
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (ctx) => _AvisoVencimiento(
      membresia: membresia,
      novedades: novedades,
      onRenovar: () {
        Navigator.pop(ctx);
        onRenovar();
      },
      onVerNovedades: () {
        Navigator.pop(ctx);
        onVerNovedades();
      },
    ),
  );
}

class _AvisoVencimiento extends StatelessWidget {
  final MembresiaCliente membresia;
  final List<Publicidad> novedades;
  final VoidCallback onRenovar;
  final VoidCallback onVerNovedades;

  const _AvisoVencimiento({
    required this.membresia,
    required this.novedades,
    required this.onRenovar,
    required this.onVerNovedades,
  });

  String get _titulo => switch (membresia.diasRestantes) {
    0 => 'Tu membresía vence hoy',
    1 => 'Te queda 1 día',
    final d => 'Te quedan $d días',
  };

  @override
  Widget build(BuildContext context) {
    final dias = membresia.diasRestantes;
    final urgente = dias <= 2;
    final acento = urgente ? AppColores.moroso : AppColores.naranja;
    final fecha = DateFormat(
      "EEEE d 'de' MMMM",
      'es',
    ).format(membresia.fechaVencimiento);

    return Dialog(
      backgroundColor: AppColores.superficie,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cabecera(context, acento),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dias == 0
                        ? 'Renuévala hoy para seguir entrenando sin pausas.'
                        : 'Tu plan ${membresia.plan} vence el $fecha. '
                              'Renuévalo a tiempo y no pierdas tu ritmo.',
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: AppColores.textoSecundario,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _cuentaRegresiva(dias, acento),
                  if (novedades.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    _tarjetaNovedades(),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: onRenovar,
                      icon: const Icon(Icons.autorenew_rounded),
                      label: const Text('Ver mi membresía'),
                      style: ElevatedButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppEspaciado.radio,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Más tarde',
                        style: TextStyle(color: AppColores.textoSecundario),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cabecera(BuildContext context, Color acento) {
    final tinte = AppColores.primario;
    return SizedBox(
      height: 190,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/imagenes/inicio/membresia.jpg',
            fit: BoxFit.cover,
            alignment: const Alignment(0.3, -0.3),
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.15),
                  Color.lerp(
                    tinte,
                    Colors.black,
                    0.35,
                  )!.withValues(alpha: 0.92),
                ],
              ),
            ),
          ),
          Positioned(
            top: 10,
            right: 10,
            child: Material(
              color: Colors.black.withValues(alpha: 0.3),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () => Navigator.pop(context),
                child: const SizedBox(
                  width: 36,
                  height: 36,
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 20,
            right: 20,
            bottom: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: acento,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.schedule_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5),
                      Text(
                        'PRÓXIMA A VENCER',
                        style: TextStyle(
                          fontSize: 11,
                          letterSpacing: 0.8,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _titulo,
                  style: const TextStyle(
                    fontSize: 25,
                    height: 1.1,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Siete casillas: las que siguen encendidas son los días que quedan.
  Widget _cuentaRegresiva(int dias, Color acento) {
    return Row(
      children: [
        for (var i = 0; i < diasAvisoVencimiento; i++) ...[
          if (i > 0) const SizedBox(width: 5),
          Expanded(
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: i < dias ? acento : acento.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _tarjetaNovedades() {
    final imagen = novedades
        .map((p) => p.imagenUrl)
        .firstWhere((u) => u != null && u.isNotEmpty, orElse: () => null);
    return Material(
      color: AppColores.primario.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(AppEspaciado.radio),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppEspaciado.radio),
        onTap: onVerNovedades,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(AppEspaciado.radioSm),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: imagen == null
                      ? Container(
                          decoration: BoxDecoration(
                            gradient: AppColores.degradadoRelleno,
                          ),
                          child: Icon(
                            Icons.campaign_rounded,
                            color: AppColores.sobreRelleno,
                          ),
                        )
                      : Image.network(
                          imagen,
                          fit: BoxFit.cover,
                          cacheWidth: 200,
                          errorBuilder: (_, _, _) => Container(
                            color: AppColores.primario.withValues(alpha: 0.1),
                            child: Icon(
                              Icons.campaign_rounded,
                              color: AppColores.primario,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      novedades.length == 1
                          ? 'Mira la novedad del gimnasio'
                          : 'Mira las ${novedades.length} novedades del gimnasio',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColores.textoPrincipal,
                      ),
                    ),
                    const SizedBox(height: 2),
                    const Text(
                      'Tal vez haya una promoción de tu interés.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColores.textoSecundario,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColores.primario),
            ],
          ),
        ),
      ),
    );
  }
}
