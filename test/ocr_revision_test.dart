import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:raiz_app/modules/modulo1_ocr/diccionario.dart';
import 'package:raiz_app/modules/modulo1_ocr/ocr_service.dart';
import 'package:raiz_app/modules/modulo1_ocr/texto_revisado.dart';
import 'package:raiz_app/modules/modulo2_deteccion/analizador_escritura.dart';

import 'helpers/hoja_sintetica.dart';

void main() {
  // El diccionario real que va en la app.
  final dic = Diccionario.desdeTexto(File(OcrService.rutaDiccionario).readAsStringSync());

  group('Diccionario', () {
    test('carga las 30 000 palabras', () {
      expect(dic.tamano, 30000);
      expect(dic.conoce('perro'), isTrue);
      expect(dic.conoce('Perro'), isTrue);
      expect(dic.conoce('qulere'), isFalse);
    });

    test('sugiere la palabra correcta ante errores típicos del OCR', () {
      expect(dic.sugerencias('qulere').first, 'quiere'); // l por i
      expect(dic.sugerencias('perrc').first, 'perro'); // c por o
      expect(dic.sugerencias('rnama'), contains('mama')); // rn por m
      expect(dic.sugerencias('ciudacl'), contains('ciudad')); // cl por d
      expect(dic.sugerencias('escuala').first, 'escuela'); // a por e
    });

    test('solo arregla solo los dígitos/símbolos cuando queda una palabra real', () {
      expect(dic.arregloSeguro('c0sa'), 'cosa');
      expect(dic.arregloSeguro('ca5a'), 'casa');
      expect(dic.arregloSeguro('2024'), isNull); // un número no se toca
      expect(dic.arregloSeguro('qulere'), isNull); // sin dígitos: no se toca
    });

    test('la distancia casi no penaliza las tildes', () {
      expect(distanciaOcr('arbol', 'árbol', 2), lessThan(0.2));
      expect(distanciaOcr('rnano', 'mano', 2), lessThan(0.5));
      expect(distanciaOcr('perro', 'gato', 2), greaterThan(2));
    });
  });

  group('revisarTexto', () {
    test('marca las dudosas, arregla solo los dígitos y conserva signos', () {
      final r = revisarTexto('¿El perrc come c0sa?\nMi mama me qulere.', dic);
      final p = r.palabras.toList();

      expect(r.renglones.length, 2);
      expect(p[0].completa, '¿El');
      expect(p[1].estado, EstadoPalabra.dudosa);
      expect(p[1].sugerencias.first, 'perro');
      expect(p[3].estado, EstadoPalabra.corregidaAuto);
      expect(p[3].completa, 'cosa?');
      expect(p.last.estado, EstadoPalabra.dudosa);
      expect(p.last.sufijo, '.');
      expect(r.porRevisar, 2);
    });

    test('nunca cambia sola una palabra dudosa (puede ser error del estudiante)', () {
      final r = revisarTexto('mi mama me qulere', dic);
      expect(r.texto, 'mi mama me qulere');
      final dudosa = r.palabras.last;
      dudosa.resolver(dudosa.sugerencias.first);
      expect(r.texto, 'mi mama me quiere');
      expect(r.porRevisar, 0);
    });

    test('respeta mayúsculas en las sugerencias', () {
      expect(revisarTexto('Qulere', dic).palabras.first.sugerencias.first, 'Quiere');
      expect(conMayusculas('casa', 'CASA'), 'CASA');
    });

    test('la lectura con más palabras reales gana', () {
      final mala = revisarTexto('el pcrrc cc rne c0rne', dic);
      final buena = revisarTexto('el perro me come', dic, fuente: 'mejorada');
      expect(mejorLectura([mala, buena]).fuente, 'mejorada');
      expect(buena.calidad, greaterThan(mala.calidad));
    });
  });

  test('imagenLimpia deja la escritura en negro sobre blanco y borra los renglones', () {
    final hoja = hojaSintetica(irregular: false);
    final limpia = AnalizadorEscritura.imagenLimpia(hoja);
    expect(limpia.width, hoja.width);
    // Un renglón del cuaderno (y = 60, en una zona sin letras) queda blanco.
    expect(limpia.getPixel(10, 60).r, 255);
    // Hay tinta negra (texto) en alguna parte.
    expect(limpia.any((p) => p.r == 0), isTrue);
  });
}
