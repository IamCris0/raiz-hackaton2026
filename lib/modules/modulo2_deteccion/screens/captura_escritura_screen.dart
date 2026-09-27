import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/raiz_widgets.dart';
import '../deteccion_service.dart';
import 'resultado_riesgo_screen.dart';

/// Módulo 2 — paso a paso: (1) quién es el estudiante, (2) foto de su
/// escritura, (3) analizar. El botón de analizar solo se activa cuando los
/// dos primeros pasos están completos.
class CapturaEscrituraScreen extends StatefulWidget {
  const CapturaEscrituraScreen({super.key});

  @override
  State<CapturaEscrituraScreen> createState() => _CapturaEscrituraScreenState();
}

class _CapturaEscrituraScreenState extends State<CapturaEscrituraScreen> {
  final _picker = ImagePicker();
  final _servicio = DeteccionService();
  final _nombre = TextEditingController();
  String? _grado;
  File? _foto;
  bool _procesando = false;

  bool get _listo => _nombre.text.trim().isNotEmpty && _foto != null && !_procesando;

  @override
  void initState() {
    super.initState();
    _nombre.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  Future<void> _elegirFoto(ImageSource fuente) async {
    final foto = await _picker.pickImage(source: fuente, maxWidth: 2000, imageQuality: 90);
    if (foto == null) return;
    setState(() => _foto = File(foto.path));
  }

  Future<void> _analizar() async {
    FocusScope.of(context).unfocus();
    setState(() => _procesando = true);
    try {
      // Pequeña pausa para que la animación de análisis sea visible en la demo.
      final futuro = _servicio.analizarFoto(_foto!);
      await Future.delayed(const Duration(milliseconds: 1600));
      final resultado = await futuro;
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultadoRiesgoScreen(
            resultado: resultado,
            nombreEstudiante: _nombre.text.trim(),
            grado: _grado,
            foto: _foto,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo analizar la imagen: $e')),
      );
    } finally {
      if (mounted) setState(() => _procesando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(title: const Text('Nueva evaluación')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
            children: [
              _Paso(
                numero: 1,
                titulo: '¿A quién vas a evaluar?',
                completo: _nombre.text.trim().isNotEmpty,
                child: Column(
                  children: [
                    TextField(
                      controller: _nombre,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Nombre del estudiante',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _grado,
                      decoration: const InputDecoration(
                        labelText: 'Grado (opcional)',
                        prefixIcon: Icon(Icons.school_outlined),
                      ),
                      items: AppConstants.grados
                          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                          .toList(),
                      onChanged: (g) => setState(() => _grado = g),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _Paso(
                numero: 2,
                titulo: 'Foto de su escritura',
                completo: _foto != null,
                child: _foto == null ? _SelectorFoto(onElegir: _elegirFoto) : _VistaFoto(foto: _foto!, onCambiar: _elegirFoto),
              ),
              const SizedBox(height: 16),
              const _Consejos(),
            ],
          ),
          bottomNavigationBar: SafeArea(
            minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: ElevatedButton.icon(
              onPressed: _listo ? _analizar : null,
              icon: const Icon(Icons.auto_awesome_rounded),
              label: const Text('Analizar escritura'),
            ),
          ),
        ),
        if (_procesando) const _CapaAnalizando(),
      ],
    );
  }
}

class _Paso extends StatelessWidget {
  final int numero;
  final String titulo;
  final bool completo;
  final Widget child;

  const _Paso({required this.numero, required this.titulo, required this.completo, required this.child});

  @override
  Widget build(BuildContext context) {
    return RaizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: completo ? AppTheme.bosque : AppTheme.borde,
                  shape: BoxShape.circle,
                ),
                child: completo
                    ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                    : Text('$numero', style: const TextStyle(fontWeight: FontWeight.w800, color: AppTheme.tintaSuave)),
              ),
              const SizedBox(width: 10),
              Text(titulo, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _SelectorFoto extends StatelessWidget {
  final void Function(ImageSource) onElegir;
  const _SelectorFoto({required this.onElegir});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        InkWell(
          onTap: () => onElegir(ImageSource.camera),
          borderRadius: BorderRadius.circular(18),
          child: Container(
            height: 150,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppTheme.bosque.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppTheme.bosque.withValues(alpha: 0.35), width: 1.5),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.photo_camera_rounded, size: 40, color: AppTheme.bosque),
                SizedBox(height: 8),
                Text('Tomar foto', style: TextStyle(fontWeight: FontWeight.w800, color: AppTheme.bosque, fontSize: 16)),
                SizedBox(height: 2),
                Text('Una hoja escrita a mano, con buena luz', style: TextStyle(fontSize: 12.5, color: AppTheme.tintaSuave)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        TextButton.icon(
          onPressed: () => onElegir(ImageSource.gallery),
          icon: const Icon(Icons.photo_library_outlined),
          label: const Text('Elegir de la galería'),
        ),
      ],
    );
  }
}

class _VistaFoto extends StatelessWidget {
  final File foto;
  final void Function(ImageSource) onCambiar;
  const _VistaFoto({required this.foto, required this.onCambiar});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Image.file(foto, height: 220, width: double.infinity, fit: BoxFit.cover),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextButton.icon(
                onPressed: () => onCambiar(ImageSource.camera),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Repetir foto'),
              ),
            ),
            Expanded(
              child: TextButton.icon(
                onPressed: () => onCambiar(ImageSource.gallery),
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('Galería'),
              ),
            ),
          ],
        ),
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
      (Icons.crop_free_rounded, 'La hoja completa dentro de la foto'),
      (Icons.edit_note_rounded, 'Mejor un dictado o copia de 3–5 líneas'),
      (Icons.straighten_rounded, 'Celular paralelo a la hoja, sin inclinar'),
    ];
    return RaizCard(
      color: AppTheme.bosque.withValues(alpha: 0.05),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Para una mejor foto', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          for (final (icono, texto) in consejos)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(icono, size: 18, color: AppTheme.bosque),
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

class _CapaAnalizando extends StatefulWidget {
  const _CapaAnalizando();

  @override
  State<_CapaAnalizando> createState() => _CapaAnalizandoState();
}

class _CapaAnalizandoState extends State<_CapaAnalizando> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.bosqueOscuro.withValues(alpha: 0.92),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ScaleTransition(
              scale: Tween(begin: 0.85, end: 1.1).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
              child: Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.spa_rounded, size: 56, color: Colors.white),
              ),
            ),
            const SizedBox(height: 26),
            const Text('Analizando trazos…',
                style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text('Tamaño de letra · espaciado · alineación',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 13.5)),
            const SizedBox(height: 24),
            const SizedBox(
              width: 160,
              child: LinearProgressIndicator(
                color: AppTheme.ambar,
                backgroundColor: Colors.white24,
                minHeight: 5,
                borderRadius: BorderRadius.all(Radius.circular(4)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
