import 'dart:io';

import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
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
      await AppDatabase.guardar(RegistroEstudiante(
        nombreEstudiante: widget.nombreEstudiante,
        grado: widget.grado,
        nivel: widget.resultado.nivel,
        puntaje: widget.resultado.puntaje,
        fecha: widget.resultado.fecha,
      ));
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

  @override
  Widget build(BuildContext context) {
    final r = widget.resultado;
    final nivel = r.nivel;
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
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
