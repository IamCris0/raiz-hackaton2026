import 'dart:io';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Módulo 1 — digitaliza el texto de una foto.
///
/// Modo **offline** (siempre disponible): ML Kit on-device.
/// Modo **online** (opcional, mejor precisión): Google Vision API — se activa
/// solo cuando [ConnectivityService.online] es true. Ver TODO abajo.
class OcrService {
  final _recognizer = TextRecognizer(script: TextRecognitionScript.latin);

  /// OCR on-device, funciona sin internet. Es el modo por defecto.
  ///
  /// Límite conocido: ML Kit está entrenado con texto impreso y lee mal la
  /// letra a mano infantil, aun con la imagen limpia (se probó). El docente
  /// debe revisar y corregir el texto.
  Future<String> reconocerOffline(File imagen) async {
    final resultado = await _recognizer.processImage(InputImage.fromFile(imagen));
    return _enOrdenDeLectura(resultado);
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

  /// TODO(equipo): implementar el modo online con Vision API cuando haya
  /// señal, usando la key guardada en un .env que NO se sube al repo
  /// (ver .gitignore — *.secrets.dart). Debe ser un método con la misma
  /// firma para poder alternar entre ambos sin tocar la UI:
  ///
  /// `Future<String> reconocerOnline(File imagen) async { ... }`

  void dispose() => _recognizer.close();
}
