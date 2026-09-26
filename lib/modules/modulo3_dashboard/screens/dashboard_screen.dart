import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../modulo2_deteccion/models/riesgo_resultado.dart';
import '../db/app_database.dart';
import '../models/registro_estudiante.dart';

/// Pantalla del docente: historial de todos los estudiantes evaluados.
/// TODO(equipo): agregar filtro por estudiante y el gráfico de evolución
/// (fl_chart) una vez haya datos reales para mostrar.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  Color _colorDe(NivelRiesgo n) {
    switch (n) {
      case NivelRiesgo.bajo:
        return AppTheme.riesgoBajo;
      case NivelRiesgo.medio:
        return AppTheme.riesgoMedio;
      case NivelRiesgo.alto:
        return AppTheme.riesgoAlto;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial de evaluaciones')),
      body: FutureBuilder<List<RegistroEstudiante>>(
        future: AppDatabase.todos(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final registros = snapshot.data!;
          if (registros.isEmpty) {
            return const Center(child: Text('Todavía no hay evaluaciones guardadas.'));
          }
          return ListView.separated(
            itemCount: registros.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final r = registros[i];
              return ListTile(
                leading: Icon(Icons.circle, color: _colorDe(r.nivel)),
                title: Text(r.nombreEstudiante),
                subtitle: Text(DateFormat('dd/MM/yyyy HH:mm').format(r.fecha)),
                trailing: Text('${(r.puntaje * 100).toStringAsFixed(0)}%'),
              );
            },
          );
        },
      ),
    );
  }
}
