import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../deteccion_service.dart';
import 'resultado_riesgo_screen.dart';

/// Pantalla donde el docente toma o selecciona la foto de la muestra de
/// escritura del estudiante. Es la puerta de entrada al Módulo 2.
class CapturaEscrituraScreen extends StatefulWidget {
  const CapturaEscrituraScreen({super.key});

  @override
  State<CapturaEscrituraScreen> createState() => _CapturaEscrituraScreenState();
}

class _CapturaEscrituraScreenState extends State<CapturaEscrituraScreen> {
  final _picker = ImagePicker();
  final _servicio = DeteccionService();
  bool _procesando = false;

  Future<void> _tomarFoto() async {
    final foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() => _procesando = true);
    try {
      final resultado = await _servicio.analizarFoto(File(foto.path));
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ResultadoRiesgoScreen(resultado: resultado)),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Capturar muestra de escritura')),
      body: Center(
        child: _procesando
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.edit_document, size: 72),
                    const SizedBox(height: 16),
                    const Text(
                      'Toma una foto clara de un texto escrito a mano por el '
                      'estudiante (ideal: una hoja completa, buena luz).',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _tomarFoto,
                      icon: const Icon(Icons.camera_alt),
                      label: const Text('Tomar foto'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
