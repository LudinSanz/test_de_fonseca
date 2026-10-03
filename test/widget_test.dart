import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_de_fonseca/main.dart';
import 'package:test_de_fonseca/screens/login_screen.dart';

void main() {
  testWidgets('Prueba de renderizado inicial de la aplicación', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // Validar que se muestra la pantalla de Login y los elementos principales
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('RIZO DENTAL'), findsOneWidget);
    expect(find.text('Iniciar Sesión'), findsOneWidget);
  });
}
