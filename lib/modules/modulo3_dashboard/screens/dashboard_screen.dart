import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/raiz_widgets.dart';
import '../../modulo2_deteccion/models/riesgo_resultado.dart';
import '../db/app_database.dart';
import '../models/registro_estudiante.dart';
import 'estudiante_detalle_screen.dart';

/// Módulo 3 — vista del docente: cómo está su grupo (distribución de
/// alertas) y la lista de estudiantes con su última evaluación.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late Future<List<RegistroEstudiante>> _datos = _cargar();

  Future<List<RegistroEstudiante>> _cargar() async {
    try {
      return await AppDatabase.todos();
    } catch (_) {
      return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: FutureBuilder<List<RegistroEstudiante>>(
        future: _datos,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final registros = snap.data!;
          if (registros.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(
                child: EstadoVacio(
                  icono: Icons.insights_rounded,
                  titulo: 'Tu historial está vacío',
                  mensaje: 'Cuando guardes una evaluación aparecerá aquí, '
                      'y podrás ver cómo evoluciona cada estudiante.',
                ),
              ),
            );
          }

          // Última evaluación por estudiante (la lista viene ordenada DESC).
          final porEstudiante = <String, RegistroEstudiante>{};
          final conteo = <String, int>{};
          for (final r in registros) {
            final k = r.nombreEstudiante.trim().toLowerCase();
            porEstudiante.putIfAbsent(k, () => r);
            conteo[k] = (conteo[k] ?? 0) + 1;
          }
          final ultimos = porEstudiante.values.toList();

          return RefreshIndicator(
            onRefresh: () async => setState(() => _datos = _cargar()),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                _TarjetaDistribucion(ultimos: ultimos),
                const SizedBox(height: 22),
                TituloSeccion('Estudiantes (${ultimos.length})'),
                for (final r in ultimos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _FilaEstudiante(
                      registro: r,
                      evaluaciones: conteo[r.nombreEstudiante.trim().toLowerCase()] ?? 1,
                      onTap: () async {
                        await Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => EstudianteDetalleScreen(nombre: r.nombreEstudiante),
                        ));
                        if (mounted) setState(() => _datos = _cargar());
                      },
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TarjetaDistribucion extends StatelessWidget {
  final List<RegistroEstudiante> ultimos;
  const _TarjetaDistribucion({required this.ultimos});

  @override
  Widget build(BuildContext context) {
    final n = {
      for (final nivel in NivelRiesgo.values) nivel: ultimos.where((r) => r.nivel == nivel).length,
    };
    final total = ultimos.length;

    return RaizCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado actual del grupo', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 2),
          Text('Según la última evaluación de cada estudiante', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 16),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        centerSpaceRadius: 40,
                        sectionsSpace: 3,
                        startDegreeOffset: -90,
                        sections: [
                          for (final nivel in NivelRiesgo.values)
                            if (n[nivel]! > 0)
                              PieChartSectionData(
                                value: n[nivel]!.toDouble(),
                                color: nivel.color,
                                radius: 22,
                                showTitle: false,
                              ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('$total', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                        const Text('total', style: TextStyle(fontSize: 11, color: AppTheme.tintaSuave)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  children: [
                    for (final nivel in NivelRiesgo.values.reversed)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(color: nivel.color, borderRadius: BorderRadius.circular(4)),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(nivel.etiqueta, style: Theme.of(context).textTheme.bodyMedium)),
                            Text('${n[nivel]}', style: const TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FilaEstudiante extends StatelessWidget {
  final RegistroEstudiante registro;
  final int evaluaciones;
  final VoidCallback onTap;

  const _FilaEstudiante({required this.registro, required this.evaluaciones, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final nombre = registro.nombreEstudiante.trim();
    final inicial = nombre.isEmpty ? '?' : nombre[0].toUpperCase();
    return RaizCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: registro.nivel.color.withValues(alpha: 0.14),
            child: Text(inicial, style: TextStyle(color: registro.nivel.color, fontWeight: FontWeight.w800, fontSize: 16)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nombre, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 15)),
                const SizedBox(height: 2),
                Text(
                  '${registro.grado ?? 'Sin grado'} · $evaluaciones ${evaluaciones == 1 ? 'evaluación' : 'evaluaciones'} · '
                  '${DateFormat('dd/MM').format(registro.fecha)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          InsigniaRiesgo(nivel: registro.nivel, compacta: true),
          const SizedBox(width: 4),
          const Icon(Icons.chevron_right_rounded, color: AppTheme.tintaSuave),
        ],
      ),
    );
  }
}
