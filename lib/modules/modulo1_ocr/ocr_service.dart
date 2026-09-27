import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../modulo2_deteccion/analizador_escritura.dart';
import 'diccionario.dart';
import 'texto_revisado.dart';

/// Módulo 1: digitaliza el texto de una foto, 100% offline.
///
/// ML Kit está entrenado con texto impreso y lee mal la letra a mano
/// infantil. Por eso el resultado no se entrega crudo:
/// 1. **Dos lecturas**: la foto original y una versión limpia (sin renglones
///    del cuaderno, margen, colores ni sombras). Se queda la que reconoce más
///    palabras reales.
/// 2. **Revisión con diccionario**: arregla solo los errores imposibles del
///    OCR (dígitos dentro de palabras) y marca las palabras dudosas con
///    sugerencias, para que el docente decida con un toque.
///
/// Nunca corrige sola la ortografía del estudiante: en una app de detección
/// de dislexia, esos errores son justamente información.
class OcrService {
  static const rutaDiccionario = 'assets/diccionario/es_frecuencias.txt';
  static Diccionario? _diccionario;

  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  Future<TextoRevisado> digitalizar(File foto) async {
    final dic = await _cargarDiccionario();
    final lecturaOriginal = await _leer(foto);

    String? lecturaLimpia;
    try {
      final bytes = await foto.readAsBytes();
      final png = await Isolate.run(() => limpiarParaOcr(bytes));
      if (png != null) {
        final dir = await getTemporaryDirectory();
        final archivo = File(p.join(dir.path, 'raiz_ocr_limpia.png'));
        await archivo.writeAsBytes(png, flush: true);
        lecturaLimpia = await _leer(archivo);
      }
    } catch (_) {
      lecturaLimpia = null; // si falla la limpieza, queda la lectura original
    }

    final limpia = lecturaLimpia;
    return Isolate.run(() {
      final opciones = [
        revisarTexto(lecturaOriginal, dic),
        if (limpia != null) revisarTexto(limpia, dic, fuente: 'mejorada'),
      ];
      return mejorLectura(opciones);
    });
  }

  /// Vuelve a revisar un texto que el docente editó a mano.
  Future<TextoRevisado> revisar(String texto) async {
    final dic = await _cargarDiccionario();
    return Isolate.run(() => revisarTexto(texto, dic));
  }

  /// Compatibilidad: solo el texto de la mejor lectura.
  Future<String> reconocerOffline(File imagen) async => (await digitalizar(imagen)).texto;

  Future<String> _leer(File imagen) async =>
      _enOrdenDeLectura(await _recognizer.processImage(InputImage.fromFile(imagen)));

  static Future<Diccionario> _cargarDiccionario() async {
    final ya = _diccionario;
    if (ya != null) return ya;
    final texto = await rootBundle.loadString(rutaDiccionario);
    return _diccionario = await Isolate.run(() => Diccionario.desdeTexto(texto));
  }

  /// ML Kit entrega bloques en su propio orden; en una hoja manuscrita eso
  /// desordena el texto. Se reordena por renglón (arriba→abajo) y dentro de
  /// cada renglón de izquierda a derecha.
  String _enOrdenDeLectura(RecognizedText resultado) {
    final lineas = [for (final b in resultado.blocks) ...b.lines]
      ..sort((a, b) => a.boundingBox.center.dy.compareTo(b.boundingBox.center.dy));

    final renglones = <List<TextLine>>[];
    for (final l in lineas) {
      final actual = renglones.isEmpty ? null : renglones.last;
      final ref = actual?.first.boundingBox;
      if (ref != null && l.boundingBox.center.dy <= ref.bottom && l.boundingBox.center.dy >= ref.top) {
        actual!.add(l);
      } else {
        renglones.add([l]);
      }
    }

    return renglones.map((r) {
      r.sort((a, b) => a.boundingBox.left.compareTo(b.boundingBox.left));
      return r.map((l) => l.text).join(' ');
    }).join('\n');
  }

  void dispose() => _recognizer.close();
}

/// Versión limpia de la foto para la segunda lectura (PNG), o null si no se
/// pudo decodificar.
Uint8List? limpiarParaOcr(Uint8List bytes) {
  final imagen = img.decodeImage(bytes);
  if (imagen == null) return null;
  return img.encodePng(AnalizadorEscritura.imagenLimpia(imagen));
}

/// La lectura que reconoce más letras de palabras reales; a igualdad, la de
/// mejor calidad. Una lectura vacía nunca gana.
TextoRevisado mejorLectura(List<TextoRevisado> opciones) {
  return opciones.reduce((a, b) {
    if (b.letrasReconocidas != a.letrasReconocidas) {
      return b.letrasReconocidas > a.letrasReconocidas ? b : a;
    }
    return b.calidad > a.calidad ? b : a;
  });
}
