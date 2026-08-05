import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  bool _pushEnabled = true;
  bool _emailEnabled = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notificaciones'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SwitchListTile(
            value: _pushEnabled,
            onChanged: (v) => setState(() => _pushEnabled = v),
            title: const Text('Recibir notificaciones push'),
          ),
          SwitchListTile(
            value: _emailEnabled,
            onChanged: (v) => setState(() => _emailEnabled = v),
            title: const Text('Notificaciones por correo'),
          ),
        ],
      ),
    );
  }
}
