import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import '../models/user.dart';

class AuthService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<User?> login(String email, String password) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final suUser = response.user;
      if (suUser != null) {
        final name = suUser.userMetadata?['name'] ?? suUser.email?.split('@').first ?? 'Usuario';
        await guardarPerfilUsuario(suUser.id, suUser.email ?? '', name);
        return User(
          id: suUser.id,
          email: suUser.email ?? '',
          name: name,
        );
      }
      return null;
    } catch (e) {
      print('Error en login Supabase: $e');
      rethrow;
    }
  }

  Future<User?> register(String name, String email, String password) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      final suUser = response.user;
      if (suUser != null) {
        await guardarPerfilUsuario(suUser.id, suUser.email ?? '', name);
        return User(
          id: suUser.id,
          email: suUser.email ?? '',
          name: name,
        );
      }
      return null;
    } catch (e) {
      print('Error en registro Supabase: $e');
      rethrow;
    }
  }

  Future<void> guardarPerfilUsuario(String userId, String userEmail, String? nombre) async {
    final userData = {
      'id': userId,
      'nombre': nombre ?? 'Nombre del Usuario',
      'email': userEmail,
      'rol': 'clínico',
      'fecha_registro': DateTime.now().toIso8601String(),
    };
    try {
      await _supabase.from('users').upsert(userData);
      print('Perfil del usuario guardado en Supabase con ID: $userId');
    } catch (e) {
      print('Error al guardar el perfil en Supabase: $e');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      // Supabase OAuth via Google
      final bool res = await _supabase.auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: 'io.supabase.flutter://login-callback/',
      );
      if (res) {
        final suUser = _supabase.auth.currentUser;
        if (suUser != null) {
          final name = suUser.userMetadata?['full_name'] ?? suUser.email ?? 'Usuario Google';
          await guardarPerfilUsuario(suUser.id, suUser.email ?? '', name);
          return User(
            id: suUser.id,
            email: suUser.email ?? '',
            name: name,
          );
        }
      }
      return null;
    } catch (e) {
      print('Error en signInWithGoogle Supabase: $e');
      return null;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  Future<User?> getCurrentUser() async {
    final suUser = _supabase.auth.currentUser;
    if (suUser != null) {
      final name = suUser.userMetadata?['name'] ?? suUser.userMetadata?['full_name'] ?? suUser.email?.split('@').first ?? 'Usuario';
      return User(
        id: suUser.id,
        email: suUser.email ?? '',
        name: name,
      );
    }
    return null;
  }

  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }
}
