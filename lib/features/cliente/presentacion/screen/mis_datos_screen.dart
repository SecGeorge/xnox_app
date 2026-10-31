import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:xnox_app/core/tema/app_tema.dart';
import 'package:xnox_app/core/widgets/diseno_app.dart';
import 'package:xnox_app/features/cliente/datos/repositorio_datos_socio.dart';
import 'package:xnox_app/features/cliente/dominio/entidades/datos_socio.dart';

/// El socio completa lo que el gimnasio no le pidió al registrarlo. Todo es
/// opcional, y el gimnasio lo ve en la ficha del miembro.
class MisDatosScreen extends StatefulWidget {
  /// Solo para pruebas: por defecto habla con `miembros.php`.
  final RepositorioDatosSocio? repositorio;

  const MisDatosScreen({super.key, this.repositorio});

  @override
  State<MisDatosScreen> createState() => _MisDatosScreenState();
}

class _MisDatosScreenState extends State<MisDatosScreen> {
  late final _repo = widget.repositorio ?? RepositorioDatosSocio();

  final _direccion = TextEditingController();
  final _enfermedad = TextEditingController();
  final _institucion = TextEditingController();
  final _nombreContacto = TextEditingController();
  final _telefonoContacto = TextEditingController();

  DateTime? _nacimiento;
  bool _sufreEnfermedad = false;
  bool _tieneSeguro = false;
  bool _cargando = true;
  String? _error;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _direccion.dispose();
    _enfermedad.dispose();
    _institucion.dispose();
    _nombreContacto.dispose();
    _telefonoContacto.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final d = await _repo.obtener();
      if (!mounted) return;
      _direccion.text = d.direccion;
      _enfermedad.text = d.enfermedad;
      _institucion.text = d.institucion;
      _nombreContacto.text = d.nombreContacto;
      _telefonoContacto.text = d.telefonoContacto;
      setState(() {
        _nacimiento = d.fechaNacimiento;
        _sufreEnfermedad = d.sufreEnfermedad;
        _tieneSeguro = d.tieneSeguro;
        _cargando = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _cargando = false;
        });
      }
    }
  }

  Future<void> _elegirNacimiento() async {
    final hoy = DateTime.now();
    final elegida = await showDatePicker(
      context: context,
      initialDate: _nacimiento ?? DateTime(hoy.year - 25),
      firstDate: DateTime(1920),
      lastDate: hoy,
      initialEntryMode: DatePickerEntryMode.calendarOnly,
      initialDatePickerMode: DatePickerMode.year,
    );
    if (elegida != null) setState(() => _nacimiento = elegida);
  }

  Future<void> _guardar() async {
    FocusScope.of(context).unfocus();
    setState(() => _guardando = true);
    final error = await _repo.guardar(
      DatosSocio(
        fechaNacimiento: _nacimiento,
        direccion: _direccion.text.trim(),
        sufreEnfermedad: _sufreEnfermedad,
        enfermedad: _enfermedad.text.trim(),
        tieneSeguro: _tieneSeguro,
        institucion: _institucion.text.trim(),
        nombreContacto: _nombreContacto.text.trim(),
        telefonoContacto: _telefonoContacto.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _guardando = false);
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(error ?? 'Tus datos se guardaron')));
  }

  Widget _campo(
    TextEditingController controlador,
    String etiqueta, {
    IconData? icono,
    TextInputType? teclado,
    int maximo = 255,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: TextField(
        controller: controlador,
        keyboardType: teclado,
        maxLength: maximo,
        textCapitalization: teclado == null
            ? TextCapitalization.sentences
            : TextCapitalization.none,
        decoration: InputDecoration(
          labelText: etiqueta,
          counterText: '',
          prefixIcon: icono == null ? null : Icon(icono),
        ),
      ),
    );
  }

  Widget _campoNacimiento() {
    final fecha = _nacimiento;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppEspaciado.sm + 4),
      child: InkWell(
        onTap: _elegirNacimiento,
        child: InputDecorator(
          isEmpty: fecha == null,
          decoration: InputDecoration(
            labelText: 'Fecha de nacimiento',
            prefixIcon: const Icon(Icons.cake_rounded),
            suffixIcon: fecha == null
                ? null
                : IconButton(
                    tooltip: 'Quitar fecha',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _nacimiento = null),
                  ),
          ),
          child: Text(
            fecha == null
                ? ''
                : DateFormat("d 'de' MMMM 'de' yyyy", 'es').format(fecha),
          ),
        ),
      ),
    );
  }

  /// Interruptor con su campo de detalle, que solo sale si dice que sí.
  Widget _conDetalle({
    required String pregunta,
    required bool valor,
    required ValueChanged<bool> alCambiar,
    required TextEditingController controlador,
    required String etiqueta,
  }) {
    return Column(
      children: [
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(pregunta),
          value: valor,
          onChanged: alCambiar,
        ),
        if (valor) _campo(controlador, etiqueta),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final listo = !_cargando && _error == null;
    return PantallaApp(
      onRefresh: _cargar,
      espacioAbajo: AppEspaciado.lg,
      pie: listo
          ? PieBoton(
              texto: 'Guardar mis datos',
              icono: Icons.check_rounded,
              cargando: _guardando,
              onPressed: _guardando ? null : _guardar,
            )
          : null,
      children: [
        const CabeceraApp(
          titulo: 'Mis datos',
          subtitulo:
              'Completa lo que quieras: tu gimnasio los verá en tu ficha',
        ),
        const SizedBox(height: AppEspaciado.md + 4),
        if (_cargando)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          VacioApp(
            icono: Icons.cloud_off_rounded,
            titulo: 'No se pudieron cargar tus datos',
            texto: '$_error. Desliza hacia abajo para reintentar.',
          )
        else ...[
          const TituloSeccion(
            icono: Icons.person_rounded,
            titulo: 'Datos personales',
          ),
          _campoNacimiento(),
          _campo(_direccion, 'Dirección', icono: Icons.home_rounded),
          const SizedBox(height: AppEspaciado.sm),
          const TituloSeccion(
            icono: Icons.favorite_rounded,
            titulo: 'Salud y seguro',
          ),
          _conDetalle(
            pregunta: '¿Tienes alguna enfermedad?',
            valor: _sufreEnfermedad,
            alCambiar: (v) => setState(() => _sufreEnfermedad = v),
            controlador: _enfermedad,
            etiqueta: '¿Cuál o cuáles?',
          ),
          _conDetalle(
            pregunta: '¿Tienes seguro?',
            valor: _tieneSeguro,
            alCambiar: (v) => setState(() => _tieneSeguro = v),
            controlador: _institucion,
            etiqueta: '¿Cuál seguro?',
          ),
          const SizedBox(height: AppEspaciado.md),
          const TituloSeccion(
            icono: Icons.emergency_rounded,
            titulo: 'Contacto en caso de accidente',
          ),
          _campo(_nombreContacto, 'Nombre', icono: Icons.badge_rounded),
          _campo(
            _telefonoContacto,
            'Teléfono',
            icono: Icons.phone_rounded,
            teclado: TextInputType.phone,
            maximo: 20,
          ),
        ],
      ],
    );
  }
}
