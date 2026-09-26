import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/connectivity_service.dart';
import '../ocr_service.dart';

/// Pantalla del Módulo 1: toma/selecciona una foto, la pasa por OCR y deja
/// que el docente corrija el texto reconocido antes de guardarlo.
class OcrCaptureScreen extends StatefulWidget {
  const OcrCaptureScreen({super.key});

  @override
  State<OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends State<OcrCaptureScreen> {
  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _controller = TextEditingController();
  bool _procesando = false;

  Future<void> _capturarYReconocer() async {
    final foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto == null) return;

    setState(() => _procesando = true);
    try {
      // Por ahora siempre offline; cuando exista reconocerOnline(), alternar
      // según context.read<ConnectivityService>().online.
      final texto = await _ocr.reconocerOffline(File(foto.path));
      _controller.text = texto;
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  void dispose() {
    _ocr.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final online = context.watch<ConnectivityService>().online;

    return Scaffold(
      appBar: AppBar(title: const Text('Digitalizar texto (OCR)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Chip(
                avatar: Icon(online ? Icons.cloud_done : Icons.cloud_off, size: 18),
                label: Text(online ? 'Modo online' : 'Modo offline'),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: _procesando ? null : _capturarYReconocer,
              icon: const Icon(Icons.camera_alt),
              label: const Text('Tomar foto del texto'),
            ),
            const SizedBox(height: 16),
            if (_procesando) const LinearProgressIndicator(),
            Expanded(
              child: TextField(
                controller: _controller,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  labelText: 'Texto reconocido (editable por el docente)',
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
