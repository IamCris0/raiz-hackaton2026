import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/services/connectivity_service.dart';
import 'shared/navigation/app_router.dart';

void main() {
  runApp(const RaizApp());
}

/// Raíz — punto de entrada de la app.
///
/// La app es offline-first: [ConnectivityService] decide en cada momento si
/// el Módulo 1 (OCR) puede usar el modo online (Vision API) o debe quedarse
/// en modo on-device. El resto de la app (Módulo 2 y 3) siempre funciona
/// localmente, con o sin señal.
class RaizApp extends StatelessWidget {
  const RaizApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ConnectivityService()..init()),
      ],
      child: MaterialApp(
        title: 'Raíz',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        initialRoute: AppRouter.home,
        onGenerateRoute: AppRouter.onGenerateRoute,
      ),
    );
  }
}
