import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paciente.dart';
import '../models/evaluacion.dart';
import '../models/configuracion_app.dart';
import '../models/reporte.dart';
import '../models/examen_clinico.dart';
import 'local_db_service.dart';

/// SupabaseService — NUBE ES LA FUENTE PRINCIPAL.
/// El local (SharedPreferences) es SOLO cache de lectura rapida.
/// Si Supabase falla al GUARDAR, se lanza excepcion para que la UI avise al usuario.
class SupabaseService {
  SupabaseClient? get _supabase {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  bool get isConnected => _supabase != null;

  // ==================== HELPERS ====================

  String _newId(String prefix) => '${prefix}_${DateTime.now().millisecondsSinceEpoch}';

  Future<void> _supabaseUpsert(String table, Map<String, dynamic> data) async {
    if (_supabase == null) {
      throw Exception('Sin conexion a Supabase. Verifica tu internet.');
    }
    try {
      await _supabase!.from(table).upsert(data);
    } catch (e) {
      debugPrint('Error Supabase upsert $table: $e');
      rethrow;
    }
  }

  Future<void> _supabaseDelete(String table, String id) async {
    if (_supabase == null) {
      throw Exception('Sin conexion a Supabase. Verifica tu internet.');
    }
    try {
      await _supabase!.from(table).delete().eq('id', id);
    } catch (e) {
      debugPrint('Error Supabase delete $table: $e');
      rethrow;
    }
  }

  // ==================== 1. PACIENTES ====================

  Future<List<Paciente>> obtenerPacientes() async {
    try {
      if (_supabase != null) {
        final response = await _supabase!.from('pacientes').select().order('nombre');
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        await LocalDbService.savePacientesMap(remoteList);
        return remoteList.map((p) => Paciente.fromMap(p, p['id'].toString())).toList();
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerPacientes (usando cache): $e');
    }
    final localList = await LocalDbService.getPacientesMapNoSeed();
    return localList.map((p) => Paciente.fromMap(p, p['id'].toString())).toList();
  }

  Future<Paciente?> obtenerPaciente(String id) async {
    try {
      if (_supabase != null) {
        final data = await _supabase!.from('pacientes').select().eq('id', id).maybeSingle();
        if (data != null) {
          final map = Map<String, dynamic>.from(data);
          await LocalDbService.upsertPacienteMap(map);
          return Paciente.fromMap(map, map['id'].toString());
        }
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerPaciente (usando cache): $e');
    }
    final localList = await LocalDbService.getPacientesMapNoSeed();
    final found = localList.firstWhere((p) => p['id'].toString() == id, orElse: () => {});
    if (found.isNotEmpty) return Paciente.fromMap(found, found['id'].toString());
    return null;
  }

  Future<void> guardarPaciente(Paciente paciente) async {
    final Map<String, dynamic> map = paciente.toMap();
    if (map['id'] == null || map['id'].toString().isEmpty) {
      map['id'] = _newId('pac');
    }
    final String fnStr = (map['fecha_nacimiento'] ?? map['fechaNacimiento'] ?? '1990-01-01')
        .toString()
        .split('T')[0];

    await _supabaseUpsert('pacientes', {
      'id': map['id'],
      'nombre': map['nombre'] ?? '',
      'apellido': map['apellido'] ?? '',
      'email': map['email'] ?? '',
      'telefono': map['telefono'] ?? '',
      'fecha_nacimiento': fnStr,
      'genero': map['genero'] ?? '',
      'direccion': map['direccion'] ?? '',
    });

    await LocalDbService.upsertPacienteMap(map);
  }

  Future<void> eliminarPaciente(String id) async {
    await _supabaseDelete('pacientes', id);
    await LocalDbService.deletePacienteMap(id);
  }

  // ==================== 2. EVALUACIONES ====================

  Future<List<Map<String, dynamic>>> obtenerEvaluaciones({String? pacienteId}) async {
    try {
      if (_supabase != null) {
        var query = _supabase!.from('evaluaciones').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query.order('fecha', ascending: false);
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        if (pacienteId == null || pacienteId.isEmpty) {
          await LocalDbService.saveEvaluacionesMap(remoteList);
        } else {
          for (var item in remoteList) {
            await LocalDbService.upsertEvaluacionMap(item);
          }
        }
        return remoteList;
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerEvaluaciones (usando cache): $e');
    }
    final localList = await LocalDbService.getEvaluacionesMapNoSeed();
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
    final String id = (evalMap['id']?.toString() ?? '').isNotEmpty
        ? evalMap['id'].toString()
        : _newId('eval');
    evalMap['id'] = id;

    await _supabaseUpsert('evaluaciones', {
      'id': id,
      'paciente_id': evalMap['paciente_id'] ?? evalMap['pacienteId'] ?? '',
      'paciente_nombre': evalMap['paciente_nombre'] ?? evalMap['pacienteNombre'] ?? '',
      'fecha': evalMap['fecha']?.toString() ?? DateTime.now().toIso8601String(),
      'puntuacion': evalMap['puntuacion'] ?? evalMap['score'] ?? 0,
      'diagnostico': evalMap['diagnostico'] ?? evalMap['diagnosis'] ?? '',
      'respuestas': evalMap['respuestas'] ?? evalMap['datos'] ?? {},
    });

    await LocalDbService.upsertEvaluacionMap(evalMap);
  }

  // ==================== 3. CITAS ====================

  Future<List<Map<String, dynamic>>> obtenerCitas({String? pacienteId}) async {
    try {
      if (_supabase != null) {
        var query = _supabase!.from('citas').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query.order('fecha_hora', ascending: true);
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        if (pacienteId == null || pacienteId.isEmpty) {
          await LocalDbService.saveCitasMap(remoteList);
        } else {
          for (var item in remoteList) {
            await LocalDbService.upsertCitaMap(item);
          }
        }
        return remoteList;
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerCitas (usando cache): $e');
    }
    final localList = await LocalDbService.getCitasMapNoSeed();
    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((c) => c['paciente_id'] == pacienteId || c['pacienteId'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarCita(Map<String, dynamic> citaData) async {
    final String id = (citaData['id']?.toString() ?? '').isNotEmpty
        ? citaData['id'].toString()
        : _newId('cita');
    citaData['id'] = id;

    await _supabaseUpsert('citas', {
      'id': id,
      'paciente_id': citaData['paciente_id'] ?? citaData['pacienteId'] ?? '',
      'paciente_nombre': citaData['paciente_nombre'] ?? citaData['pacienteNombre'] ?? '',
      'paciente_telefono': citaData['paciente_telefono'] ?? citaData['pacienteTelefono'] ?? '',
      'fecha_hora': citaData['fecha_hora'] ?? citaData['fechaHora'] ?? DateTime.now().toIso8601String(),
      'fecha': citaData['fecha'] ?? '',
      'hora': citaData['hora'] ?? '',
      'motivo': citaData['motivo'] ?? '',
      'notas': citaData['notas'] ?? '',
      'estado': citaData['estado'] ?? 'Programada',
    });

    await LocalDbService.upsertCitaMap(citaData);
  }

  Future<void> eliminarCita(String id) async {
    await _supabaseDelete('citas', id);
    await LocalDbService.deleteCitaMap(id);
  }

  // ==================== 4. INVENTARIO ====================

  Future<List<Map<String, dynamic>>> obtenerInventario() async {
    try {
      if (_supabase != null) {
        final response = await _supabase!.from('inventario').select().order('nombre');
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        await LocalDbService.saveInventarioMap(remoteList);
        return remoteList;
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerInventario (usando cache): $e');
    }
    return await LocalDbService.getInventarioMapNoSeed();
  }

  Future<void> guardarItemInventario(Map<String, dynamic> itemData) async {
    final String id = (itemData['id']?.toString() ?? '').isNotEmpty
        ? itemData['id'].toString()
        : _newId('inv');
    itemData['id'] = id;

    await _supabaseUpsert('inventario', {
      'id': id,
      'nombre': itemData['nombre'] ?? '',
      'categoria': itemData['categoria'] ?? '',
      'cantidad': itemData['cantidad'] ?? 0,
      'unidad': itemData['unidad'] ?? '',
      'stock_minimo': itemData['stock_minimo'] ?? itemData['stockMinimo'] ?? 0,
      'costo_unitario': itemData['costo_unitario'] ?? itemData['costoUnitario'] ?? 0.0,
    });

    await LocalDbService.upsertInventarioMap(itemData);
  }

  Future<void> eliminarItemInventario(String id) async {
    await _supabaseDelete('inventario', id);
    await LocalDbService.deleteInventarioMap(id);
  }

  // ==================== 5. RECETAS ====================

  Future<List<Map<String, dynamic>>> obtenerRecetas({String? pacienteId}) async {
    try {
      if (_supabase != null) {
        var query = _supabase!.from('recetas').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query.order('fecha', ascending: false);
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        if (pacienteId == null || pacienteId.isEmpty) {
          await LocalDbService.saveRecetasMap(remoteList);
        } else {
          for (var item in remoteList) {
            await LocalDbService.upsertRecetaMap(item);
          }
        }
        return remoteList;
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerRecetas (usando cache): $e');
    }
    final localList = await LocalDbService.getRecetasMapNoSeed();
    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((r) => r['paciente_id'] == pacienteId || r['pacienteId'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> guardarReceta(Map<String, dynamic> recetaData) async {
    final String id = (recetaData['id']?.toString() ?? '').isNotEmpty
        ? recetaData['id'].toString()
        : _newId('receta');
    recetaData['id'] = id;

    await _supabaseUpsert('recetas', {
      'id': id,
      'paciente_id': recetaData['paciente_id'] ?? recetaData['pacienteId'] ?? '',
      'paciente_nombre': recetaData['paciente_nombre'] ?? recetaData['pacienteNombre'] ?? '',
      'doctor_nombre': recetaData['doctor_nombre'] ?? recetaData['doctorNombre'] ?? '',
      'fecha': recetaData['fecha'] ?? DateTime.now().toIso8601String().split('T')[0],
      'medicamentos': recetaData['medicamentos'] ?? '',
      'indicaciones': recetaData['indicaciones'] ?? '',
      'indicaciones_generales': recetaData['indicaciones_generales'] ?? recetaData['indicacionesGenerales'] ?? '',
    });

    await LocalDbService.upsertRecetaMap(recetaData);
  }

  // ==================== 5.5. TRATAMIENTOS ====================

  Future<List<Map<String, dynamic>>> obtenerTratamientos({String? pacienteId}) async {
    try {
      if (_supabase != null) {
        var query = _supabase!.from('tratamientos').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query;
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        if (pacienteId == null || pacienteId.isEmpty) {
          await LocalDbService.saveTratamientosMap(remoteList);
        } else {
          for (var item in remoteList) {
            await LocalDbService.upsertTratamientoMap(item);
          }
        }
        return remoteList;
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerTratamientos (usando cache): $e');
    }
    final localList = await LocalDbService.getTratamientosMapNoSeed();
    if (pacienteId != null && pacienteId.isNotEmpty) {
      return localList.where((t) => t['paciente_id'] == pacienteId || t['pacienteId'] == pacienteId).toList();
    }
    return localList;
  }

  Future<void> eliminarTratamiento(String id) async {
    try {
      if (_supabase != null) {
        await _supabase!.from('tratamientos').delete().eq('id', id);
      }
    } catch (e) {
      debugPrint('Aviso: no se pudo eliminar tratamiento en Supabase remoto. $e');
    }
    await LocalDbService.deleteTratamientoMap(id);
  }

  Future<void> guardarTratamiento(Map<String, dynamic> tratData) async {
    final String id = (tratData['id']?.toString() ?? '').isNotEmpty
        ? tratData['id'].toString()
        : _newId('trat');
    tratData['id'] = id;

    // Tratamos de guardar en Supabase (si la tabla existe, guardará; si no, fallará y guardará localmente)
    try {
      final remoteMap = <String, dynamic>{
        'id': id,
        'paciente_id': tratData['paciente_id'] ?? tratData['pacienteId'] ?? '',
        'diente': tratData['diente'] ?? 0,
        'diagnostico': tratData['diagnostico'] ?? '',
        'tratamiento': tratData['tratamiento'] ?? '',
        'evolucion': tratData['evolucion'] ?? '',
        'precio_gtq': tratData['precio_gtq'] ?? 0.0,
        'estado': tratData['estado'] ?? '',
        'notas': tratData['notas'] ?? '',
        'fecha': tratData['fecha'] ?? DateTime.now().toIso8601String(),
      };
      if (tratData.containsKey('categoria')) remoteMap['categoria'] = tratData['categoria'];
      if (tratData.containsKey('abono_gtq')) remoteMap['abono_gtq'] = tratData['abono_gtq'];
      await _supabaseUpsert('tratamientos', remoteMap);
    } catch (e) {
      debugPrint('Aviso: no se pudo guardar en Supabase remoto (tabla tratamientos no existe?). Guardando localmente. $e');
    }

    await LocalDbService.upsertTratamientoMap(tratData);
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
      debugPrint('Aviso Supabase obtenerPerfilDoctor (usando cache): $e');
    }
    return await LocalDbService.getDoctorProfile(idOrEmail);
  }

  Future<void> guardarPerfilDoctor(Map<String, dynamic> doctorData) async {
    await LocalDbService.saveDoctorProfile(doctorData);
    if (_supabase != null) {
      try {
        await _supabase!.from('users').upsert(doctorData);
      } catch (e) {
        debugPrint('Error Supabase guardarPerfilDoctor: $e');
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

  // ==================== 8. EXÁMENES & RADIOGRAFÍAS 360° ====================

  Future<List<ExamenClinico>> obtenerExamenes({String? pacienteId}) async {
    try {
      if (_supabase != null) {
        var query = _supabase!.from('examenes_clinicos').select();
        if (pacienteId != null && pacienteId.isNotEmpty) {
          query = query.eq('paciente_id', pacienteId);
        }
        final response = await query.order('fecha', ascending: false);
        final remoteList = (response as List).map((e) => Map<String, dynamic>.from(e)).toList();
        await LocalDbService.saveExamenesMap(remoteList);
        return remoteList.map((e) => ExamenClinico.fromMap(e, e['id'].toString())).toList();
      }
    } catch (e) {
      debugPrint('Aviso Supabase obtenerExamenes (usando cache local): $e');
    }
    final localList = await LocalDbService.getExamenesMap();
    final filtered = (pacienteId != null && pacienteId.isNotEmpty)
        ? localList.where((e) => (e['paciente_id'] == pacienteId || e['pacienteId'] == pacienteId)).toList()
        : localList;
    return filtered.map((e) => ExamenClinico.fromMap(e, e['id'].toString())).toList();
  }

  Future<void> guardarExamen(ExamenClinico examen) async {
    final Map<String, dynamic> map = examen.toMap();
    if (map['id'] == null || map['id'].toString().isEmpty) {
      map['id'] = _newId('exam');
    }

    await LocalDbService.upsertExamenMap(map);

    if (_supabase != null) {
      try {
        await _supabaseUpsert('examenes_clinicos', {
          'id': map['id'],
          'paciente_id': map['paciente_id'] ?? '',
          'paciente_nombre': map['paciente_nombre'] ?? '',
          'titulo': map['titulo'] ?? '',
          'tipo': map['tipo'] ?? '',
          'subtipo': map['subtipo'] ?? '',
          'zona': map['zona'] ?? '',
          'fecha': map['fecha'] ?? DateTime.now().toIso8601String().split('T')[0],
          'observaciones': map['observaciones'] ?? '',
          'file_name': map['file_name'] ?? '',
          'file_type': map['file_type'] ?? '',
          'file_size_bytes': map['file_size_bytes'] ?? 0,
          if (map['file_base64'] != null) 'file_base64': map['file_base64'],
          if (map['file_url'] != null) 'file_url': map['file_url'],
          'created_at': map['created_at'] ?? DateTime.now().toIso8601String(),
        });
      } catch (e) {
        debugPrint('Aviso Supabase guardarExamen en nube: $e');
      }
    }
  }

  Future<void> eliminarExamen(String id) async {
    await LocalDbService.deleteExamenMap(id);
    if (_supabase != null) {
      try {
        await _supabaseDelete('examenes_clinicos', id);
      } catch (e) {
        debugPrint('Aviso Supabase delete examen: $e');
      }
    }
  }

  // ==================== SYNC DE EMERGENCIA ====================

  Future<Map<String, int>> sincronizarCacheANube() async {
    if (_supabase == null) throw Exception('Sin conexion a Supabase');
    int syncedPacientes = 0, syncedCitas = 0, syncedEvals = 0, syncedRecetas = 0;

    final pacientes = await LocalDbService.getPacientesMapNoSeed();
    for (var p in pacientes) {
      try {
        final fnStr = (p['fecha_nacimiento'] ?? p['fechaNacimiento'] ?? '1990-01-01').toString().split('T')[0];
        await _supabase!.from('pacientes').upsert({
          'id': p['id'], 'nombre': p['nombre'] ?? '',
          'apellido': p['apellido'] ?? '', 'email': p['email'] ?? '',
          'telefono': p['telefono'] ?? '', 'fecha_nacimiento': fnStr,
          'genero': p['genero'] ?? '', 'direccion': p['direccion'] ?? '',
        });
        syncedPacientes++;
      } catch (e) { debugPrint('Error sync paciente ${p['id']}: $e'); }
    }

    final citas = await LocalDbService.getCitasMapNoSeed();
    for (var c in citas) {
      try {
        await _supabase!.from('citas').upsert({
          'id': c['id'], 'paciente_id': c['paciente_id'] ?? c['pacienteId'] ?? '',
          'paciente_nombre': c['paciente_nombre'] ?? '',
          'paciente_telefono': c['paciente_telefono'] ?? '',
          'fecha_hora': c['fecha_hora'] ?? c['fechaHora'] ?? DateTime.now().toIso8601String(),
          'fecha': c['fecha'] ?? '', 'hora': c['hora'] ?? '',
          'motivo': c['motivo'] ?? '', 'notas': c['notas'] ?? '',
          'estado': c['estado'] ?? 'Programada',
        });
        syncedCitas++;
      } catch (e) { debugPrint('Error sync cita ${c['id']}: $e'); }
    }

    final evals = await LocalDbService.getEvaluacionesMapNoSeed();
    for (var ev in evals) {
      try {
        await _supabase!.from('evaluaciones').upsert({
          'id': ev['id'], 'paciente_id': ev['paciente_id'] ?? ev['pacienteId'] ?? '',
          'paciente_nombre': ev['paciente_nombre'] ?? '',
          'fecha': ev['fecha']?.toString() ?? DateTime.now().toIso8601String(),
          'puntuacion': ev['puntuacion'] ?? 0,
          'diagnostico': ev['diagnostico'] ?? '',
          'respuestas': ev['respuestas'] ?? {},
        });
        syncedEvals++;
      } catch (e) { debugPrint('Error sync eval ${ev['id']}: $e'); }
    }

    final recetas = await LocalDbService.getRecetasMapNoSeed();
    for (var r in recetas) {
      try {
        await _supabase!.from('recetas').upsert({
          'id': r['id'], 'paciente_id': r['paciente_id'] ?? r['pacienteId'] ?? '',
          'paciente_nombre': r['paciente_nombre'] ?? '',
          'doctor_nombre': r['doctor_nombre'] ?? '',
          'fecha': r['fecha'] ?? DateTime.now().toIso8601String().split('T')[0],
          'medicamentos': r['medicamentos'] ?? '',
          'indicaciones': r['indicaciones'] ?? '',
          'indicaciones_generales': r['indicaciones_generales'] ?? '',
        });
        syncedRecetas++;
      } catch (e) { debugPrint('Error sync receta ${r['id']}: $e'); }
    }

    int syncedExamenes = 0;
    final examenes = await LocalDbService.getExamenesMapNoSeed();
    for (var ex in examenes) {
      try {
        await _supabase!.from('examenes_clinicos').upsert({
          'id': ex['id'],
          'paciente_id': ex['paciente_id'] ?? ex['pacienteId'] ?? '',
          'paciente_nombre': ex['paciente_nombre'] ?? ex['pacienteNombre'] ?? '',
          'titulo': ex['titulo'] ?? '',
          'tipo': ex['tipo'] ?? '',
          'subtipo': ex['subtipo'] ?? '',
          'zona': ex['zona'] ?? '',
          'fecha': ex['fecha'] ?? DateTime.now().toIso8601String().split('T')[0],
          'observaciones': ex['observaciones'] ?? '',
          'file_name': ex['file_name'] ?? ex['fileName'] ?? '',
          'file_type': ex['file_type'] ?? ex['fileType'] ?? '',
          'file_size_bytes': ex['file_size_bytes'] ?? ex['fileSizeBytes'] ?? 0,
          if (ex['file_base64'] != null) 'file_base64': ex['file_base64'],
          if (ex['file_url'] != null) 'file_url': ex['file_url'],
          'created_at': ex['created_at'] ?? ex['createdAt'] ?? DateTime.now().toIso8601String(),
        });
        syncedExamenes++;
      } catch (e) { debugPrint('Error sync examen ${ex['id']}: $e'); }
    }

    return {'pacientes': syncedPacientes, 'citas': syncedCitas, 'evaluaciones': syncedEvals, 'recetas': syncedRecetas, 'examenes': syncedExamenes};
  }
}

// Alias para compatibilidad con codigo existente
typedef FirestoreService = SupabaseService;