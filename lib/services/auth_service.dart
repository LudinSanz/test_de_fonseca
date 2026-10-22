import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import 'supabase_service.dart';
import 'local_db_service.dart';

class AuthService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<User?> login(String email, String password) async {
    final cleanEmail = email.trim();
    if (_supabase != null) {
      try {
        final response = await _supabase!.auth.signInWithPassword(
          email: cleanEmail,
          password: password,
        );
        final suUser = response.user;
        if (suUser != null) {
          final name = suUser.userMetadata?['name'] ?? suUser.email?.split('@').first ?? 'Usuario';
          await guardarPerfilUsuario(suUser.id, suUser.email ?? cleanEmail, name);
          return User(
            id: suUser.id,
            email: suUser.email ?? cleanEmail,
            name: name,
          );
        }
        return null;
      } on AuthException catch (e) {
        debugPrint('Error de autenticación Supabase: ${e.message}');
        rethrow;
      } catch (e) {
        debugPrint('Error general en login Supabase: $e');
        rethrow;
      }
    }

    // Modo fuera de línea: solo si el cliente Supabase no pudo inicializarse por falta de red
    // y existe una sesión previa guardada localmente para este mismo correo.
    final activeDoc = await LocalDbService.getDoctorProfile(cleanEmail);
    if (activeDoc != null && (activeDoc['email']?.toString().toLowerCase() == cleanEmail.toLowerCase())) {
      return User(
        id: activeDoc['id'] ?? 'usr_offline',
        email: cleanEmail,
        name: activeDoc['name'] ?? 'Doctor (Offline)',
      );
    }
    throw Exception('No fue posible autenticar. Verifica tus credenciales y conexión de red.');
  }

  Future<User?> register(String name, String email, String password) async {
    final cleanEmail = email.trim();
    final cleanName = name.trim();
    if (_supabase != null) {
      try {
        final response = await _supabase!.auth.signUp(
          email: cleanEmail,
          password: password,
          data: {'name': cleanName},
        );
        final suUser = response.user;
        if (suUser != null) {
          await guardarPerfilUsuario(suUser.id, suUser.email ?? cleanEmail, cleanName);
          return User(
            id: suUser.id,
            email: suUser.email ?? cleanEmail,
            name: cleanName,
          );
        }
        return null;
      } on AuthException catch (e) {
        debugPrint('Error en registro Supabase: ${e.message}');
        rethrow;
      } catch (e) {
        debugPrint('Error general en registro Supabase: $e');
        rethrow;
      }
    }

    throw Exception('Se requiere conexión a la base de datos para registrar una nueva cuenta clínica.');
  }

  Future<void> guardarPerfilUsuario(String userId, String userEmail, String? nombre) async {
    final userData = {
      'id': userId,
      'name': nombre ?? 'Dr. Especialista Rizo Dental',
      'email': userEmail.trim(),
      'created_at': DateTime.now().toIso8601String(),
    };
    try {
      final supabaseService = SupabaseService();
      await supabaseService.guardarPerfilDoctor(userData);
      debugPrint('Perfil del usuario guardado con ID: $userId');
    } catch (e) {
      debugPrint('Error al guardar el perfil del usuario: $e');
    }
  }

  Future<User?> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        scopes: ['email', 'profile'],
      );
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser != null) {
        final name = googleUser.displayName ?? 'Usuario Google';
        final email = googleUser.email.trim();
        final userId = 'google_${googleUser.id}';
        
        await guardarPerfilUsuario(userId, email, name);
        return User(
          id: userId,
          email: email,
          name: name,
        );
      }
      return null;
    } catch (e) {
      debugPrint('Error en Google Sign In: $e');
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _supabase?.auth.resetPasswordForEmail(email);
    } catch (e) {
      debugPrint('Reseteo de contraseña enviado con aviso: $e');
    }
  }

  Future<User?> getCurrentUser() async {
    final suUser = _supabase?.auth.currentUser;
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
    try {
      await _supabase?.auth.signOut();
    } catch (e) {
      debugPrint('Sesión remota cerrada con aviso: $e');
    }
    try {
      await LocalDbService.clearActiveDoctorSession();
    } catch (_) {}
  }
}

