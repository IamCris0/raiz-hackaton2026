import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_constants.dart';
import '../modules/modulo2_deteccion/models/riesgo_resultado.dart';
import 'widgets/raiz_widgets.dart';

/// Texto del reporte de una evaluación, para compartir con el DECE o la
/// familia. Siempre incluye el aviso de que no es un diagnóstico.
String textoReporte({
  required String nombre,
  String? grado,
  required DateTime fecha,
  required NivelRiesgo nivel,
  required double puntaje,
  required List<String> senales,
  List<String> observaciones = const [],
}) {
  final b = StringBuffer()
    ..writeln('${AppConstants.appName} — Reporte de evaluación de escritura')
    ..writeln()
    ..writeln('Estudiante: $nombre${grado == null ? '' : ' · $grado'}')
    ..writeln('Fecha: ${DateFormat('dd/MM/yyyy · HH:mm').format(fecha)}')
    ..writeln('Resultado: ${nivel.etiqueta} (índice ${(puntaje * 100).round()} de 100)')
    ..writeln(nivel.resumen);

  if (senales.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Señales detectadas:');
    for (final s in senales) {
      b.writeln('• $s');
    }
  }
  if (observaciones.isNotEmpty) {
    b
      ..writeln()
      ..writeln('Observaciones (no cambian el índice):');
    for (final o in observaciones) {
      b.writeln('• $o');
    }
  }
  b
    ..writeln()
    ..writeln('Qué hacer ahora:');
  for (final (i, r) in nivel.recomendaciones.indexed) {
    b.writeln('${i + 1}. $r');
  }
  b
    ..writeln()
    ..writeln('IMPORTANTE: ${AppConstants.avisoNoDiagnostico}')
    ..writeln()
    ..write('Generado con ${AppConstants.appName}, sin internet, en el celular del docente.');
  return b.toString();
}

/// Antes de que datos de un niño salgan de la app, el docente confirma con
/// quién los va a compartir.
Future<bool> confirmarCompartir(BuildContext context) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.lock_outline_rounded),
      title: const Text('Compartir reporte'),
      content: const Text(
        'El reporte incluye el nombre del estudiante y la foto de su escritura. '
        'Compártelo solo con el DECE, la autoridad de la institución o la familia.',
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Compartir')),
      ],
    ),
  );
  return ok == true;
}

/// Abre el menú de compartir del celular con el reporte y, si la hay, la
/// imagen analizada. Es el único momento en que datos del estudiante salen
/// de la app, y solo porque el docente lo pide.
Future<void> compartirReporte({
  required String texto,
  required String nombre,
  Uint8List? vista,
  String? vistaRuta,
}) async {
  final archivos = <XFile>[];
  if (vista != null) {
    final tmp = File(p.join((await getTemporaryDirectory()).path, 'raiz_reporte.jpg'));
    await tmp.writeAsBytes(vista, flush: true);
    archivos.add(XFile(tmp.path, mimeType: 'image/jpeg'));
  } else if (vistaRuta != null && File(vistaRuta).existsSync()) {
    archivos.add(XFile(vistaRuta, mimeType: 'image/jpeg'));
  }
  await SharePlus.instance.share(ShareParams(
    text: texto,
    subject: 'Raíz: evaluación de escritura de $nombre',
    files: archivos.isEmpty ? null : archivos,
  ));
}
