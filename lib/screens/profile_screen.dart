import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Perfil'),
        backgroundColor: isDark ? Colors.grey[900] : Colors.blue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: _getUserData(),
        builder: (context, snapshot) {
          final userData = snapshot.data;
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (userData == null) {
            return const Center(child: Text('No se encontraron datos de usuario.'));
          }
          final nombre = userData['nombre'] ?? 'Usuario';
          final email = userData['email'] ?? 'correo@ejemplo.com';
          final rol = userData['rol'] ?? 'Clínico';
          DateTime? fecha;
          final fr = userData['fecha_registro'] ?? userData['fechaRegistro'];
          if (fr is String) {
            fecha = DateTime.tryParse(fr);
          }

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              ListTile(
                leading: const Icon(Icons.person, color: Colors.blue),
                title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(email),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.verified_user, color: Colors.green),
                title: const Text('Rol'),
                subtitle: Text(rol),
              ),
              if (fecha != null)
                ListTile(
                  leading: const Icon(Icons.calendar_today, color: Colors.orange),
                  title: const Text('Fecha de registro'),
                  subtitle: Text('${fecha.day}/${fecha.month}/${fecha.year}'),
                ),
            ],
          );
        },
      ),
    );
  }
}
