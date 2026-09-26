import 'dart:io';
import 'package:image/image.dart' as img;

import 'models/riesgo_resultado.dart';

/// El núcleo diferenciador de Raíz: analiza una foto de la escritura de un
/// estudiante y devuelve una alerta de riesgo.
///
/// ## Por qué empezar con una heurística y no con un modelo TFLite
/// Entrenar un modelo de visión confiable para dislexia/disgrafía necesita
/// un dataset etiquetado que hoy no existe. Para tener un prototipo
/// demostrable en el plazo del hackatón, la primera versión usa una
/// heurística basada en marcadores conocidos de disgrafía en la literatura
/// (variabilidad del tamaño de letra, espaciado irregular entre palabras,
/// desalineación respecto a la línea base). Es intencionalmente simple y
/// transparente sobre sus límites — el roadmap real es reemplazar
/// [_analizarHeuristica] por inferencia con `tflite_flutter` una vez exista
/// un modelo entrenado (ver assets/models/).
class DeteccionService {
  /// Punto de entrada único. Cambiar la implementación interna no debería
  /// afectar a quien llama esto desde la UI.
  Future<RiesgoResultado> analizarFoto(File foto) async {
    final bytes = await foto.readAsBytes();
    final imagen = img.decodeImage(bytes);
    if (imagen == null) {
      throw Exception('No se pudo leer la imagen capturada.');
    }
    return _analizarHeuristica(imagen);
  }

  RiesgoResultado _analizarHeuristica(img.Image imagen) {
    // TODO(equipo): implementar los 3 marcadores reales:
    //   1. Variabilidad del tamaño de letra (detección de contornos + bounding boxes)
    //   2. Espaciado irregular entre palabras/letras
    //   3. Desalineación respecto a la línea base
    // Por ahora placeholder para que la UI y el flujo end-to-end ya
    // funcionen mientras se afina el análisis real de imagen.
    const senalesPlaceholder = <String>[
      'Análisis de imagen pendiente de calibrar — resultado de ejemplo',
    ];

    return RiesgoResultado(
      nivel: NivelRiesgo.medio,
      puntaje: 0.5,
      senales: senalesPlaceholder,
    );
  }

  // Cuando exista un modelo entrenado:
  //
  // Future<RiesgoResultado> _analizarConModelo(img.Image imagen) async {
  //   final interpreter = await Interpreter.fromAsset('models/deteccion.tflite');
  //   ...
  // }
}
