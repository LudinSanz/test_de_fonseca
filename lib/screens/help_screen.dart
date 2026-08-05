import 'package:flutter/material.dart';

class HelpScreen extends StatelessWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayuda'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('¿Tienes dudas o necesitas soporte?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('• Consulta las preguntas frecuentes.'),
            Text('• Escribe a soporte@tuapp.com.'),
            SizedBox(height: 24),
            Text('Versión de la app: 1.0.0', style: TextStyle(color: Colors.grey)),
          ],
        ),
      ),
    );
  }
}
