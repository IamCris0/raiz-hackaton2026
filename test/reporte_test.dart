import 'package:flutter_test/flutter_test.dart';
import 'package:raiz_app/core/constants/app_constants.dart';
import 'package:raiz_app/modules/modulo2_deteccion/models/riesgo_resultado.dart';
import 'package:raiz_app/shared/reporte.dart';

void main() {
  test('el reporte incluye resultado, señales, observaciones y el aviso ético', () {
    final texto = textoReporte(
      nombre: 'Estudiante 1',
      grado: '3.º EGB',
      fecha: DateTime(2026, 9, 27, 10, 30),
      nivel: NivelRiesgo.alto,
      puntaje: 0.9,
      senales: ['Las letras suben y bajan: la escritura no sigue la línea del renglón.'],
      observaciones: ['El tamaño de las letras es algo irregular.'],
    );

    expect(texto, contains('Estudiante 1 · 3.º EGB'));
    expect(texto, contains('27/09/2026 · 10:30'));
    expect(texto, contains('Riesgo alto (índice 90 de 100)'));
    expect(texto, contains('• Las letras suben y bajan'));
    expect(texto, contains('Observaciones (no cambian el índice)'));
    expect(texto, contains('1. Informar al DECE'));
    expect(texto, contains(AppConstants.avisoNoDiagnostico));
  });

  test('sin señales ni observaciones no deja secciones vacías', () {
    final texto = textoReporte(
      nombre: 'Estudiante 2',
      fecha: DateTime(2026, 9, 27),
      nivel: NivelRiesgo.bajo,
      puntaje: 0.05,
      senales: const [],
    );
    expect(texto, isNot(contains('Señales detectadas')));
    expect(texto, isNot(contains('Observaciones')));
    expect(texto, contains(AppConstants.avisoNoDiagnostico));
  });
}
