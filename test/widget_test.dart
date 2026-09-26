import 'package:flutter_test/flutter_test.dart';

import 'package:raiz_app/main.dart';

void main() {
  testWidgets('La pantalla principal muestra la acción principal y las herramientas', (tester) async {
    await tester.pumpWidget(const RaizApp());
    await tester.pumpAndSettle();

    expect(find.text('Nueva evaluación'), findsOneWidget);
    expect(find.text('Digitalizar texto'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
  });
}
