import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

import 'analizador_escritura.dart';
import 'models/riesgo_resultado.dart';

/// El núcleo diferenciador de Raíz: analiza una foto de la escritura de un
/// estudiante y devuelve una alerta de riesgo.
///
/// ## Por qué empezar con una heurística y no con un modelo TFLite
/// Entrenar un modelo de visión confiable para dislexia/disgrafía necesita
/// un dataset etiquetado que hoy no existe (menos aún en español). Esta
/// versión mide marcadores de disgrafía conocidos en la literatura
/// (irregularidad del tamaño de letra, del espaciado entre palabras y de la
/// línea base) directamente sobre la foto, 100% en el celular. El roadmap es
/// complementarlo con un modelo `tflite_flutter` entrenado (ver assets/models/).
class DeteccionService {
  /// Punto de entrada único. Cambiar la implementación interna no debería
  /// afectar a quien llama esto desde la UI.
  ///
  /// Lanza [EscrituraInsuficienteException] si la foto no tiene suficiente
  /// escritura para medir: mejor avisar que inventar un resultado.
  Future<RiesgoResultado> analizarFoto(File foto) async {
    final bytes = await foto.readAsBytes();
    // El análisis recorre cada píxel: en otro isolate la UI no se congela.
    return Isolate.run(() => evaluar(bytes));
  }
}

/// Rangos de calibración por indicador: por debajo de `normal` no hay señal,
/// en `alto` o más la señal es máxima.
///
/// PROVISIONAL: `normal` sale de dos muestras reales con buena letra (un
/// dictado infantil a lápiz y una hoja adulta con esfero) y `alto` de
/// muestras sintéticas irregulares. Recalibrar con las 10–20 fotos reales
/// anonimizadas (usar [AnalizadorEscritura.diagnostico] para revisar).
const _tamano = (normal: 0.32, alto: 0.60);
const _espaciado = (normal: 0.40, alto: 0.90);
const _lineaBase = (normal: 0.18, alto: 0.50);

RiesgoResultado evaluar(Uint8List bytes) {
  final imagen = img.decodeImage(bytes);
  if (imagen == null) {
    throw const EscrituraInsuficienteException('No se pudo leer la imagen capturada.');
  }
  return interpretar(AnalizadorEscritura.medir(imagen));
}

RiesgoResultado interpretar(MedidasEscritura m) {
  double escalar(double valor, ({double normal, double alto}) r) =>
      ((valor - r.normal) / (r.alto - r.normal)).clamp(0.0, 1.0);

  final tamano = escalar(m.tamano, _tamano);
  final espaciado = escalar(m.espaciado, _espaciado);
  final lineaBase = escalar(m.lineaBase, _lineaBase);

  final puntaje = (0.4 * tamano + 0.3 * espaciado + 0.3 * lineaBase).clamp(0.0, 1.0);
  final nivel = puntaje < 0.35
      ? NivelRiesgo.bajo
      : puntaje < 0.65
          ? NivelRiesgo.medio
          : NivelRiesgo.alto;

  final senales = <String>[
    if (tamano >= 0.6)
      'El tamaño de las letras cambia mucho, incluso dentro de una misma línea.'
    else if (tamano >= 0.3)
      'El tamaño de las letras es algo irregular.',
    if (espaciado >= 0.6)
      'El espacio entre palabras es muy desigual: algunas quedan pegadas y otras muy separadas.'
    else if (espaciado >= 0.3)
      'El espacio entre palabras varía más de lo esperado.',
    if (lineaBase >= 0.6)
      'Las letras suben y bajan: la escritura no sigue la línea del renglón.'
    else if (lineaBase >= 0.3)
      'Algunas letras se salen un poco de la línea del renglón.',
  ];
  if (senales.isEmpty) {
    senales.add('El tamaño, el espaciado y la alineación de la escritura se ven regulares.');
  }
  if (m.renglones < 3) {
    senales.add('Se analizaron solo ${m.renglones} renglones: con una muestra más larga el resultado es más confiable.');
  }

  return RiesgoResultado(nivel: nivel, puntaje: puntaje, senales: senales);
}
