import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;

import 'analizador_escritura.dart';
import 'clasificador_letras.dart';
import 'models/riesgo_resultado.dart';

/// El núcleo diferenciador de Raíz: analiza una foto de la escritura de un
/// estudiante y devuelve una alerta de riesgo.
///
/// ## Por qué empezar con una heurística y no con un modelo TFLite
/// Entrenar un modelo de visión confiable para dislexia/disgrafía necesita
/// un dataset etiquetado que hoy no existe (menos aún en español). Esta
/// versión mide marcadores de disgrafía conocidos en la literatura
/// (irregularidad del tamaño de letra, del espaciado entre palabras y de la
/// línea base) directamente sobre la foto, 100% en el celular, y lo
/// complementa con un modelo TFLite que detecta letras escritas en espejo
/// (señal de dislexia; ver model/README.md y [ClasificadorLetras]).
class DeteccionService {
  static Uint8List? _modelo;
  static bool _modeloIntentado = false;

  /// Punto de entrada único. Cambiar la implementación interna no debería
  /// afectar a quien llama esto desde la UI.
  ///
  /// Lanza [EscrituraInsuficienteException] si la foto no tiene suficiente
  /// escritura para medir: mejor avisar que inventar un resultado.
  Future<RiesgoResultado> analizarFoto(File foto) async {
    final bytes = await foto.readAsBytes();
    final modelo = await _cargarModelo();
    // El análisis recorre cada píxel: en otro isolate la UI no se congela.
    // El modelo viaja como bytes; el intérprete se crea dentro del isolate.
    return Isolate.run(() => evaluar(bytes, modelo: modelo));
  }

  /// Los assets solo se leen desde el isolate principal. Si el modelo no
  /// está (o falla), la app sigue funcionando sin la señal de inversiones.
  static Future<Uint8List?> _cargarModelo() async {
    if (_modeloIntentado) return _modelo;
    _modeloIntentado = true;
    try {
      final datos = await rootBundle.load(ClasificadorLetras.rutaModelo);
      _modelo = datos.buffer.asUint8List(datos.offsetInBytes, datos.lengthInBytes);
    } catch (_) {
      _modelo = null;
    }
    return _modelo;
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

/// % de letras en espejo. PROVISIONAL, igual que los demás: recalibrar con
/// dictados reales.
const _inversiones = (normal: 0.03, alto: 0.15);

/// Con menos letras sueltas el porcentaje no es confiable (una sola letra
/// mal clasificada pesaría demasiado).
const minLetrasParaInversiones = 15;

RiesgoResultado evaluar(Uint8List bytes, {Uint8List? modelo}) {
  final imagen = img.decodeImage(bytes);
  if (imagen == null) {
    throw const EscrituraInsuficienteException('No se pudo leer la imagen capturada.');
  }
  final analisis = AnalizadorEscritura.analizar(imagen);

  ResultadoLetras? letras;
  if (modelo != null) {
    ClasificadorLetras? clasificador;
    try {
      clasificador = ClasificadorLetras.desdeBytes(modelo);
      letras = clasificador.clasificar(analisis.letras);
    } catch (_) {
      letras = null; // sin modelo usable: se evalúa solo la forma
    } finally {
      clasificador?.cerrar();
    }
  }
  return interpretar(analisis.medidas, letras: letras);
}

/// [letras] es opcional: sin modelo, o con menos de [minLetrasParaInversiones]
/// letras sueltas, se evalúa solo la forma (disgrafía) con los pesos originales.
RiesgoResultado interpretar(MedidasEscritura m, {ResultadoLetras? letras}) {
  double escalar(double valor, ({double normal, double alto}) r) =>
      ((valor - r.normal) / (r.alto - r.normal)).clamp(0.0, 1.0);

  final tamano = escalar(m.tamano, _tamano);
  final espaciado = escalar(m.espaciado, _espaciado);
  final lineaBase = escalar(m.lineaBase, _lineaBase);

  final conInversiones = (letras?.letras ?? 0) >= minLetrasParaInversiones;
  final inversiones = conInversiones ? escalar(letras?.proporcion ?? 0, _inversiones) : 0.0;

  final puntaje = (conInversiones
          ? 0.3 * inversiones + 0.3 * tamano + 0.2 * espaciado + 0.2 * lineaBase
          : 0.4 * tamano + 0.3 * espaciado + 0.3 * lineaBase)
      .clamp(0.0, 1.0);
  final nivel = puntaje < 0.35
      ? NivelRiesgo.bajo
      : puntaje < 0.65
          ? NivelRiesgo.medio
          : NivelRiesgo.alto;

  final senales = <String>[
    if (inversiones >= 0.6)
      'Se observan varias letras escritas en espejo (por ejemplo e, s, z, j o r al revés).'
    else if (inversiones >= 0.3)
      'Algunas letras podrían estar escritas en espejo.',
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
    senales.add(conInversiones
        ? 'El tamaño, el espaciado, la alineación y la orientación de las letras se ven regulares.'
        : 'El tamaño, el espaciado y la alineación de la escritura se ven regulares.');
  }
  if (letras != null && !conInversiones) {
    senales.add('No se revisaron letras en espejo: se encontraron pocas letras sueltas '
        '(funciona mejor con letra de imprenta que con cursiva).');
  }
  if (m.renglones < 3) {
    senales.add('Se analizaron solo ${m.renglones} renglones: con una muestra más larga el resultado es más confiable.');
  }

  return RiesgoResultado(nivel: nivel, puntaje: puntaje, senales: senales);
}
