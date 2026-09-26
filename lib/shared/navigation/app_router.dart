import 'package:flutter/material.dart';

import '../../modules/modulo1_ocr/screens/ocr_capture_screen.dart';
import '../../modules/modulo2_deteccion/screens/captura_escritura_screen.dart';
import '../../modules/modulo3_dashboard/screens/dashboard_screen.dart';
import '../widgets/home_screen.dart';

/// Rutas centralizadas. Agregar una pantalla nueva = agregar una constante +
/// un case, nada más.
class AppRouter {
  AppRouter._();

  static const home = '/';
  static const captura = '/captura';
  static const ocr = '/ocr';
  static const dashboard = '/dashboard';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case captura:
        return MaterialPageRoute(builder: (_) => const CapturaEscrituraScreen());
      case ocr:
        return MaterialPageRoute(builder: (_) => const OcrCaptureScreen());
      case dashboard:
        return MaterialPageRoute(builder: (_) => const DashboardScreen());
      case home:
      default:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
    }
  }
}
