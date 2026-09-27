/// Constantes compartidas por toda la app.
class AppConstants {
  AppConstants._();

  static const String appName = 'Raíz';
  static const String lema = 'Detectar a tiempo, acompañar siempre.';

  /// Texto legal/ético que debe acompañar SIEMPRE un resultado del Módulo 2.
  /// Raíz genera una alerta de riesgo, nunca un diagnóstico clínico.
  static const String avisoNoDiagnostico =
      'Este resultado es una alerta de riesgo, no un diagnóstico clínico. '
      'Se recomienda derivar al estudiante a un profesional especializado.';

  static const List<String> grados = [
    '2.º EGB', '3.º EGB', '4.º EGB', '5.º EGB', '6.º EGB', '7.º EGB',
  ];

  static const String dbName = 'raiz_local.db';
  static const int dbVersion = 3; // v2: columna "grado" · v3: señales, observaciones y vista
}
