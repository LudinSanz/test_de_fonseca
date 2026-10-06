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

  // ==================== HELPER UPSERTS ====================

  Future<void> _upsertPacienteMap(Map<String, dynamic> pacienteMap) async {
    if (_supabase == null) return;
    final String id = pacienteMap['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final String fnStr = (pacienteMap['fecha_nacimiento'] ?? pacienteMap['fechaNacimiento'] ?? '1990-01-01').toString().split('T')[0];

    try {
      await _supabase!.from('pacientes').upsert({
        'id': id,
        'nombre': pacienteMap['nombre'] ?? '',
        'apellido': pacienteMap['apellido'] ?? '',
        'email': pacienteMap['email'] ?? '',
        'telefono': pacienteMap['telefono'] ?? '',
        'fecha_nacimiento': fnStr,
        'genero': pacienteMap['genero'] ?? '',
        'direccion': pacienteMap['direccion'] ?? '',
      });
    } catch (e) {
      try {
        await _supabase!.from('pacientes').upsert({
          'id': id,
          'nombre': pacienteMap['nombre'] ?? '',
          'apellido': pacienteMap['apellido'] ?? '',
          'email': pacienteMap['email'] ?? '',
          'telefono': pacienteMap['telefono'] ?? '',
          'genero': pacienteMap['genero'] ?? '',
          'direccion': pacienteMap['direccion'] ?? '',
        });
      } catch (e2) {
        debugPrint('Error _upsertPacienteMap: $e2');
      }
    }
  }

  Future<void> _upsertCitaMap(Map<String, dynamic> citaData) async {
    if (_supabase == null) return;
    final String id = citaData['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final pacienteId = citaData['paciente_id'] ?? citaData['pacienteId'] ?? '';
    final pacienteNombre = citaData['paciente_nombre'] ?? citaData['pacienteNombre'] ?? '';
    final pacienteTel = citaData['paciente_telefono'] ?? citaData['pacienteTelefono'] ?? '';
    final fechaHora = citaData['fecha_hora'] ?? citaData['fechaHora'] ?? DateTime.now().toIso8601String();

    try {
      await _supabase!.from('citas').upsert({
        'id': id,
        'paciente_id': pacienteId,
        'paciente_nombre': pacienteNombre,
        'paciente_telefono': pacienteTel,
        'fecha_hora': fechaHora,
        'fecha': citaData['fecha'] ?? '',
        'hora': citaData['hora'] ?? '',
        'motivo': citaData['motivo'] ?? '',
        'notas': citaData['notas'] ?? '',
        'estado': citaData['estado'] ?? 'Programada',
      });
    } catch (e) {
      try {
        await _supabase!.from('citas').upsert({
          'id': id,
          'paciente_id': pacienteId,
          'fecha_hora': fechaHora,
          'motivo': citaData['motivo'] ?? '',
          'estado': citaData['estado'] ?? 'Programada',
        });
      } catch (e2) {
        debugPrint('Error _upsertCitaMap: $e2');
      }
    }
  }

  Future<void> _upsertEvaluacionMap(Map<String, dynamic> evalMap) async {
    if (_supabase == null) return;
    final String id = evalMap['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final pacienteId = evalMap['paciente_id'] ?? evalMap['pacienteId'] ?? '';
    final pacienteNombre = evalMap['paciente_nombre'] ?? evalMap['pacienteNombre'] ?? '';

    try {
      await _supabase!.from('evaluaciones').upsert({
        'id': id,
        'paciente_id': pacienteId,
        'paciente_nombre': pacienteNombre,
        'fecha': evalMap['fecha']?.toString() ?? DateTime.now().toIso8601String(),
        'puntuacion': evalMap['puntuacion'] ?? evalMap['score'] ?? 0,
        'diagnostico': evalMap['diagnostico'] ?? evalMap['diagnosis'] ?? '',
        'respuestas': evalMap['respuestas'] ?? evalMap['datos'] ?? {},
      });
    } catch (e) {
      try {
        await _supabase!.from('evaluaciones').upsert({
          'id': id,
          'paciente_id': pacienteId,
          'puntuacion': evalMap['puntuacion'] ?? evalMap['score'] ?? 0,
          'diagnostico': evalMap['diagnostico'] ?? evalMap['diagnosis'] ?? '',
        });
      } catch (e2) {
        debugPrint('Error _upsertEvaluacionMap: $e2');
      }
    }
  }

  Future<void> _upsertRecetaMap(Map<String, dynamic> recetaData) async {
    if (_supabase == null) return;
    final String id = recetaData['id']?.toString() ?? '';
    if (id.isEmpty) return;

    final pacienteId = recetaData['paciente_id'] ?? recetaData['pacienteId'] ?? '';
    final pacienteNombre = recetaData['paciente_nombre'] ?? recetaData['pacienteNombre'] ?? '';
    final doctorNombre = recetaData['doctor_nombre'] ?? recetaData['doctorNombre'] ?? '';

    try {
      await _supabase!.from('recetas').upsert({
        'id': id,
        'paciente_id': pacienteId,
        'paciente_nombre': pacienteNombre,
        'doctor_nombre': doctorNombre,
        'fecha': recetaData['fecha'] ?? DateTime.now().toIso8601String().split('T')[0],
        'medicamentos': recetaData['medicamentos'] ?? '',
        'indicaciones': recetaData['indicaciones'] ?? '',
        'indicaciones_generales': recetaData['indicaciones_generales'] ?? recetaData['indicacionesGenerales'] ?? '',
      });
    } catch (e) {
      try {
        await _supabase!.from('recetas').upsert({
          'id': id,
          'paciente_id': pacienteId,
          'medicamentos': recetaData['medicamentos'] ?? '',
          'indicaciones': recetaData['indicaciones'] ?? '',
        });
      } catch (e2) {
        debugPrint('Error _upsertRecetaMap: $e2');
      }
    }
  }

  Future<void> _upsertInventarioMap(Map<String, dynamic> itemData) async {
    if (_supabase == null) return;
    final String id = itemData['id']?.toString() ?? '';
    if (id.isEmpty) return;

    try {
      await _supabase!.from('inventario').upsert({
        'id': id,
        'nombre': itemData['nombre'] ?? '',
        'categoria': itemData['categoria'] ?? '',
        'cantidad': itemData['cantidad'] ?? 0,
        'unidad': itemData['unidad'] ?? '',
        'stock_minimo': itemData['stock_minimo'] ?? itemData['stockMinimo'] ?? 0,
        'costo_unitario': itemData['costo_unitario'] ?? itemData['costoUnitario'] ?? 0.0,
      });
    } catch (e) {
      debugPrint('Error _upsertInventarioMap: $e');
    }
  }

  Future<void> syncAllToSupabase() async {
    if (_supabase == null) return;
    try {
      final pacientes = await LocalDbService.getPacientesMap();
      for (var p in pacientes) {
        await _upsertPacienteMap(p);
      }
      final citas = await LocalDbService.getCitasMap();
      for (var c in citas) {
        await _upsertCitaMap(c);
      }
      final evaluaciones = await LocalDbService.getEvaluacionesMap();
      for (var e in evaluaciones) {
        await _upsertEvaluacionMap(e);
      }
      final recetas = await LocalDbService.getRecetasMap();
      for (var r in recetas) {
        await _upsertRecetaMap(r);
      }
      final inventario = await LocalDbService.getInventarioMap();
      for (var i in inventario) {
        await _upsertInventarioMap(i);
      }
    } catch (e) {
      debugPrint('Aviso en syncAllToSupabase: $e');
    }
  }

  // ==================== 1. PACIENTES ====================

  Future<List<Paciente>> obtenerPacientes() async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getPacientesMap();
    try {
      if (_supabase != null) {
        final response = await _supabase!.from('pacientes').select();
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
              final existing = mergedMap[id] ?? {};
              mergedMap[id] = {...existing, ...p};
            }
          }

          final mergedList = mergedMap.values.toList();
          await LocalDbService.savePacientesMap(mergedList);
          await syncAllToSupabase();

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
    await _upsertPacienteMap(pacienteMap);
    await syncAllToSupabase();
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
        final response = await _supabase!.from('evaluaciones').select();
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
          await syncAllToSupabase();

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
    await _upsertEvaluacionMap(evalMap);
    await syncAllToSupabase();
  }

  // ==================== 3. CITAS ====================

  Future<List<Map<String, dynamic>>> obtenerCitas({String? pacienteId}) async {
    final List<Map<String, dynamic>> localList = await LocalDbService.getCitasMap();
    try {
      if (_supabase != null) {
        final response = await _supabase!.from('citas').select();
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
          await syncAllToSupabase();

          if (pacienteId != null && pacienteId.isNotEmpty) {
            return mergedList.where((c) => c['paciente_id'] == pacienteId || c['pacienteId'] == pacienteId).toList();
          }
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerCitas (usando cache local): $e');
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((c) => c['paciente_id'] == pacienteId || c['pacienteId'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarCita(Map<String, dynamic> citaData) async {
    final String id = citaData['id']?.toString() ?? 'cita_${DateTime.now().millisecondsSinceEpoch}';
    citaData['id'] = id;
    await LocalDbService.upsertCitaMap(citaData);
    await _upsertCitaMap(citaData);
    await syncAllToSupabase();
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
        final response = await _supabase!.from('inventario').select();
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
          await syncAllToSupabase();
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
    await _upsertInventarioMap(itemData);
    await syncAllToSupabase();
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
        final response = await _supabase!.from('recetas').select();
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
          await syncAllToSupabase();

          if (pacienteId != null && pacienteId.isNotEmpty) {
            return mergedList.where((r) => r['paciente_id'] == pacienteId || r['pacienteId'] == pacienteId).toList();
          }
          return mergedList;
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerRecetas (usando cache local): $e');
    }

    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((r) => r['paciente_id'] == pacienteId || r['pacienteId'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarReceta(Map<String, dynamic> recetaData) async {
    final String id = recetaData['id']?.toString() ?? 'receta_${DateTime.now().millisecondsSinceEpoch}';
    recetaData['id'] = id;
    await LocalDbService.upsertRecetaMap(recetaData);
    await _upsertRecetaMap(recetaData);
    await syncAllToSupabase();
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
    final String emailOrId = doctorData['email'] ?? doctorData['id'] ?? '';
    Map<String, dynamic> mergedData = doctorData;
    if (emailOrId.isNotEmpty) {
      final existing = await LocalDbService.getDoctorProfile(emailOrId);
      if (existing != null && existing.isNotEmpty) {
        mergedData = {...existing, ...doctorData};
      }
    }

    await LocalDbService.saveDoctorProfile(mergedData);
    if (_supabase != null) {
      try {
        await _supabase!.from('users').upsert(mergedData);
      } catch (e1) {
        try {
          await _supabase!.from('users').upsert({
            'id': mergedData['id'] ?? emailOrId,
            'email': mergedData['email'] ?? '',
            'name': mergedData['name'] ?? mergedData['nombre'] ?? '',
          });
        } catch (e2) {
          debugPrint('Error en Supabase guardarPerfilDoctor: $e2');
        }
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
