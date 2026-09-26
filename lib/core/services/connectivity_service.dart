import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

/// Decide si la app puede usar el modo "online" del Módulo 1 (OCR vía Vision
/// API) o debe quedarse en modo on-device. Ningún otro módulo depende de
/// esto: Módulo 2 y 3 siempre son 100% locales.
class ConnectivityService extends ChangeNotifier {
  bool _online = false;
  bool get online => _online;

  Future<void> init() async {
    try {
      final result = await Connectivity().checkConnectivity();
      _update(result);
      Connectivity().onConnectivityChanged.listen(_update);
    } catch (_) {
      // Sin plugin disponible (p. ej. en tests): se asume modo offline.
      _online = false;
    }
  }

  void _update(List<ConnectivityResult> result) {
    final wasOnline = _online;
    _online = result.any((r) => r != ConnectivityResult.none);
    if (wasOnline != _online) notifyListeners();
  }
}
