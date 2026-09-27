import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/raiz_widgets.dart';
import '../ocr_service.dart';
import '../texto_revisado.dart';

/// Módulo 1: foto → texto. El OCR se equivoca con la letra a mano, así que
/// el resultado llega **revisado**: las palabras dudosas aparecen marcadas y
/// se corrigen con un toque. El docente decide siempre: una palabra "mal
/// escrita" puede ser un error del OCR… o del estudiante.
class OcrCaptureScreen extends StatefulWidget {
  const OcrCaptureScreen({super.key});

  @override
  State<OcrCaptureScreen> createState() => _OcrCaptureScreenState();
}

enum _Modo { revisar, editar }

class _OcrCaptureScreenState extends State<OcrCaptureScreen> {
  static const _azul = Color(0xFF3A7BD5);

  final _picker = ImagePicker();
  final _ocr = OcrService();
  final _editor = TextEditingController();
  File? _foto;
  TextoRevisado? _resultado;
  _Modo _modo = _Modo.revisar;
  bool _procesando = false;

  Future<void> _capturar(ImageSource fuente) async {
    final foto = await _picker.pickImage(source: fuente, maxWidth: 2400);
    if (foto == null) return;

    setState(() {
      _foto = File(foto.path);
      _resultado = null;
      _modo = _Modo.revisar;
      _procesando = true;
    });
    try {
      final r = await _ocr.digitalizar(_foto!);
      if (!mounted) return;
      setState(() => _resultado = r);
      if (r.palabras.isEmpty) {
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

  String get _textoActual => _modo == _Modo.editar ? _editor.text : (_resultado?.texto ?? '');

  void _copiar() {
    Clipboard.setData(ClipboardData(text: _textoActual));
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Texto copiado')));
  }

  Future<void> _cambiarModo(_Modo modo) async {
    if (modo == _modo) return;
    if (modo == _Modo.editar) {
      _editor.text = _resultado?.texto ?? '';
      setState(() => _modo = modo);
      return;
    }
    // De vuelta a "Revisar": se revisa de nuevo lo que el docente escribió.
    setState(() => _procesando = true);
    final r = await _ocr.revisar(_editor.text);
    if (!mounted) return;
    setState(() {
      _resultado = r;
      _modo = modo;
      _procesando = false;
    });
  }

  Future<void> _revisarPalabra(Palabra p) async {
    final elegido = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _HojaPalabra(palabra: p),
    );
    if (elegido == null) return;
    setState(() => p.resolver(elegido));
  }

  Future<void> _siguienteDudosa() async {
    final p = _resultado?.palabras.where((p) => p.porRevisar).firstOrNull;
    if (p != null) await _revisarPalabra(p);
  }

  @override
  void dispose() {
    _ocr.dispose();
    _editor.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado;
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
                      Text('Sin internet · lee la foto dos veces y marca las palabras dudosas',
                          style: Theme.of(context).textTheme.bodySmall),
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
                            Text('Leyendo y revisando…',
                                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
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
          if (_foto == null) ...[
            const SizedBox(height: 16),
            const _Consejos(),
          ],
          if (r != null && r.palabras.isNotEmpty) ...[
            const SizedBox(height: 22),
            _Resumen(resultado: r, onSiguiente: r.porRevisar > 0 ? _siguienteDudosa : null),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SegmentedButton<_Modo>(
                    segments: const [
                      ButtonSegment(value: _Modo.revisar, icon: Icon(Icons.spellcheck_rounded), label: Text('Revisar')),
                      ButtonSegment(value: _Modo.editar, icon: Icon(Icons.edit_note_rounded), label: Text('Editar')),
                    ],
                    selected: {_modo},
                    onSelectionChanged: _procesando ? null : (s) => _cambiarModo(s.first),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: 'Copiar texto',
                  onPressed: _copiar,
                  icon: const Icon(Icons.copy_rounded),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (_modo == _Modo.revisar)
              RaizCard(child: _TextoMarcado(resultado: r, onTocar: _revisarPalabra))
            else
              TextField(
                controller: _editor,
                minLines: 8,
                maxLines: null,
                decoration: const InputDecoration(
                  hintText: 'Corrige el texto libremente. Al volver a "Revisar" se marca de nuevo.',
                ),
              ),
            const SizedBox(height: 10),
            const _Leyenda(),
          ],
        ],
      ),
    );
  }
}

/// Calidad de la lectura + cuántas palabras faltan por revisar.
class _Resumen extends StatelessWidget {
  final TextoRevisado resultado;
  final VoidCallback? onSiguiente;

  const _Resumen({required this.resultado, this.onSiguiente});

  @override
  Widget build(BuildContext context) {
    final c = resultado.calidad;
    final (etiqueta, color) = c >= 0.85
        ? ('Lectura buena', AppTheme.riesgoBajo)
        : c >= 0.6
            ? ('Lectura regular', AppTheme.riesgoMedio)
            : ('Lectura difícil', AppTheme.riesgoAlto);
    final faltan = resultado.porRevisar;
    final t = Theme.of(context).textTheme;

    return RaizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconoBurbuja(icono: Icons.fact_check_rounded, color: color, tamano: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$etiqueta · ${(c * 100).round()}% reconocido', style: t.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      faltan == 0
                          ? 'No quedan palabras por revisar.'
                          : '$faltan ${faltan == 1 ? 'palabra' : 'palabras'} por revisar'
                              '${resultado.corregidasAuto > 0 ? ' · ${resultado.corregidasAuto} arregladas solas' : ''}',
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (resultado.fuente == 'mejorada') ...[
            const SizedBox(height: 10),
            Text('Se leyó mejor la versión limpia de la foto (sin renglones ni sombras).', style: t.bodySmall),
          ],
          if (c < 0.6) ...[
            const SizedBox(height: 10),
            Text(
              'La letra a mano es difícil para el lector automático. Para una mejor lectura: '
              'más luz, la hoja recta y de cerca, o letra de imprenta.',
              style: t.bodySmall?.copyWith(color: const Color(0xFF7A4F12)),
            ),
          ],
          if (onSiguiente != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onSiguiente,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Revisar la siguiente palabra marcada'),
            ),
          ],
        ],
      ),
    );
  }
}

/// El texto con cada palabra dudosa resaltada y tocable.
class _TextoMarcado extends StatelessWidget {
  final TextoRevisado resultado;
  final void Function(Palabra) onTocar;

  const _TextoMarcado({required this.resultado, required this.onTocar});

  @override
  Widget build(BuildContext context) {
    const base = TextStyle(fontSize: 17, height: 1.6, color: AppTheme.tinta);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final renglon in resultado.renglones)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [for (final p in renglon) _palabra(p, base)],
            ),
          ),
      ],
    );
  }

  Widget _palabra(Palabra p, TextStyle base) {
    switch (p.estado) {
      case EstadoPalabra.correcta:
        return Text(p.completa, style: base);
      case EstadoPalabra.corregidaAuto:
      case EstadoPalabra.revisada:
        final auto = p.estado == EstadoPalabra.corregidaAuto;
        return GestureDetector(
          onTap: () => onTocar(p),
          child: Text(
            p.completa,
            style: base.copyWith(
              decoration: TextDecoration.underline,
              decorationStyle: TextDecorationStyle.dotted,
              decorationColor: auto ? AppTheme.riesgoBajo : AppTheme.bosque,
              decorationThickness: 2,
            ),
          ),
        );
      case EstadoPalabra.dudosa:
        return InkWell(
          onTap: () => onTocar(p),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.ambar.withValues(alpha: 0.22),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.ambar),
            ),
            child: Text(p.completa, style: base.copyWith(fontWeight: FontWeight.w700)),
          ),
        );
    }
  }
}

/// Hoja inferior para decidir una palabra: sugerencias, dejarla o escribir otra.
class _HojaPalabra extends StatefulWidget {
  final Palabra palabra;
  const _HojaPalabra({required this.palabra});

  @override
  State<_HojaPalabra> createState() => _HojaPalabraState();
}

class _HojaPalabraState extends State<_HojaPalabra> {
  late final _otra = TextEditingController(text: widget.palabra.texto);

  @override
  void dispose() {
    _otra.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.palabra;
    final t = Theme.of(context).textTheme;
    final opciones = [...p.sugerencias];
    if (p.estado == EstadoPalabra.corregidaAuto && !opciones.contains(p.texto)) opciones.insert(0, p.texto);

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('El lector leyó: «${p.leida}»', style: t.titleLarge),
          const SizedBox(height: 6),
          Text(
            p.estado == EstadoPalabra.corregidaAuto
                ? 'Tenía números o símbolos en medio de la palabra, así que se cambió sola por «${p.texto}».'
                : 'Puede ser un error del lector… o así la escribió el estudiante. '
                    'Si es un error de ortografía del estudiante, déjala como está: es información útil.',
            style: t.bodyMedium,
          ),
          if (opciones.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text('¿Quisiste decir?', style: t.titleMedium),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in opciones)
                  FilledButton.tonal(
                    onPressed: () => Navigator.pop(context, s),
                    child: Text(s, style: const TextStyle(fontSize: 16)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.pop(context, p.leida),
            icon: const Icon(Icons.history_edu_rounded),
            label: Text('Dejar como lo escribió: «${p.leida}»'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _otra,
                  decoration: const InputDecoration(labelText: 'Escribir otra', isDense: true),
                  onSubmitted: (v) => Navigator.pop(context, v.trim().isEmpty ? p.texto : v.trim()),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: () => Navigator.pop(context, _otra.text.trim().isEmpty ? p.texto : _otra.text.trim()),
                icon: const Icon(Icons.check_rounded),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  const _Leyenda();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme.bodySmall;
    Widget muestra(Color fondo, Color borde) => Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(color: fondo, border: Border.all(color: borde), borderRadius: BorderRadius.circular(4)),
        );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        Row(mainAxisSize: MainAxisSize.min, children: [
          muestra(AppTheme.ambar.withValues(alpha: 0.22), AppTheme.ambar),
          const SizedBox(width: 6),
          Text('Tocar para revisar', style: t),
        ]),
        Row(mainAxisSize: MainAxisSize.min, children: [
          muestra(Colors.transparent, AppTheme.riesgoBajo),
          const SizedBox(width: 6),
          Text('Arreglada sola / revisada', style: t),
        ]),
      ],
    );
  }
}

class _Consejos extends StatelessWidget {
  const _Consejos();

  @override
  Widget build(BuildContext context) {
    const consejos = [
      (Icons.wb_sunny_outlined, 'Buena luz, sin sombras sobre la hoja'),
      (Icons.straighten_rounded, 'Celular paralelo a la hoja y de cerca'),
      (Icons.text_fields_rounded, 'La letra de imprenta se lee mucho mejor que la cursiva'),
    ];
    return RaizCard(
      color: _OcrCaptureScreenState._azul.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Para una mejor lectura', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final (icono, texto) in consejos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(icono, size: 18, color: _OcrCaptureScreenState._azul),
                  const SizedBox(width: 10),
                  Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
