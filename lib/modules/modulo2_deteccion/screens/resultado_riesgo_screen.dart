import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/riesgo_resultado.dart';

/// Muestra el semáforo de riesgo + las señales detectadas + el aviso ético
/// obligatorio de que esto no es un diagnóstico clínico.
class ResultadoRiesgoScreen extends StatelessWidget {
  final RiesgoResultado resultado;

  const ResultadoRiesgoScreen({super.key, required this.resultado});

  Color get _color {
    switch (resultado.nivel) {
      case NivelRiesgo.bajo:
        return AppTheme.riesgoBajo;
      case NivelRiesgo.medio:
        return AppTheme.riesgoMedio;
      case NivelRiesgo.alto:
        return AppTheme.riesgoAlto;
    }
  }

  String get _etiqueta {
    switch (resultado.nivel) {
      case NivelRiesgo.bajo:
        return 'Sin señales relevantes';
      case NivelRiesgo.medio:
        return 'Señales moderadas — observar';
      case NivelRiesgo.alto:
        return 'Señales importantes — derivar a especialista';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resultado')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _color, width: 2),
              ),
              child: Column(
                children: [
                  Icon(Icons.circle, color: _color, size: 36),
                  const SizedBox(height: 8),
                  Text(_etiqueta,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _color, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text('Señales detectadas',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...resultado.senales.map((s) => ListTile(
                  leading: const Icon(Icons.chevron_right),
                  title: Text(s),
                )),
            const Spacer(),
            Text(
              AppConstants.avisoNoDiagnostico,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
