import 'package:flutter/material.dart';

import '../navigation/app_router.dart';

/// Pantalla principal: acceso rápido a los 3 módulos. Pensada para que un
/// docente sin mucha experiencia digital entienda de un vistazo qué hacer.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Raíz')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '¿Qué querés hacer hoy?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _BotonModulo(
              icono: Icons.psychology_alt,
              titulo: 'Evaluar riesgo de un estudiante',
              subtitulo: 'Foto de la escritura → alerta de riesgo',
              onTap: () => Navigator.pushNamed(context, AppRouter.captura),
            ),
            const SizedBox(height: 12),
            _BotonModulo(
              icono: Icons.document_scanner,
              titulo: 'Digitalizar texto (OCR)',
              subtitulo: 'Convertir una foto de texto a texto editable',
              onTap: () => Navigator.pushNamed(context, AppRouter.ocr),
            ),
            const SizedBox(height: 12),
            _BotonModulo(
              icono: Icons.bar_chart,
              titulo: 'Ver historial',
              subtitulo: 'Evaluaciones guardadas por estudiante',
              onTap: () => Navigator.pushNamed(context, AppRouter.dashboard),
            ),
          ],
        ),
      ),
    );
  }
}

class _BotonModulo extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String subtitulo;
  final VoidCallback onTap;

  const _BotonModulo({
    required this.icono,
    required this.titulo,
    required this.subtitulo,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icono, size: 32),
        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitulo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }
}
