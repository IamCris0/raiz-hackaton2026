import 'dart:convert';

import '../../modulo2_deteccion/models/riesgo_resultado.dart';

/// Un registro histórico: un estudiante + el resultado de una evaluación del
/// Módulo 2 en una fecha dada. Es lo que se guarda en SQLite para que el
/// docente vea la evolución en el tiempo (Módulo 3).
class RegistroEstudiante {
  final int? id;
  final String nombreEstudiante;
  final String? grado;
  final NivelRiesgo nivel;
  final double puntaje;
  final DateTime fecha;

  /// Qué se detectó, para que semanas después el docente sepa por qué salió
  /// la alerta. Vacías en registros guardados antes de la versión 3.
  final List<String> senales;
  final List<String> observaciones;

  /// Ruta local de la imagen analizada (renglones y letras marcadas).
  final String? vistaRuta;

  RegistroEstudiante({
    this.id,
    required this.nombreEstudiante,
    this.grado,
    required this.nivel,
    required this.puntaje,
    required this.fecha,
    this.senales = const [],
    this.observaciones = const [],
    this.vistaRuta,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nombre_estudiante': nombreEstudiante,
        'grado': grado,
        'nivel': nivel.name,
        'puntaje': puntaje,
        'fecha': fecha.toIso8601String(),
        'senales': jsonEncode(senales),
        'observaciones': jsonEncode(observaciones),
        'vista_ruta': vistaRuta,
      };

  factory RegistroEstudiante.fromMap(Map<String, Object?> map) {
    List<String> lista(Object? v) => v is String ? List<String>.from(jsonDecode(v) as List) : const [];
    return RegistroEstudiante(
      id: map['id'] as int?,
      nombreEstudiante: map['nombre_estudiante'] as String,
      grado: map['grado'] as String?,
      nivel: NivelRiesgo.values.byName(map['nivel'] as String),
      puntaje: (map['puntaje'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
      senales: lista(map['senales']),
      observaciones: lista(map['observaciones']),
      vistaRuta: map['vista_ruta'] as String?,
    );
  }
}

/// Resumen para la pantalla de inicio y el dashboard.
class ResumenHistorial {
  final int evaluaciones;
  final int estudiantes;
  final int alertasAltas;
  final List<RegistroEstudiante> recientes;

  const ResumenHistorial({
    required this.evaluaciones,
    required this.estudiantes,
    required this.alertasAltas,
    required this.recientes,
  });

  static const vacio = ResumenHistorial(evaluaciones: 0, estudiantes: 0, alertasAltas: 0, recientes: []);
}
