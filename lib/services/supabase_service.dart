import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paciente.dart';
import '../models/evaluacion.dart';
import '../models/configuracion_app.dart';
import '../models/reporte.dart';

class SupabaseService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // GUARDAR PACIENTE
  Future<void> guardarPaciente(Paciente paciente) async {
    final map = paciente.toMap();
    map['id'] = paciente.id;
    await _supabase.from('pacientes').upsert(map);
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
