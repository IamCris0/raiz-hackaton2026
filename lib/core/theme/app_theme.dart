import 'package:flutter/material.dart';

/// Identidad visual de Raíz: verde bosque (raíces, crecimiento) + ámbar cálido
/// (la alerta temprana) sobre un fondo crema suave, pensado para leerse bien
/// en celulares de gama baja y a pleno sol en el aula.
///
/// Regla: ninguna pantalla hardcodea colores — todo sale de aquí.
class AppTheme {
  AppTheme._();

  // Marca
  static const Color bosque = Color(0xFF1F6F4A);
  static const Color bosqueOscuro = Color(0xFF0F3D2A);
  static const Color brote = Color(0xFF6BBF8A);
  static const Color ambar = Color(0xFFF2A541);
  static const Color crema = Color(0xFFF7F5EF);
  static const Color tinta = Color(0xFF1C1C1A);
  static const Color tintaSuave = Color(0xFF5E5D58);
  static const Color borde = Color(0xFFE6E3DA);

  // Semáforo de riesgo
  static const Color riesgoBajo = Color(0xFF2E9E5B);
  static const Color riesgoMedio = Color(0xFFE8A317);
  static const Color riesgoAlto = Color(0xFFD64545);

  // Compatibilidad con el nombre usado en el scaffold original
  static const Color primary = bosque;

  static const LinearGradient gradienteMarca = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bosqueOscuro, bosque, Color(0xFF2F8F5E)],
  );

  static const LinearGradient gradienteAccion = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1F6F4A), Color(0xFF3AA06B)],
  );

  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: bosque,
      primary: bosque,
      secondary: ambar,
      surface: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: crema,
      textTheme: const TextTheme(
        headlineMedium: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: tinta, letterSpacing: -0.5),
        titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: tinta),
        titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: tinta),
        bodyLarge: TextStyle(fontSize: 15, color: tinta, height: 1.4),
        bodyMedium: TextStyle(fontSize: 14, color: tintaSuave, height: 1.4),
        bodySmall: TextStyle(fontSize: 12, color: tintaSuave, height: 1.35),
        labelLarge: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: crema,
        foregroundColor: tinta,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: tinta),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: borde),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: bosque,
          foregroundColor: Colors.white,
          disabledBackgroundColor: borde,
          elevation: 0,
          minimumSize: const Size.fromHeight(54),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: bosque,
          minimumSize: const Size.fromHeight(54),
          side: const BorderSide(color: bosque, width: 1.5),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borde),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: bosque, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        side: const BorderSide(color: borde),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: tinta),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: bosqueOscuro,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}
