import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paciente.dart';
import '../models/evaluacion.dart';
import '../models/configuracion_app.dart';
import '../models/reporte.dart';
import 'local_db_service.dart';

class SupabaseService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  // ==================== 1. PACIENTES ====================

  Future<List<Paciente>> obtenerPacientes() async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getPacientesMap();
    try {
      if (_supabase != null) {
        final response = await _supabase!.from('pacientes').select().order('nombre');
        if (response is List) {
          final remoteList = response.map((e) => Map<String, dynamic>.from(e)).toList();
          final Map<String, Map<String, dynamic>> mergedMap = {};
          for (var p in remoteList) {
            final id = p['id']?.toString() ?? '';
            if (id.isNotEmpty) mergedMap[id] = p;
          }
          for (var p in localList) {
            final id = p['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              // Combine remote and local properties so local updates are kept
              final existing = mergedMap[id] ?? {};
              mergedMap[id] = {...existing, ...p};
            }
          }
          final mergedList = mergedMap.values.toList();
          await LocalDbService.savePacientesMap(mergedList);
          return mergedList.map((p) => Paciente.fromMap(p, p['id'].toString())).toList();
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerPacientes (usando cache local): $e');
    }

    return localList.map((p) => Paciente.fromMap(p, p['id'].toString())).toList();
  }

  Future<Paciente?> obtenerPaciente(String id) async {
    try {
      if (_supabase != null) {
        final data = await _supabase!.from('pacientes').select().eq('id', id).maybeSingle();
        if (data != null) {
          final remoteMap = Map<String, dynamic>.from(data);
          await LocalDbService.upsertPacienteMap(remoteMap);
          return Paciente.fromMap(remoteMap, remoteMap['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerPaciente (usando cache local): $e');
    }

    final localList = await LocalDbService.getPacientesMap();
    final found = localList.firstWhere(
      (p) => p['id'].toString() == id,
      orElse: () => {},
    );
    if (found.isNotEmpty) {
      return Paciente.fromMap(found, found['id'].toString());
    }
    return null;
  }

  Future<void> guardarPaciente(Paciente paciente) async {
    final Map<String, dynamic> pacienteMap = paciente.toMap();
    await LocalDbService.upsertPacienteMap(pacienteMap);

    if (_supabase != null) {
      final String fechaStr = paciente.fechaNacimiento.toIso8601String().split('T')[0];
      try {
        await _supabase!.from('pacientes').upsert({
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
        try {
          await _supabase!.from('pacientes').upsert({
            'id': paciente.id,
            'nombre': paciente.nombre,
            'apellido': paciente.apellido,
            'email': paciente.email,
            'telefono': paciente.telefono,
            'genero': paciente.genero,
            'direccion': paciente.direccion,
          });
        } catch (e2) {
          debugPrint('Error en Supabase guardarPaciente, guardado localmente: $e2');
        }
      }
    }
  }

  Future<void> eliminarPaciente(String id) async {
    await LocalDbService.deletePacienteMap(id);
    try {
      if (_supabase != null) {
        await _supabase!.from('pacientes').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Aviso en Supabase eliminarPaciente: $e');
    }
  }

  // ==================== 2. EVALUACIONES ====================

  Future<List<Map<String, dynamic>>> obtenerEvaluaciones({String? pacienteId}) async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getEvaluacionesMap();
    try {
      if (_supabase != null) {
        var query = _supabase!.from('evaluaciones').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.or('paciente_id.eq.$pacienteId,pacienteId.eq.$pacienteId');
        }
        final response = await query.order('created_at', ascending: false);
        if (response is List) {
          final remoteList = response.map((e) => Map<String, dynamic>.from(e)).toList();
          final Map<String, Map<String, dynamic>> mergedMap = {};
          for (var item in remoteList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) mergedMap[id] = item;
          }
          for (var item in localList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              final existing = mergedMap[id] ?? {};
              mergedMap[id] = {...existing, ...item};
            }
          }
          final mergedList = mergedMap.values.toList();
          await LocalDbService.saveEvaluacionesMap(mergedList);
          if (pacienteId != null && pacienteId.isNotEmpty) {
            return mergedList.where((e) => e['paciente_id'] == pacienteId || e['pacienteId'] == pacienteId).toList();
          }
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerEvaluaciones (usando cache local): $e');
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((e) => e['paciente_id'] == pacienteId || e['pacienteId'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarEvaluacion(dynamic evaluacion) async {
    Map<String, dynamic> evalMap;
    if (evaluacion is Evaluacion) {
      evalMap = evaluacion.toMap();
    } else if (evaluacion is Map<String, dynamic>) {
      evalMap = Map<String, dynamic>.from(evaluacion);
    } else {
      return;
    }

    final String id = evalMap['id']?.toString() ?? 'eval_${DateTime.now().millisecondsSinceEpoch}';
    evalMap['id'] = id;
    await LocalDbService.upsertEvaluacionMap(evalMap);

    if (_supabase != null) {
      final cleanMap = {
        'id': id,
        'paciente_id': evalMap['paciente_id'] ?? evalMap['pacienteId'] ?? '',
        'paciente_nombre': evalMap['paciente_nombre'] ?? evalMap['pacienteNombre'] ?? 'Paciente General',
        'fecha': evalMap['fecha']?.toString() ?? DateTime.now().toIso8601String(),
        'puntuacion': evalMap['puntuacion'] ?? evalMap['score'] ?? 0,
        'diagnostico': evalMap['diagnostico'] ?? evalMap['diagnosis'] ?? '',
        'respuestas': evalMap['respuestas'] ?? evalMap['datos'] ?? {},
      };
      try {
        await _supabase!.from('evaluaciones').upsert(cleanMap);
      } catch (e) {
        debugPrint('Error en Supabase guardarEvaluacion, guardado localmente: $e');
      }
    }
  }

  // ==================== 3. CITAS ====================

  Future<List<Map<String, dynamic>>> obtenerCitas({String? pacienteId}) async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getCitasMap();
    try {
      if (_supabase != null) {
        var query = _supabase!.from('citas').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query.order('created_at', ascending: false);
        if (response is List) {
          final remoteList = response.map((e) => Map<String, dynamic>.from(e)).toList();
          final Map<String, Map<String, dynamic>> mergedMap = {};
          for (var item in remoteList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) mergedMap[id] = item;
          }
          for (var item in localList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              final existing = mergedMap[id] ?? {};
              mergedMap[id] = {...existing, ...item};
            }
          }
          final mergedList = mergedMap.values.toList();
          await LocalDbService.saveCitasMap(mergedList);
          if (pacienteId != null && pacienteId.isNotEmpty) {
            return mergedList.where((c) => c['paciente_id'] == pacienteId).toList();
          }
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerCitas (usando cache local): $e');
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((c) => c['paciente_id'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarCita(Map<String, dynamic> citaData) async {
    final String id = citaData['id']?.toString() ?? 'cita_${DateTime.now().millisecondsSinceEpoch}';
    citaData['id'] = id;
    await LocalDbService.upsertCitaMap(citaData);

    if (_supabase != null) {
      try {
        await _supabase!.from('citas').upsert(citaData);
      } catch (e) {
        debugPrint('Error en Supabase guardarCita, guardado localmente: $e');
      }
    }
  }

  Future<void> eliminarCita(String id) async {
    await LocalDbService.deleteCitaMap(id);
    try {
      if (_supabase != null) {
        await _supabase!.from('citas').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Aviso en Supabase eliminarCita: $e');
    }
  }

  // ==================== 4. INVENTARIO ====================

  Future<List<Map<String, dynamic>>> obtenerInventario() async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getInventarioMap();
    try {
      if (_supabase != null) {
        final response = await _supabase!.from('inventario').select().order('nombre', ascending: true);
        if (response is List) {
          final remoteList = response.map((e) => Map<String, dynamic>.from(e)).toList();
          final Map<String, Map<String, dynamic>> mergedMap = {};
          for (var item in remoteList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) mergedMap[id] = item;
          }
          for (var item in localList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              final existing = mergedMap[id] ?? {};
              mergedMap[id] = {...existing, ...item};
            }
          }
          final mergedList = mergedMap.values.toList();
          await LocalDbService.saveInventarioMap(mergedList);
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerInventario (usando cache local): $e');
    }

    return localList;
  }

  Future<void> guardarItemInventario(Map<String, dynamic> itemData) async {
    final String id = itemData['id']?.toString() ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';
    itemData['id'] = id;
    await LocalDbService.upsertInventarioMap(itemData);

    if (_supabase != null) {
      try {
        await _supabase!.from('inventario').upsert(itemData);
      } catch (e) {
        debugPrint('Error en Supabase guardarItemInventario, guardado localmente: $e');
      }
    }
  }

  Future<void> eliminarItemInventario(String id) async {
    await LocalDbService.deleteInventarioMap(id);
    try {
      if (_supabase != null) {
        await _supabase!.from('inventario').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Aviso en Supabase eliminarItemInventario: $e');
    }
  }

  // ==================== 5. RECETAS ====================

  Future<List<Map<String, dynamic>>> obtenerRecetas({String? pacienteId}) async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getRecetasMap();
    try {
      if (_supabase != null) {
        var query = _supabase!.from('recetas').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query.order('created_at', ascending: false);
        if (response is List) {
          final remoteList = response.map((e) => Map<String, dynamic>.from(e)).toList();
          final Map<String, Map<String, dynamic>> mergedMap = {};
          for (var item in remoteList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) mergedMap[id] = item;
          }
          for (var item in localList) {
            final id = item['id']?.toString() ?? '';
            if (id.isNotEmpty) {
              final existing = mergedMap[id] ?? {};
              mergedMap[id] = {...existing, ...item};
            }
          }
          final mergedList = mergedMap.values.toList();
          await LocalDbService.saveRecetasMap(mergedList);
          if (pacienteId != null && pacienteId.isNotEmpty) {
            return mergedList.where((r) => r['paciente_id'] == pacienteId).toList();
          }
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerRecetas (usando cache local): $e');
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((r) => r['paciente_id'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarReceta(Map<String, dynamic> recetaData) async {
    final String id = recetaData['id']?.toString() ?? 'receta_${DateTime.now().millisecondsSinceEpoch}';
    recetaData['id'] = id;
    await LocalDbService.upsertRecetaMap(recetaData);

    if (_supabase != null) {
      try {
        await _supabase!.from('recetas').upsert(recetaData);
      } catch (e) {
        debugPrint('Error en Supabase guardarReceta, guardado localmente: $e');
      }
    }
  }

  // ==================== 6. PERFIL DOCTOR ====================

  Future<Map<String, dynamic>?> obtenerPerfilDoctor(String idOrEmail) async {
    try {
      if (_supabase != null && idOrEmail.isNotEmpty) {
        var query = _supabase!.from('users').select();
        if (idOrEmail.contains('@')) {
          query = query.eq('email', idOrEmail);
        } else {
          query = query.eq('id', idOrEmail);
        }
        final res = await query.maybeSingle();
        if (res != null) {
          final profileMap = Map<String, dynamic>.from(res);
          await LocalDbService.saveDoctorProfile(profileMap);
          return profileMap;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerPerfilDoctor (usando cache local): $e');
    }

    return await LocalDbService.getDoctorProfile(idOrEmail);
  }

  Future<void> guardarPerfilDoctor(Map<String, dynamic> doctorData) async {
    await LocalDbService.saveDoctorProfile(doctorData);
    if (_supabase != null) {
      try {
        await _supabase!.from('users').upsert(doctorData);
      } catch (e) {
        debugPrint('Error en Supabase guardarPerfilDoctor, guardado localmente: $e');
      }
    }
  }

  // ==================== 7. CONFIGURACION Y REPORTES ====================

  Future<void> guardarConfiguracion(ConfiguracionApp config) async {
    final map = config.toMap();
    map['id'] = config.id;
    await LocalDbService.saveList('db_configuracion_v2', [map]);
    if (_supabase != null) {
      try {
        await _supabase!.from('configuracion').upsert(map);
      } catch (e) {
        debugPrint('Error guardarConfiguracion: $e');
      }
    }
  }

  Future<ConfiguracionApp?> obtenerConfiguracion(String id) async {
    try {
      if (_supabase != null) {
        final data = await _supabase!.from('configuracion').select().eq('id', id).maybeSingle();
        if (data != null) {
          return ConfiguracionApp.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('Aviso obtenerConfiguracion: $e');
    }
    return null;
  }

  Future<void> guardarReporte(Reporte reporte) async {
    final map = reporte.toMap();
    map['id'] = reporte.id;
    await LocalDbService.saveList('db_reportes_v2', [map]);
    if (_supabase != null) {
      try {
        await _supabase!.from('reportes').upsert(map);
      } catch (e) {
        debugPrint('Error guardarReporte: $e');
      }
    }
  }

  Future<Reporte?> obtenerReporte(String id) async {
    try {
      if (_supabase != null) {
        final data = await _supabase!.from('reportes').select().eq('id', id).maybeSingle();
        if (data != null) {
          return Reporte.fromMap(Map<String, dynamic>.from(data), data['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('Aviso obtenerReporte: $e');
    }
    return null;
  }
}

// Alias para compatibilidad con código existente
typedef FirestoreService = SupabaseService;

