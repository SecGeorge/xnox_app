import 'package:flutter/widgets.dart';
import 'package:xnox_app/core/database/empresa_dao.dart';
import 'package:xnox_app/core/network/http_service.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/features/ajustes/datos/repositorios/repositorio_ajustes_impl.dart';

/// Lo que identifica visualmente al gimnasio activo.
class MarcaGimnasio {
  final PaletaApp paleta;
  final String? logoUrl;
  final String? nombre;

  const MarcaGimnasio({required this.paleta, this.logoUrl, this.nombre});

  MarcaGimnasio copyWith({PaletaApp? paleta, String? logoUrl, String? nombre}) =>
      MarcaGimnasio(
        paleta: paleta ?? this.paleta,
        logoUrl: logoUrl ?? this.logoUrl,
        nombre: nombre ?? this.nombre,
      );
}

/// Marca (colores + logo) del gimnasio al que apunta la app.
///
/// La fuente de verdad es el servidor del gimnasio: `ajustes.php → obtener`
/// (no pide sesión, así que sirve ya en el login) devuelve el logo, el nombre
/// y la plantilla de colores que eligió el admin (`paleta_app`), y el admin la
/// cambia con `guardar_paleta`. Así todos los dispositivos que apuntan a esa
/// API se ven igual. La tabla `empresa` del SQLite guarda una copia para
/// pintar la app al abrir sin esperar a la red; si el gimnasio nunca eligió,
/// se usa la plantilla inicial de su código ([PaletasApp.inicialPara]).
class ControladorMarca with WidgetsBindingObserver {
  ControladorMarca._();
  static final ControladorMarca instancia = ControladorMarca._();

  final ValueNotifier<MarcaGimnasio> marca =
      ValueNotifier(const MarcaGimnasio(paleta: PaletasApp.porDefecto));

  PaletaApp get paleta => marca.value.paleta;

  bool _observando = false;

  /// Lee la marca guardada del gimnasio activo (sin red) y luego la refresca
  /// desde el servidor en segundo plano.
  Future<void> cargar() async {
    if (!_observando) {
      // Al volver a la app se consulta otra vez: si el admin cambió los
      // colores, los demás dispositivos los toman sin reiniciar.
      WidgetsBinding.instance.addObserver(this);
      _observando = true;
    }
    final empresa = await EmpresaDao.instancia.activa();
    final paleta = empresa?.paleta != null
        ? PaletasApp.porId(empresa!.paleta)
        : PaletasApp.inicialPara(empresa?.codigo);
    _aplicar(MarcaGimnasio(
      paleta: paleta,
      logoUrl: empresa?.logoUrl,
      nombre: empresa?.nombreComercial,
    ));
    if (empresa != null) {
      // Sin await: el arranque no espera a la red.
      refrescar();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refrescar();
  }

  /// Pide al servidor del gimnasio activo su logo, nombre y colores, los
  /// aplica y los guarda en el SQLite.
  Future<void> refrescar() async {
    try {
      final empresa = await EmpresaDao.instancia.activa();
      if (empresa == null) return;
      final datos =
          await RepositorioAjustesImpl(HttpService()).obtenerDatosNegocio();
      final nombre = datos.nombre.trim().isEmpty ? null : datos.nombre.trim();
      // Sin respuesta del servidor (datos vacíos) se conserva lo guardado.
      if (datos.logoUrl == null && nombre == null && datos.paletaApp == null) {
        return;
      }
      await EmpresaDao.instancia.guardarMarca(empresa.id,
          logoUrl: datos.logoUrl, nombreComercial: nombre);
      var paletaNueva = paleta;
      if (datos.paletaApp != null) {
        paletaNueva = PaletasApp.porId(datos.paletaApp);
        await EmpresaDao.instancia.guardarPaleta(empresa.id, paletaNueva.id);
      }
      _aplicar(MarcaGimnasio(
        paleta: paletaNueva,
        logoUrl: datos.logoUrl,
        nombre: nombre,
      ));
    } catch (e) {
      debugPrint('[MARCA] no se pudo refrescar la marca: $e');
    }
  }

  /// El admin elige los colores: se guardan en el servidor (para todos los
  /// dispositivos del gimnasio) y luego se aplican aquí. Devuelve `null` si
  /// salió bien o el mensaje de error; si falla, la app no cambia de colores.
  Future<String?> elegirPaleta(PaletaApp nueva) async {
    final String? error;
    try {
      error = await RepositorioAjustesImpl(HttpService()).guardarPaleta(nueva.id);
    } catch (_) {
      return 'No se pudo conectar con el servidor. Intenta de nuevo.';
    }
    if (error != null) return error;
    _aplicar(marca.value.copyWith(paleta: nueva));
    final empresa = await EmpresaDao.instancia.activa();
    if (empresa != null) {
      await EmpresaDao.instancia.guardarPaleta(empresa.id, nueva.id);
    }
    return null;
  }

  void _aplicar(MarcaGimnasio nueva) {
    final cambiaColores = nueva.paleta.id != AppColores.paleta.id;
    AppColores.aplicar(nueva.paleta);
    marca.value = nueva;
    if (cambiaColores) _redibujarTodo();
  }

  /// Los colores se leen de [AppColores] al construir cada widget, así que al
  /// cambiar de paleta hay que reconstruir el árbol entero (sin perder la
  /// navegación ni el estado de las pantallas abiertas).
  void _redibujarTodo() {
    final raiz = WidgetsBinding.instance.rootElement;
    if (raiz == null) return;
    void marcar(Element e) {
      e.markNeedsBuild();
      e.visitChildren(marcar);
    }

    raiz.visitChildren(marcar);
  }
}
