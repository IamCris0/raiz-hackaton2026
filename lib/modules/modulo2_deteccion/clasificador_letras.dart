import 'dart:typed_data';

import 'package:tflite_flutter/tflite_flutter.dart';

import 'analizador_escritura.dart';

/// Resultado de clasificar las letras sueltas de una muestra.
class ResultadoLetras {
  /// Letras sueltas analizadas.
  final int letras;

  /// Letras que el modelo marca como escritas en espejo (con confianza alta).
  final int invertidas;

  const ResultadoLetras({required this.letras, required this.invertidas});

  double get proporcion => letras == 0 ? 0 : invertidas / letras;

  @override
  String toString() => 'letras=$letras invertidas=$invertidas';
}

/// Clasifica cada letra en normal / invertida (espejo) con el modelo
/// `assets/models/letras_invertidas.tflite` (ver model/README.md).
///
/// Se crea a partir de los BYTES del modelo para poder usarlo dentro de un
/// isolate: el intérprete no se puede pasar entre isolates, los bytes sí.
class ClasificadorLetras {
  static const rutaModelo = 'assets/models/letras_invertidas.tflite';

  /// Solo cuenta como invertida si el modelo está muy seguro: preferimos
  /// perder alguna inversión antes que alarmar por error.
  static const confianzaMinima = 0.9;

  final Interpreter _interprete;

  ClasificadorLetras._(this._interprete);

  factory ClasificadorLetras.desdeBytes(Uint8List modelo) =>
      ClasificadorLetras._(Interpreter.fromBuffer(modelo));

  /// Probabilidad de "invertida" (0–1) para una letra ya normalizada
  /// (28x28, ver [AnalizadorEscritura.normalizarLetra]).
  double probabilidadInvertida(Float32List letra) {
    const lado = AnalizadorEscritura.ladoLetra;
    final entrada = [
      List.generate(lado, (y) => List.generate(lado, (x) => [letra[y * lado + x]])),
    ];
    final salida = [List<double>.filled(2, 0)];
    _interprete.run(entrada, salida);
    return salida[0][1];
  }

  ResultadoLetras clasificar(List<Float32List> letras) {
    var invertidas = 0;
    for (final l in letras) {
      if (probabilidadInvertida(l) >= confianzaMinima) invertidas++;
    }
    return ResultadoLetras(letras: letras.length, invertidas: invertidas);
  }

  void cerrar() => _interprete.close();
}
