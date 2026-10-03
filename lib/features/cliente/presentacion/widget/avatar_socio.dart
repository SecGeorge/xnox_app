import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/hoja_moderna.dart';
import 'package:xnox_app/features/cliente/presentacion/controlador/controlador_foto_perfil.dart';

/// Avatar redondo del socio: su foto de perfil o, si no tiene, la inicial
/// sobre el color de la marca. Con [editable] lleva una cámara para cambiarla.
class AvatarSocio extends StatelessWidget {
  final double tamano;
  final String nombre;
  final bool editable;
  final VoidCallback? onTap;

  const AvatarSocio({
    super.key,
    this.tamano = 46,
    required this.nombre,
    this.editable = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? (editable ? () => cambiarFotoPerfil(context) : null),
      child: ValueListenableBuilder<String?>(
        valueListenable: ControladorFotoPerfil.instancia.url,
        builder: (context, url, _) {
          final inicial = Text(
            nombre.isEmpty ? '?' : nombre.characters.first.toUpperCase(),
            style: TextStyle(
              fontSize: tamano * 0.41,
              fontWeight: FontWeight.w800,
              color: AppColores.sobreRelleno,
            ),
          );
          return SizedBox(
            width: tamano,
            height: tamano,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: tamano,
                  height: tamano,
                  alignment: Alignment.center,
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    gradient: AppColores.degradadoRelleno,
                    shape: BoxShape.circle,
                    border: AppColores.bordeCabecera,
                  ),
                  child: url == null
                      ? inicial
                      : Image.network(
                          url,
                          width: tamano,
                          height: tamano,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => inicial,
                        ),
                ),
                ValueListenableBuilder<bool>(
                  valueListenable: ControladorFotoPerfil.instancia.subiendo,
                  builder: (_, subiendo, _) => subiendo
                      ? Container(
                          width: tamano,
                          height: tamano,
                          padding: EdgeInsets.all(tamano * 0.28),
                          decoration: const BoxDecoration(
                            color: Colors.black45,
                            shape: BoxShape.circle,
                          ),
                          child: const CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                if (editable)
                  Positioned(
                    right: -2,
                    bottom: -2,
                    child: Container(
                      width: tamano * 0.36,
                      height: tamano * 0.36,
                      decoration: BoxDecoration(
                        color: AppColores.primario,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColores.superficie,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.photo_camera_rounded,
                        size: tamano * 0.19,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Pregunta de dónde sacar la foto (cámara o galería), la sube y avisa.
Future<void> cambiarFotoPerfil(BuildContext context) async {
  final origen = await mostrarHojaModerna<ImageSource>(
    context,
    builder: (ctx) => HojaModerna(
      icono: Icons.account_circle_rounded,
      titulo: 'Foto de perfil',
      subtitulo: 'El gimnasio también la verá en tu ficha',
      child: Row(
        children: [
          Expanded(
            child: _opcion(
              Icons.photo_camera_rounded,
              'Tomar foto',
              () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ),
          const SizedBox(width: AppEspaciado.sm + 2),
          Expanded(
            child: _opcion(
              Icons.photo_library_rounded,
              'Galería',
              () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ),
        ],
      ),
    ),
  );
  if (origen == null || !context.mounted) return;

  final messenger = ScaffoldMessenger.of(context);
  final error = await ControladorFotoPerfil.instancia.cambiar(origen);
  if (error == null) return;
  messenger.showSnackBar(
    SnackBar(
      content: Text(error.isEmpty ? 'Foto de perfil actualizada' : error),
      backgroundColor: error.isEmpty ? AppColores.exito : AppColores.moroso,
    ),
  );
}

Widget _opcion(IconData icono, String texto, VoidCallback onTap) {
  return Material(
    color: AppColores.fondo,
    borderRadius: BorderRadius.circular(AppEspaciado.radio),
    child: InkWell(
      borderRadius: BorderRadius.circular(AppEspaciado.radio),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColores.primario.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icono, color: AppColores.primario, size: 26),
            ),
            const SizedBox(height: 10),
            Text(
              texto,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColores.textoPrincipal,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
