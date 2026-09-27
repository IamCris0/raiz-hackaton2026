import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:raiz_app/modules/modulo2_deteccion/analizador_escritura.dart';
import 'package:raiz_app/modules/modulo2_deteccion/deteccion_service.dart';
import 'package:raiz_app/modules/modulo2_deteccion/models/riesgo_resultado.dart';

const _frases = [
  'en un lejano bosque vivia una',
  'brujita llamada patricia ella',
  'hacia hechizos para convertir',
  'animales en personas y asi poder',
  'jugar con ellos un dia atrapo',
];

/// Hoja sintética: renglones de cuaderno + texto. Con [irregular], cada
/// palabra cambia de tamaño, se sale del renglón y el espacio varía.
img.Image _hoja({required bool irregular, int semilla = 7}) {
  final azar = Random(semilla);
  final hoja = img.Image(width: 1000, height: 800);
  img.fill(hoja, color: img.ColorRgb8(248, 248, 244));
  for (var y = 60; y < 800; y += 55) {
    img.drawLine(hoja, x1: 0, y1: y, x2: 999, y2: y, color: img.ColorRgb8(170, 190, 215));
  }

  final tinta = img.ColorRgb8(40, 40, 40);
  for (var i = 0; i < _frases.length; i++) {
    var x = 80;
    final base = 110 + i * 130;
    for (final palabra in _frases[i].split(' ')) {
      final fuente = irregular && azar.nextBool() ? img.arial24 : img.arial48;
      final dy = irregular ? azar.nextInt(40) - 20 : 0;
      img.drawString(hoja, palabra, font: fuente, x: x, y: base - fuente.lineHeight + dy, color: tinta);
      final ancho = palabra.codeUnits.fold<int>(0, (s, c) => s + (fuente.characters[c]?.xAdvance ?? fuente.base));
      x += ancho + (irregular ? 10 + azar.nextInt(70) : 30);
    }
  }
  return hoja;
}

void main() {
  test('la escritura irregular mide más alto que la regular en los 3 indicadores', () {
    final regular = AnalizadorEscritura.medir(_hoja(irregular: false));
    final irregular = AnalizadorEscritura.medir(_hoja(irregular: true));
    // ignore: avoid_print
    print('regular:   $regular\nirregular: $irregular');

    expect(regular.renglones, _frases.length);
    expect(irregular.tamano, greaterThan(regular.tamano));
    expect(irregular.espaciado, greaterThan(regular.espaciado));
    expect(irregular.lineaBase, greaterThan(regular.lineaBase));
  });

  test('el semáforo marca bajo lo regular y sube con lo irregular', () {
    final regular = interpretar(AnalizadorEscritura.medir(_hoja(irregular: false)));
    final irregular = interpretar(AnalizadorEscritura.medir(_hoja(irregular: true)));

    expect(regular.nivel, NivelRiesgo.bajo);
    expect(irregular.nivel, isNot(NivelRiesgo.bajo));
    expect(irregular.puntaje, greaterThan(regular.puntaje));
    expect(irregular.senales.join(), contains('renglón'));
  });

  test('una hoja sin escritura avisa en vez de inventar un resultado', () {
    final vacia = img.Image(width: 800, height: 1000);
    img.fill(vacia, color: img.ColorRgb8(250, 250, 250));
    expect(() => AnalizadorEscritura.medir(vacia), throwsA(isA<EscrituraInsuficienteException>()));
  });
}
