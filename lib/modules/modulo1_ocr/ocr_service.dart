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
  Future<String> reconocerOffline(File imagen) async {
    final input = InputImage.fromFile(imagen);
    final resultado = await _recognizer.processImage(input);
    return resultado.text;
  }

  /// TODO(equipo): implementar el modo online con Vision API cuando haya
  /// señal, usando la key guardada en un .env que NO se sube al repo
  /// (ver .gitignore — *.secrets.dart). Debe ser un método con la misma
  /// firma para poder alternar entre ambos sin tocar la UI:
  ///
  /// `Future<String> reconocerOnline(File imagen) async { ... }`

  void dispose() => _recognizer.close();
}
