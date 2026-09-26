import 'package:flutter/material.dart';

/// Tema visual único de la app. Cambia los colores acá y se propaga a todo
/// Raíz — no hardcodear colores dentro de las pantallas de los módulos.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF2A78D6); // azul — marca Raíz
  static const Color secondary = Color(0xFF1BAF7A); // aqua
  static const Color riesgoAlto = Color(0xFFD03B3B); // rojo — alerta alta
  static const Color riesgoMedio = Color(0xFFEDA100); // amarillo — alerta media
  static const Color riesgoBajo = Color(0xFF0CA30C); // verde — sin señales

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: primary),
      scaffoldBackgroundColor: const Color(0xFFFCFCFB),
      appBarTheme: const AppBarTheme(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
