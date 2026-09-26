import '../../modulo2_deteccion/models/riesgo_resultado.dart';

/// Un registro histórico: un estudiante + el resultado de una evaluación del
/// Módulo 2 en una fecha dada. Es lo que se guarda en SQLite para que el
/// docente vea la evolución en el tiempo (Módulo 3).
class RegistroEstudiante {
  final int? id;
  final String nombreEstudiante;
  final NivelRiesgo nivel;
  final double puntaje;
  final DateTime fecha;

  RegistroEstudiante({
    this.id,
    required this.nombreEstudiante,
    required this.nivel,
    required this.puntaje,
    required this.fecha,
  });

  Map<String, Object?> toMap() => {
        'id': id,
        'nombre_estudiante': nombreEstudiante,
        'nivel': nivel.name,
        'puntaje': puntaje,
        'fecha': fecha.toIso8601String(),
      };

  factory RegistroEstudiante.fromMap(Map<String, Object?> map) {
    return RegistroEstudiante(
      id: map['id'] as int?,
      nombreEstudiante: map['nombre_estudiante'] as String,
      nivel: NivelRiesgo.values.byName(map['nivel'] as String),
      puntaje: (map['puntaje'] as num).toDouble(),
      fecha: DateTime.parse(map['fecha'] as String),
    );
  }
}
