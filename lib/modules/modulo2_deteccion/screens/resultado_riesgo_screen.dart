import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/reporte.dart';
import '../../../shared/widgets/raiz_widgets.dart';
import '../../modulo3_dashboard/db/app_database.dart';
import '../../modulo3_dashboard/models/registro_estudiante.dart';
import '../models/riesgo_resultado.dart';

/// Resultado del Módulo 2: medidor animado, señales detectadas, qué hacer
/// ahora y el aviso ético obligatorio. Desde aquí se guarda en el historial.
class ResultadoRiesgoScreen extends StatefulWidget {
  final RiesgoResultado resultado;
  final String nombreEstudiante;
  final String? grado;
  final File? foto;

  const ResultadoRiesgoScreen({
    super.key,
    required this.resultado,
    this.nombreEstudiante = 'Estudiante',
    this.grado,
    this.foto,
  });

  @override
  State<ResultadoRiesgoScreen> createState() => _ResultadoRiesgoScreenState();
}

class _ResultadoRiesgoScreenState extends State<ResultadoRiesgoScreen> {
  bool _guardado = false;
  bool _guardando = false;

  Future<void> _guardar() async {
    setState(() => _guardando = true);
    try {
      final r = widget.resultado;
      await AppDatabase.guardar(
        RegistroEstudiante(
          nombreEstudiante: widget.nombreEstudiante,
          grado: widget.grado,
          nivel: r.nivel,
          puntaje: r.puntaje,
          fecha: r.fecha,
          senales: r.senales,
          observaciones: r.observaciones,
        ),
        vista: r.vista,
      );
      if (!mounted) return;
      setState(() => _guardado = true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Guardado en el historial de ${widget.nombreEstudiante}')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('No se pudo guardar: $e')));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _compartir() async {
    final r = widget.resultado;
    if (!await confirmarCompartir(context)) return;
    await compartirReporte(
      nombre: widget.nombreEstudiante,
      vista: r.vista,
      texto: textoReporte(
        nombre: widget.nombreEstudiante,
        grado: widget.grado,
        fecha: r.fecha,
        nivel: r.nivel,
        puntaje: r.puntaje,
        senales: r.senales,
        observaciones: r.observaciones,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final nivel = r.nivel;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Resultado'),
        actions: [
          IconButton(
            tooltip: 'Compartir reporte',
            icon: const Icon(Icons.share_rounded),
            onPressed: _compartir,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          // Tarjeta principal
          RaizCard(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
            child: Column(
              children: [
                Text(widget.nombreEstudiante, style: t.titleLarge, textAlign: TextAlign.center),
                if (widget.grado != null) ...[
                  const SizedBox(height: 2),
                  Text(widget.grado!, style: t.bodyMedium),
                ],
                const SizedBox(height: 18),
                MedidorRiesgo(valor: r.puntaje, color: nivel.color),
                const SizedBox(height: 14),
                InsigniaRiesgo(nivel: nivel),
                const SizedBox(height: 10),
                Text(nivel.resumen, style: t.bodyLarge, textAlign: TextAlign.center),
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (r.vista != null) ...[
            const TituloSeccion('Lo que analizó Raíz'),
            _VistaAnalisis(bytes: r.vista!),
            const SizedBox(height: 22),
          ],

          const TituloSeccion('Señales detectadas'),
          RaizCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              children: [
                for (var i = 0; i < r.senales.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: AppTheme.borde),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.fiber_manual_record, size: 10, color: nivel.color),
                        const SizedBox(width: 10),
                        Expanded(child: Text(r.senales[i], style: t.bodyLarge)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),

          if (r.observaciones.isNotEmpty) ...[
            const TituloSeccion('Observaciones'),
            RaizCard(
              color: AppTheme.borde.withValues(alpha: 0.35),
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final o in r.observaciones)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.info_outline_rounded, size: 18, color: AppTheme.tintaSuave),
                          const SizedBox(width: 10),
                          Expanded(child: Text(o, style: t.bodyLarge)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 4),
                  Text('Se ven en la escritura, pero no cambian el índice de riesgo.', style: t.bodySmall),
                ],
              ),
            ),
            const SizedBox(height: 22),
          ],

          const TituloSeccion('¿Qué hacer ahora?'),
          RaizCard(
            child: Column(
              children: [
                for (final (i, rec) in nivel.recomendaciones.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 12,
                          backgroundColor: AppTheme.bosque.withValues(alpha: 0.12),
                          child: Text('${i + 1}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.bosque)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(rec, style: t.bodyLarge)),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const AvisoEtico(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                child: const Text('Inicio'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton.icon(
                onPressed: (_guardado || _guardando) ? null : _guardar,
                icon: Icon(_guardado ? Icons.check_rounded : Icons.bookmark_add_rounded),
                label: Text(_guardado ? 'Guardado' : 'Guardar en historial'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// La foto con la línea de cada renglón y las letras marcadas, para que el
/// docente vea en qué se basó la alerta. Se toca para ampliarla.
class _VistaAnalisis extends StatelessWidget {
  final Uint8List bytes;
  const _VistaAnalisis({required this.bytes});

  void _ampliar(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(maxScale: 6, child: Center(child: Image.memory(bytes))),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: SafeArea(
                child: IconButton.filled(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return RaizCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => _ampliar(context),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.memory(bytes, width: double.infinity, fit: BoxFit.fitWidth),
                  Positioned(
                    right: 8,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                      child: const Icon(Icons.zoom_in_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          const _Leyenda(color: Color(0xFF1E6EDC), texto: 'Línea del renglón que detectó Raíz', linea: true),
          const _Leyenda(color: Color(0xFF28A05A), texto: 'Letra que sigue el renglón'),
          const _Leyenda(color: Color(0xFFDC2828), texto: 'Letra que flota o se hunde'),
          const SizedBox(height: 6),
          Text('Toca la imagen para ampliarla.', style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _Leyenda extends StatelessWidget {
  final Color color;
  final String texto;
  final bool linea;
  const _Leyenda({required this.color, required this.texto, this.linea = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Container(
            width: 18,
            height: linea ? 3 : 14,
            decoration: BoxDecoration(
              color: linea ? color : null,
              border: linea ? null : Border.all(color: color, width: 2),
              borderRadius: BorderRadius.circular(linea ? 2 : 3),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(texto, style: Theme.of(context).textTheme.bodyMedium)),
        ],
      ),
    );
  }
}
