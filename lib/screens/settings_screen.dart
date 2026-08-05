import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../theme_provider.dart';
import '../constants/colors.dart';
import 'profile_screen.dart';
import 'help_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _isLoading = true;
  bool _notificacionesActivas = true;

  @override
  void initState() {
    super.initState();
    _cargarConfiguracionSupabase();
  }

  Future<void> _cargarConfiguracionSupabase() async {
    setState(() => _isLoading = true);
    try {
      final res = await Supabase.instance.client
          .from('configuracion')
          .select()
          .eq('id', 'global')
          .maybeSingle();

      if (res != null) {
        setState(() {
          _notificacionesActivas = res['notificaciones'] ?? true;
        });
      }
    } catch (e) {
      debugPrint('Error al cargar configuración de Supabase: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarConfiguracion(bool val) async {
    setState(() => _notificacionesActivas = val);
    try {
      await Supabase.instance.client.from('configuracion').upsert({
        'id': 'global',
        'notificaciones': val,
        'tema': 'light',
      });
    } catch (e) {
      debugPrint('Error al guardar configuración en Supabase: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.settings_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIZO DENTAL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Configuración Global de la Clínica',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : ListView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                children: [
                  // Card 1: Tema de la Aplicación
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                      ],
                    ),
                    child: Consumer<ThemeProvider>(
                      builder: (context, themeProvider, _) => SwitchListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        title: const Text('Modo Oscuro', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                        subtitle: const Text('Cambia el aspecto visual de la aplicación', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                        secondary: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
                        ),
                        value: themeProvider.isDarkMode,
                        activeColor: AppColors.primary,
                        onChanged: (v) => themeProvider.toggleTheme(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Card 2: Notificaciones Supabase
                  Container(
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLowest,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: const [
                        BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                      ],
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      title: const Text('Notificaciones y Alertas', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                      subtitle: const Text('Recordatorios de citas e inventario bajo', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
                      secondary: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                        child: const Icon(Icons.notifications_active_outlined, color: AppColors.primary),
                      ),
                      value: _notificacionesActivas,
                      activeColor: AppColors.primary,
                      onChanged: _guardarConfiguracion,
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Card 3: Perfil Profesional del Doctor
                  _buildSettingsTile(
                    title: 'Perfil Profesional del Doctor',
                    subtitle: 'Configura el membrete oficial, colegiado y firma digital',
                    icon: Icons.person_pin_outlined,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileScreen()));
                    },
                  ),
                  const SizedBox(height: 14),

                  // Card 4: Ayuda y Soporte Técnico
                  _buildSettingsTile(
                    title: 'Centro de Ayuda & Soporte',
                    subtitle: 'Guía clínica y contacto con desarrollo Rizo Dental',
                    icon: Icons.help_outline_rounded,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HelpScreen()));
                    },
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
          child: Icon(icon, color: AppColors.primary),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.textLight),
        onTap: onTap,
      ),
    );
  }
}
