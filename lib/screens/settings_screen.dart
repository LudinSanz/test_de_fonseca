import 'profile_screen.dart';
import 'notifications_screen.dart';
import 'help_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/configuracion_app.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  Future<Map<String, dynamic>?> _getUserData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return null;
    final res = await Supabase.instance.client
        .from('users')
        .select()
        .eq('id', user.id)
        .maybeSingle();
    return res != null ? Map<String, dynamic>.from(res) : null;
  }

  ConfiguracionApp? _configuracionApp;
  bool _loadingConfig = true;
  String? _configError;

  @override
  void initState() {
    super.initState();
    _loadConfiguracionApp();
  }

  Future<void> _loadConfiguracionApp() async {
    setState(() {
      _loadingConfig = true;
      _configError = null;
    });
    try {
      final data = await Supabase.instance.client
          .from('configuracion')
          .select()
          .eq('id', 'global')
          .maybeSingle();
      if (data != null) {
        setState(() {
          _configuracionApp = ConfiguracionApp.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
          _loadingConfig = false;
        });
      } else {
        setState(() {
          _configuracionApp = null;
          _loadingConfig = false;
        });
      }
    } catch (e) {
      setState(() {
        _configError = e.toString();
        _loadingConfig = false;
      });
    }
  }

  Future<void> _editarConfiguracionApp() async {
    if (_configuracionApp == null) return;
    final TextEditingController versionController = TextEditingController(text: _configuracionApp!.version);
    final TextEditingController mensajeController = TextEditingController(text: _configuracionApp!.mensajeBienvenida);
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Editar configuración global'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: versionController,
                decoration: const InputDecoration(labelText: 'Versión'),
              ),
              TextField(
                controller: mensajeController,
                decoration: const InputDecoration(labelText: 'Mensaje de bienvenida'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () async {
                final nuevaConfig = ConfiguracionApp(
                  id: 'global',
                  version: versionController.text,
                  mensajeBienvenida: mensajeController.text,
                  parametros: _configuracionApp!.parametros,
                );
                final map = nuevaConfig.toMap();
                map['id'] = 'global';
                await Supabase.instance.client.from('configuracion').upsert(map);
                Navigator.pop(context);
                _loadConfiguracionApp();
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Configuración'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data;
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              Consumer<ThemeProvider>(
                builder: (context, themeProvider, _) => SwitchListTile(
                  title: const Text('Modo oscuro'),
                  value: themeProvider.isDarkMode,
                  onChanged: (v) => themeProvider.toggleTheme(),
                  secondary: const Icon(Icons.dark_mode),
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.person,
                title: 'Perfil',
                subtitle: userData != null ? userData['nombre'] ?? 'Usuario' : 'Cargando...',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.notifications,
                title: 'Notificaciones',
                subtitle: 'Gestiona tus preferencias de notificación',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const NotificationsScreen()),
                  );
                },
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                icon: Icons.help_outline,
                title: 'Ayuda',
                subtitle: 'Preguntas frecuentes y soporte',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                },
              ),
              const SizedBox(height: 32),
              Card(
                color: Colors.amber.shade50,
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Configuración global', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          IconButton(
                            icon: const Icon(Icons.edit, color: Colors.blue),
                            onPressed: _loadingConfig || _configuracionApp == null ? null : _editarConfiguracionApp,
                          ),
                        ],
                      ),
                      _loadingConfig
                          ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 8),
                              child: LinearProgressIndicator(),
                            )
                          : _configError != null
                              ? Text('Error: '+_configError!, style: const TextStyle(color: Colors.red))
                              : _configuracionApp != null
                                  ? Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Versión: '+_configuracionApp!.version),
                                        Text('Mensaje: '+_configuracionApp!.mensajeBienvenida),
                                      ],
                                    )
                                  : const Text('No hay configuración global.'),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 3,
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.blue.shade50,
          child: Icon(icon, color: Colors.blue),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
        onTap: onTap,
      ),
    );
  }
}
