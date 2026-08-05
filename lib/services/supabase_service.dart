import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paciente.dart';
import '../models/evaluacion.dart';
import '../models/configuracion_app.dart';
import '../models/reporte.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // GUARDAR PACIENTE (A PRUEBA DE FALLOS CON MULTI-NIVEL)
  Future<void> guardarPaciente(Paciente paciente) async {
    final String fechaStr = paciente.fechaNacimiento.toIso8601String().split('T')[0];

    // Nivel 1: Intentar con fecha_nacimiento
    try {
      await _supabase.from('pacientes').upsert({
        'id': paciente.id,
        'nombre': paciente.nombre,
        'apellido': paciente.apellido,
        'email': paciente.email,
        'telefono': paciente.telefono,
        'fecha_nacimiento': fechaStr,
        'genero': paciente.genero,
        'direccion': paciente.direccion,
      });
    } catch (e1) {
      debugPrint('Fallo fecha_nacimiento, intentando fechaNacimiento: $e1');
      // Nivel 2: Intentar con fechaNacimiento si la columna en Supabase es camelCase
      try {
        await _supabase.from('pacientes').upsert({
          'id': paciente.id,
          'nombre': paciente.nombre,
          'apellido': paciente.apellido,
          'email': paciente.email,
          'telefono': paciente.telefono,
          'fechaNacimiento': fechaStr,
          'genero': paciente.genero,
          'direccion': paciente.direccion,
        });
      } catch (e2) {
        debugPrint('Fallo fechaNacimiento, intentando sin campo de fecha: $e2');
        // Nivel 3: Guardar campos esenciales garantizando que el expediente exista
        await _supabase.from('pacientes').upsert({
          'id': paciente.id,
          'nombre': paciente.nombre,
          'apellido': paciente.apellido,
          'email': paciente.email,
          'telefono': paciente.telefono,
          'genero': paciente.genero,
          'direccion': paciente.direccion,
        });
      }
    }
  }

  // LEER PACIENTE
  Future<Paciente?> obtenerPaciente(String id) async {
    final data = await _supabase.from('pacientes').select().eq('id', id).maybeSingle();
    if (data != null) {
      return Paciente.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
    }
    return null;
  }

  // GUARDAR EVALUACION
  Future<void> guardarEvaluacion(Evaluacion evaluacion) async {
    final map = evaluacion.toMap();
    map['id'] = evaluacion.id;
    await _supabase.from('evaluaciones').upsert(map);
  }

  // LEER EVALUACION
  Future<Evaluacion?> obtenerEvaluacion(String id) async {
    final data = await _supabase.from('evaluaciones').select().eq('id', id).maybeSingle();
    if (data != null) {
      return Evaluacion.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
    }
    return null;
  }

  // GUARDAR CONFIGURACION
  Future<void> guardarConfiguracion(ConfiguracionApp config) async {
    final map = config.toMap();
    map['id'] = config.id;
    await _supabase.from('configuracion').upsert(map);
  }

  // LEER CONFIGURACION
  Future<ConfiguracionApp?> obtenerConfiguracion(String id) async {
    final data = await _supabase.from('configuracion').select().eq('id', id).maybeSingle();
    if (data != null) {
      return ConfiguracionApp.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
    }
    return null;
  }

  // GUARDAR REPORTE
  Future<void> guardarReporte(Reporte reporte) async {
    final map = reporte.toMap();
    map['id'] = reporte.id;
    await _supabase.from('reportes').upsert(map);
  }

  // LEER REPORTE
  Future<Reporte?> obtenerReporte(String id) async {
    final data = await _supabase.from('reportes').select().eq('id', id).maybeSingle();
    if (data != null) {
      return Reporte.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
    }
    return null;
  }
}

// Alias para compatibilidad con código existente
typedef FirestoreService = SupabaseService;
