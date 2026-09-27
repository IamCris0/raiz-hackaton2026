import 'package:flutter_test/flutter_test.dart';
import 'package:raiz_app/modules/modulo2_deteccion/models/riesgo_resultado.dart';
import 'package:raiz_app/modules/modulo3_dashboard/models/registro_estudiante.dart';

void main() {
  test('un registro guarda y recupera señales, observaciones y la imagen', () {
    final original = RegistroEstudiante(
      nombreEstudiante: 'Estudiante 1',
      grado: '3.º EGB',
      nivel: NivelRiesgo.medio,
      puntaje: 0.42,
      fecha: DateTime(2026, 9, 27, 10, 30),
      senales: ['Las letras suben y bajan: la escritura no sigue la línea del renglón.'],
      observaciones: ['El tamaño de las letras es algo irregular.'],
      vistaRuta: '/datos/evaluaciones/1.jpg',
    );
    final leido = RegistroEstudiante.fromMap(original.toMap()..['id'] = 7);

    expect(leido.id, 7);
    expect(leido.nivel, NivelRiesgo.medio);
    expect(leido.senales, original.senales);
    expect(leido.observaciones, original.observaciones);
    expect(leido.vistaRuta, original.vistaRuta);
  });

  test('los registros guardados antes de la versión 3 se leen sin detalle', () {
    final viejo = RegistroEstudiante.fromMap({
      'id': 1,
      'nombre_estudiante': 'Estudiante 2',
      'grado': null,
      'nivel': 'bajo',
      'puntaje': 0.1,
      'fecha': '2026-09-26T12:00:00.000',
    });
    expect(viejo.senales, isEmpty);
    expect(viejo.observaciones, isEmpty);
    expect(viejo.vistaRuta, isNull);
  });
}
