import 'package:flutter_test/flutter_test.dart';
import 'package:xnox_app/features/nutricion/dominio/nutricion.dart';

void main() {
  const pollo = Alimento(
    id: 1,
    nombre: 'Pechuga de pollo a la plancha',
    porcionG: 150,
    porcionNombre: '1 filete',
  );
  const atun = Alimento(
    id: 2,
    nombre: 'Atún en agua',
    porcionG: 120,
    porcionNombre: '1 lata escurrida',
  );
  const palta = Alimento(
    id: 3,
    nombre: 'Palta',
    porcionG: 100,
    porcionNombre: '1/2 palta',
  );

  test('gramos con su equivalencia en porciones', () {
    expect(pollo.cantidadTexto(150), '150 g · 1 filete');
    expect(pollo.cantidadTexto(75), '75 g · ½ filete');
    expect(pollo.cantidadTexto(300), '300 g · 2 filetes');
    expect(atun.cantidadTexto(240), '240 g · 2 latas escurridas');
  });

  test('solo gramos si no es un múltiplo claro o la porción no tiene unidad', () {
    expect(pollo.cantidadTexto(137), '137 g');
    expect(palta.cantidadTexto(100), '100 g');
    expect(gramosTexto(62.5), '62.5 g');
  });
}
