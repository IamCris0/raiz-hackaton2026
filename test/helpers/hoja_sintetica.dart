import 'dart:math';

import 'package:image/image.dart' as img;

const frasesSinteticas = [
  'en un lejano bosque vivia una',
  'brujita llamada patricia ella',
  'hacia hechizos para convertir',
  'animales en personas y asi poder',
  'jugar con ellos un dia atrapo',
];

/// Hoja sintética: renglones de cuaderno + texto. Con [irregular], cada
/// palabra cambia de tamaño, se sale del renglón y el espacio varía.
img.Image hojaSintetica({required bool irregular, int semilla = 7}) {
  final azar = Random(semilla);
  final hoja = img.Image(width: 1000, height: 800);
  img.fill(hoja, color: img.ColorRgb8(248, 248, 244));
  for (var y = 60; y < 800; y += 55) {
    img.drawLine(hoja, x1: 0, y1: y, x2: 999, y2: y, color: img.ColorRgb8(170, 190, 215));
  }

  final tinta = img.ColorRgb8(40, 40, 40);
  for (var i = 0; i < frasesSinteticas.length; i++) {
    var x = 80;
    final base = 110 + i * 130;
    for (final palabra in frasesSinteticas[i].split(' ')) {
      final fuente = irregular && azar.nextBool() ? img.arial24 : img.arial48;
      final dy = irregular ? azar.nextInt(40) - 20 : 0;
      img.drawString(hoja, palabra, font: fuente, x: x, y: base - fuente.lineHeight + dy, color: tinta);
      final ancho = palabra.codeUnits.fold<int>(0, (s, c) => s + (fuente.characters[c]?.xAdvance ?? fuente.base));
      x += ancho + (irregular ? 10 + azar.nextInt(70) : 30);
    }
  }
  return hoja;
}

