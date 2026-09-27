import 'dart:typed_data';

/// Nivel de alerta que devuelve el Módulo 2 tras analizar una foto de
/// escritura. Nunca es un diagnóstico — ver [AppConstants.avisoNoDiagnostico].
enum NivelRiesgo { bajo, medio, alto }

/// Resultado de analizar una muestra de escritura.
///
/// [senales] son los rasgos que la heurística (o, a futuro, el modelo
/// TFLite) detectó — se muestran al docente para que entienda el "por qué"
/// de la alerta, no solo el semáforo.
class RiesgoResultado {
  final NivelRiesgo nivel;
  final double puntaje; // 0.0 - 1.0, entre más alto más señales de riesgo
  final List<String> senales;

  /// Rasgos que se ven en la escritura pero no cambian el índice (por
  /// ejemplo, uno que la calibración dejó sin peso) o avisos sobre la
  /// muestra. Se muestran aparte de [senales].
  final List<String> observaciones;
  final DateTime fecha;

  /// JPEG de la zona escrita con la línea de cada renglón y las letras que
  /// la siguen (verde) o se salen de ella (rojo). Null si no se generó.
  final Uint8List? vista;

  RiesgoResultado({
    required this.nivel,
    required this.puntaje,
    required this.senales,
    this.observaciones = const [],
    this.vista,
    DateTime? fecha,
  }) : fecha = fecha ?? DateTime.now();
}
