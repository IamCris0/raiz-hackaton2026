import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:raiz_app/modules/modulo2_deteccion/analizador_escritura.dart';
import 'package:raiz_app/modules/modulo2_deteccion/deteccion_service.dart';
import 'package:raiz_app/modules/modulo2_deteccion/models/riesgo_resultado.dart';

import 'helpers/hoja_sintetica.dart';

void main() {
  test('la escritura irregular mide más alto que la regular en los 3 indicadores', () {
    final regular = AnalizadorEscritura.medir(hojaSintetica(irregular: false));
    final irregular = AnalizadorEscritura.medir(hojaSintetica(irregular: true));
    // ignore: avoid_print
    print('regular:   $regular\nirregular: $irregular');

    expect(regular.renglones, frasesSinteticas.length);
    expect(irregular.tamano, greaterThan(regular.tamano));
    expect(irregular.espaciado, greaterThan(regular.espaciado));
    expect(irregular.lineaBase, greaterThan(regular.lineaBase));
  });

  test('el semáforo marca bajo lo regular y sube con lo irregular', () {
    final regular = interpretar(AnalizadorEscritura.medir(hojaSintetica(irregular: false)));
    final irregular = interpretar(AnalizadorEscritura.medir(hojaSintetica(irregular: true)));

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
