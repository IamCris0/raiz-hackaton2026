/// Constantes compartidas por toda la app.
class AppConstants {
  AppConstants._();

  static const String appName = 'Raíz';

  /// Texto legal/ético que debe acompañar SIEMPRE un resultado del Módulo 2.
  /// Raíz genera una alerta de riesgo, nunca un diagnóstico clínico.
  static const String avisoNoDiagnostico =
      'Este resultado es una alerta de riesgo, no un diagnóstico clínico. '
      'Se recomienda derivar al estudiante a un profesional especializado.';

  static const String dbName = 'raiz_local.db';
  static const int dbVersion = 1;
}
