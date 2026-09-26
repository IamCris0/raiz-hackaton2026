import 'package:flutter_test/flutter_test.dart';

import 'package:raiz_app/main.dart';

void main() {
  testWidgets('La pantalla principal muestra los 3 módulos', (tester) async {
    await tester.pumpWidget(const RaizApp());
    await tester.pump();

    expect(find.text('Evaluar riesgo de un estudiante'), findsOneWidget);
    expect(find.text('Digitalizar texto (OCR)'), findsOneWidget);
    expect(find.text('Ver historial'), findsOneWidget);
  });
}
