import 'dart:io';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/reporte.dart';
import '../../../shared/widgets/raiz_widgets.dart';
import '../db/app_database.dart';
import '../models/registro_estudiante.dart';

/// Evolución de un estudiante en el tiempo: el gráfico que le permite al
/// docente ver si las intervenciones están funcionando.
class EstudianteDetalleScreen extends StatefulWidget {
  final String nombre;
  const EstudianteDetalleScreen({super.key, required this.nombre});

  @override
  State<EstudianteDetalleScreen> createState() => _EstudianteDetalleScreenState();
}

class _EstudianteDetalleScreenState extends State<EstudianteDetalleScreen> {
  late Future<List<RegistroEstudiante>> _datos = AppDatabase.historialDe(widget.nombre);

  Future<void> _eliminar(RegistroEstudiante r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar evaluación'),
        content: Text('¿Eliminar la evaluación del ${DateFormat('dd/MM/yyyy').format(r.fecha)}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Eliminar')),
        ],
      ),
    );
    if (ok != true || r.id == null) return;
    await AppDatabase.eliminar(r.id!);
    if (mounted) setState(() => _datos = AppDatabase.historialDe(widget.nombre));
  }

  void _verEvaluacion(RegistroEstudiante r) {
    final t = Theme.of(context).textTheme;
    final vista = r.vistaRuta == null ? null : File(r.vistaRuta!);
    Widget lista(String titulo, List<String> items, IconData icono, Color color) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Text(titulo, style: t.titleMedium),
            for (final s in items)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icono, size: 16, color: color),
                    const SizedBox(width: 8),
                    Expanded(child: Text(s, style: t.bodyMedium)),
                  ],
                ),
              ),
          ],
        );

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.95,
        builder: (ctx, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          children: [
            Row(
              children: [
                InsigniaRiesgo(nivel: r.nivel),
                const SizedBox(width: 10),
                Text('índice ${(r.puntaje * 100).round()}', style: t.titleMedium),
                const Spacer(),
                Text(DateFormat('dd/MM/yyyy · HH:mm').format(r.fecha), style: t.bodySmall),
              ],
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.share_rounded, size: 18),
                label: const Text('Compartir reporte'),
                onPressed: () async {
                  if (!await confirmarCompartir(ctx)) return;
                  await compartirReporte(
                    nombre: r.nombreEstudiante,
                    vistaRuta: r.vistaRuta,
                    texto: textoReporte(
                      nombre: r.nombreEstudiante,
                      grado: r.grado,
                      fecha: r.fecha,
                      nivel: r.nivel,
                      puntaje: r.puntaje,
                      senales: r.senales,
                      observaciones: r.observaciones,
                    ),
                  );
                },
              ),
            ),
            if (vista != null && vista.existsSync()) ...[
              const SizedBox(height: 16),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: InteractiveViewer(maxScale: 5, child: Image.file(vista)),
              ),
              const SizedBox(height: 6),
              Text('Azul: renglón · Verde: sigue el renglón · Rojo: flota o se hunde. Pellizca para ampliar.',
                  style: t.bodySmall),
            ],
            if (r.senales.isNotEmpty) lista('Señales detectadas', r.senales, Icons.fiber_manual_record, r.nivel.color),
            if (r.observaciones.isNotEmpty)
              lista('Observaciones', r.observaciones, Icons.info_outline_rounded, AppTheme.tintaSuave),
            if (r.senales.isEmpty && vista == null) ...[
              const SizedBox(height: 16),
              Text('Esta evaluación se guardó con una versión anterior de Raíz y no tiene el detalle.',
                  style: t.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.nombre)),
      body: FutureBuilder<List<RegistroEstudiante>>(
        future: _datos,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final lista = snap.data!;
          if (lista.isEmpty) {
            return const Center(
              child: EstadoVacio(icono: Icons.person_off_outlined, titulo: 'Sin evaluaciones', mensaje: ''),
            );
          }
          final ultimo = lista.last;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
            children: [
              RaizCard(
                child: Row(
                  children: [
                    MedidorRiesgo(valor: ultimo.puntaje, color: ultimo.nivel.color, tamano: 96),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Última evaluación', style: Theme.of(context).textTheme.bodySmall),
                          const SizedBox(height: 4),
                          InsigniaRiesgo(nivel: ultimo.nivel),
                          const SizedBox(height: 6),
                          Text(DateFormat('dd/MM/yyyy · HH:mm').format(ultimo.fecha),
                              style: Theme.of(context).textTheme.bodyMedium),
                          if (ultimo.grado != null)
                            Text(ultimo.grado!, style: Theme.of(context).textTheme.bodyMedium),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              const TituloSeccion('Evolución del índice de riesgo'),
              RaizCard(
                padding: const EdgeInsets.fromLTRB(8, 20, 20, 12),
                child: SizedBox(
                  height: 190,
                  child: lista.length < 2
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              'Con 2 o más evaluaciones verás aquí la línea de evolución.',
                              style: Theme.of(context).textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : _GraficoEvolucion(lista: lista),
                ),
              ),
              const SizedBox(height: 22),
              const TituloSeccion('Todas las evaluaciones'),
              for (final r in lista.reversed)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: RaizCard(
                    onTap: () => _verEvaluacion(r),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(r.nivel.icono, color: r.nivel.color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(DateFormat('dd/MM/yyyy · HH:mm').format(r.fecha),
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 14.5)),
                              Text('${r.nivel.etiqueta} · índice ${(r.puntaje * 100).round()}',
                                  style: Theme.of(context).textTheme.bodySmall),
                              if (r.senales.isNotEmpty || r.vistaRuta != null)
                                Text('Toca para ver el detalle',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppTheme.bosque, fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Eliminar',
                          onPressed: () => _eliminar(r),
                          icon: const Icon(Icons.delete_outline_rounded, color: AppTheme.tintaSuave),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              const AvisoEtico(),
            ],
          );
        },
      ),
    );
  }
}

class _GraficoEvolucion extends StatelessWidget {
  final List<RegistroEstudiante> lista;
  const _GraficoEvolucion({required this.lista});

  @override
  Widget build(BuildContext context) {
    final spots = [
      for (var i = 0; i < lista.length; i++) FlSpot(i.toDouble(), lista[i].puntaje * 100),
    ];

    return LineChart(
      LineChartData(
        minY: 0,
        maxY: 100,
        minX: 0,
        maxX: (lista.length - 1).toDouble(),
        gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 25),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 34, interval: 25),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 1,
              reservedSize: 26,
              getTitlesWidget: (value, meta) {
                final i = value.round();
                if (i < 0 || i >= lista.length || value != i.toDouble()) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(DateFormat('dd/MM').format(lista[i].fecha),
                      style: const TextStyle(fontSize: 10.5, color: AppTheme.tintaSuave)),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            preventCurveOverShooting: true,
            color: AppTheme.bosque,
            barWidth: 3.5,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: true, color: AppTheme.bosque.withValues(alpha: 0.10)),
          ),
        ],
      ),
    );
  }
}
