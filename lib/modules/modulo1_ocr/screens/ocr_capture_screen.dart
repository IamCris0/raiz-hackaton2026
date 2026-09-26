import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/services/connectivity_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/raiz_widgets.dart';
import '../ocr_service.dart';

/// Módulo 1: foto → texto editable. El docente puede corregir lo reconocido
/// y copiarlo para usarlo en sus registros.
class OcrCaptureScreen extends StatefulWidget {
  const OcrCaptureScreen({super.key});

  @override
  State<OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

class _OcrCaptureScreenState extends State<OcrCaptureScreen> {
  static const _azul = Color(0xFF3A7BD5);

  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _controller = TextEditingController();
  File? _foto;
  bool _procesando = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  Future<void> _capturar(ImageSource fuente) async {
    final foto = await _picker.pickImage(source: fuente, maxWidth: 2000);
    if (foto == null) return;

    setState(() {
      _foto = File(foto.path);
      _procesando = true;
    });
    try {
      final texto = await _ocr.reconocerOffline(_foto!);
      _controller.text = texto.trim().isEmpty ? '' : texto;
      if (texto.trim().isEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se encontró texto. Prueba con más luz o más cerca.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error en el OCR: $e')));
      }
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  void _copiar() {
    Clipboard.setData(ClipboardData(text: _controller.text));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto copiado')));
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
    final texto = _controller.text.trim();
    final palabras = texto.isEmpty ? 0 : texto.split(RegExp(r'\s+')).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Digitalizar texto')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          RaizCard(
            color: _azul.withValues(alpha: 0.06),
            child: Row(
              children: [
                const IconoBurbuja(icono: Icons.document_scanner_rounded, color: _azul),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Reconocimiento de texto', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 2),
                      Text(
                        online
                            ? 'En línea · se procesa en el celular'
                            : 'Sin internet · se procesa en el celular',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_foto != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  Image.file(_foto!, height: 190, width: double.infinity, fit: BoxFit.cover),
                  if (_procesando)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black45,
                        alignment: Alignment.center,
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(color: Colors.white),
                            SizedBox(height: 10),
                            Text('Leyendo texto…', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: _azul),
                  onPressed: _procesando ? null : () => _capturar(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_rounded),
                  label: Text(_foto == null ? 'Tomar foto' : 'Otra foto'),
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 60,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _azul,
                    side: const BorderSide(color: _azul, width: 1.5),
                    padding: EdgeInsets.zero,
                  ),
                  onPressed: _procesando ? null : () => _capturar(ImageSource.gallery),
                  child: const Icon(Icons.photo_library_outlined),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          TituloSeccion(
            'Texto reconocido',
            accion: texto.isEmpty
                ? null
                : TextButton.icon(onPressed: _copiar, icon: const Icon(Icons.copy_rounded, size: 18), label: const Text('Copiar')),
          ),
          TextField(
            controller: _controller,
            minLines: 8,
            maxLines: null,
            decoration: const InputDecoration(
              hintText: 'Aquí aparecerá el texto. Puedes corregirlo antes de copiarlo.',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text('$palabras palabras · ${texto.length} caracteres',
                style: const TextStyle(fontSize: 12, color: AppTheme.tintaSuave)),
          ),
        ],
      ),
    );
  }
}
