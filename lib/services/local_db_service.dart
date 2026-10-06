import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalDbService {
  static const String _keyPacientes = 'db_pacientes_v2';
  static const String _keyEvaluaciones = 'db_evaluaciones_v2';
  static const String _keyCitas = 'db_citas_v2';
  static const String _keyInventario = 'db_inventario_v2';
  static const String _keyRecetas = 'db_recetas_v2';
  static const String _keyUsers = 'db_users_v2';

  // Seed Data Initializers
  static final List<Map<String, dynamic>> _seedPacientes = [
    {
      'id': 'paciente_demo',
      'nombre': 'María Mercedes',
      'apellido': 'Morales',
      'email': 'mmorales@ejemplo.com',
      'telefono': '+502 5555 1234',
      'fecha_nacimiento': '1992-05-14',
      'fechaNacimiento': '1992-05-14',
      'genero': 'Femenino',
      'direccion': 'Ciudad de Guatemala, Zona 10',
    },
    {
      'id': 'paciente_002',
      'nombre': 'Juan Carlos',
      'apellido': 'Gómez Rivas',
      'email': 'jcgomez@ejemplo.com',
      'telefono': '+502 4444 8888',
      'fecha_nacimiento': '1988-11-20',
      'fechaNacimiento': '1988-11-20',
      'genero': 'Masculino',
      'direccion': 'Antigua Guatemala, Sacatepéquez',
    },
  ];

  static final List<Map<String, dynamic>> _seedEvaluaciones = [
    {
      'id': 'eval_demo_1',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'paciente_nombre': 'María Mercedes Morales',
      'fecha': DateTime.now().subtract(const Duration(days: 2)).toIso8601String(),
      'puntuacion': 12,
      'diagnostico': 'Disfunción Temporomandibular (ATM) Moderada',
      'respuestas': {
        'q1': 'Sí (2 pts)',
        'q2': 'A veces (1 pt)',
        'q3': 'Sí (2 pts)',
        'q4': 'A veces (1 pt)',
        'q5': 'No (0 pts)',
      },
    },
  ];

  static final List<Map<String, dynamic>> _seedCitas = [
    {
      'id': 'cita_demo_1',
      'paciente_id': 'paciente_demo',
      'paciente_nombre': 'María Mercedes Morales',
      'paciente_telefono': '+502 5555 1234',
      'fecha_hora': DateTime.now().add(const Duration(days: 3)).toIso8601String(),
      'fecha': '2026-10-10',
      'hora': '09:30 AM',
      'motivo': 'Control y Ajuste de Férula Miorrelajante',
      'estado': 'Programada',
      'notas': 'Paciente reporta mejoría en dolor matutino.',
    },
  ];

  static final List<Map<String, dynamic>> _seedInventario = [
    {
      'id': 'inv_01',
      'nombre': 'Férula Miorrelajante Tipo Michigan',
      'categoria': 'Instrumental',
      'cantidad': 15,
      'unidad': 'piezas',
      'stock_minimo': 5,
      'costo_unitario': 350.00,
    },
    {
      'id': 'inv_02',
      'nombre': 'Ibuprofeno 600mg (Caja x 30)',
      'categoria': 'Medicamentos',
      'cantidad': 24,
      'unidad': 'cajas',
      'stock_minimo': 10,
      'costo_unitario': 65.00,
    },
    {
      'id': 'inv_03',
      'nombre': 'Placas de Registro Articular',
      'categoria': 'Insumos / Materiales',
      'cantidad': 40,
      'unidad': 'paquetes',
      'stock_minimo': 8,
      'costo_unitario': 120.00,
    },
  ];

  static final List<Map<String, dynamic>> _seedRecetas = [
    {
      'id': 'receta_demo_1',
      'paciente_id': 'paciente_demo',
      'paciente_nombre': 'María Mercedes Morales',
      'doctor_nombre': 'Dr. Ludin Solis',
      'fecha': DateTime.now().toIso8601String().split('T')[0],
      'medicamentos': '1. Ibuprofeno 600mg - 1 tableta cada 8 horas por 5 días tras comidas.\n2. Relaxil - 1 tableta por la noche antes de dormir.',
      'indicaciones': 'Uso obligatorio de férula miorrelajante nocturna. Aplicar compresas de agua tibia en articulaciones temporomandibulares 15 min.',
      'indicaciones_generales': 'Evitar chicle, alimentos duros o tostados. Realizar fisioterapia de apertura suave.',
    },
  ];

  // Helper Methods to Read/Write Lists to SharedPreferences
  static Future<List<Map<String, dynamic>>> getList(String key, List<Map<String, dynamic>> defaultSeed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error leyendo local key $key: $e');
    }
    // Return seed data if empty and persist it
    await saveList(key, defaultSeed);
    return List<Map<String, dynamic>>.from(defaultSeed);
  }

  static Future<void> saveList(String key, List<Map<String, dynamic>> list) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, jsonEncode(list));
    } catch (e) {
      debugPrint('Error guardando local key $key: $e');
    }
  }

  // PACIENTES
  static Future<List<Map<String, dynamic>>> getPacientesMap() async {
    return await getList(_keyPacientes, _seedPacientes);
  }

  static Future<void> savePacientesMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyPacientes, list);
  }

  static Future<void> upsertPacienteMap(Map<String, dynamic> pacienteData) async {
    final list = await getPacientesMap();
    final String id = pacienteData['id']?.toString() ?? 'paciente_${DateTime.now().millisecondsSinceEpoch}';
    final index = list.indexWhere((p) => p['id'].toString() == id);
    if (index >= 0) {
      list[index] = pacienteData;
    } else {
      list.insert(0, pacienteData);
    }
    await savePacientesMap(list);
  }

  static Future<void> deletePacienteMap(String id) async {
    final list = await getPacientesMap();
    list.removeWhere((p) => p['id'].toString() == id);
    await savePacientesMap(list);
  }

  // EVALUACIONES
  static Future<List<Map<String, dynamic>>> getEvaluacionesMap() async {
    return await getList(_keyEvaluaciones, _seedEvaluaciones);
  }

  static Future<void> saveEvaluacionesMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyEvaluaciones, list);
  }

  static Future<void> upsertEvaluacionMap(Map<String, dynamic> evalData) async {
    final list = await getEvaluacionesMap();
    final String id = evalData['id']?.toString() ?? 'eval_${DateTime.now().millisecondsSinceEpoch}';
    final index = list.indexWhere((e) => e['id'].toString() == id);
    if (index >= 0) {
      list[index] = evalData;
    } else {
      list.insert(0, evalData);
    }
    await saveEvaluacionesMap(list);
  }

  // CITAS
  static Future<List<Map<String, dynamic>>> getCitasMap() async {
    return await getList(_keyCitas, _seedCitas);
  }

  static Future<void> saveCitasMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyCitas, list);
  }

  static Future<void> upsertCitaMap(Map<String, dynamic> citaData) async {
    final list = await getCitasMap();
    final String id = citaData['id']?.toString() ?? 'cita_${DateTime.now().millisecondsSinceEpoch}';
    final index = list.indexWhere((c) => c['id'].toString() == id);
    if (index >= 0) {
      list[index] = citaData;
    } else {
      list.insert(0, citaData);
    }
    await saveCitasMap(list);
  }

  static Future<void> deleteCitaMap(String id) async {
    final list = await getCitasMap();
    list.removeWhere((c) => c['id'].toString() == id);
    await saveCitasMap(list);
  }

  // INVENTARIO
  static Future<List<Map<String, dynamic>>> getInventarioMap() async {
    return await getList(_keyInventario, _seedInventario);
  }

  static Future<void> saveInventarioMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyInventario, list);
  }

  static Future<void> upsertInventarioMap(Map<String, dynamic> itemData) async {
    final list = await getInventarioMap();
    final String id = itemData['id']?.toString() ?? 'inv_${DateTime.now().millisecondsSinceEpoch}';
    final index = list.indexWhere((i) => i['id'].toString() == id);
    if (index >= 0) {
      list[index] = itemData;
    } else {
      list.insert(0, itemData);
    }
    await saveInventarioMap(list);
  }

  static Future<void> deleteInventarioMap(String id) async {
    final list = await getInventarioMap();
    list.removeWhere((i) => i['id'].toString() == id);
    await saveInventarioMap(list);
  }

  // RECETAS
  static Future<List<Map<String, dynamic>>> getRecetasMap() async {
    return await getList(_keyRecetas, _seedRecetas);
  }

  static Future<void> saveRecetasMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyRecetas, list);
  }

  static Future<void> upsertRecetaMap(Map<String, dynamic> recetaData) async {
    final list = await getRecetasMap();
    final String id = recetaData['id']?.toString() ?? 'receta_${DateTime.now().millisecondsSinceEpoch}';
    final index = list.indexWhere((r) => r['id'].toString() == id);
    if (index >= 0) {
      list[index] = recetaData;
    } else {
      list.insert(0, recetaData);
    }
    await saveRecetasMap(list);
  }

  static Future<void> deleteRecetaMap(String id) async {
    final list = await getRecetasMap();
    list.removeWhere((r) => r['id'].toString() == id);
    await saveRecetasMap(list);
  }

  // DOCTOR USER PROFILE
  static Future<Map<String, dynamic>?> getDoctorProfile(String idOrEmail) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (idOrEmail.isNotEmpty) {
        final String? jsonStr = prefs.getString('${_keyUsers}_$idOrEmail');
        if (jsonStr != null && jsonStr.isNotEmpty) {
          return Map<String, dynamic>.from(jsonDecode(jsonStr));
        }
      }
      final String? activeJsonStr = prefs.getString('${_keyUsers}_active_doctor');
      if (activeJsonStr != null && activeJsonStr.isNotEmpty) {
        return Map<String, dynamic>.from(jsonDecode(activeJsonStr));
      }
    } catch (e) {
      debugPrint('Error leyendo perfil doctor: $e');
    }
    return {
      'id': 'usr_doctor_demo',
      'name': 'Dr. Ludin Solis',
      'email': 'doctor@clinic.gt',
      'colegiado': 'COL-98421',
      'especialidad': 'Especialista en Disfunción ATM y Odontología Estética',
      'telefono': '+502 5981-6632',
      'direccion_clinica': 'Edificio Médico Plazuela, Nivel 5, Oficina 502',
    };
  }

  static Future<void> saveDoctorProfile(Map<String, dynamic> doctorData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String id = doctorData['id']?.toString() ?? 'usr_doctor_demo';
      final String email = doctorData['email']?.toString() ?? '';

      Map<String, dynamic> existing = {};
      if (email.isNotEmpty) {
        final ex = prefs.getString('${_keyUsers}_$email');
        if (ex != null && ex.isNotEmpty) existing = Map<String, dynamic>.from(jsonDecode(ex));
      }
      final mergedData = {...existing, ...doctorData};
      final String jsonStr = jsonEncode(mergedData);

      await prefs.setString('${_keyUsers}_$id', jsonStr);
      if (email.isNotEmpty) {
        await prefs.setString('${_keyUsers}_$email', jsonStr);
      }
      await prefs.setString('${_keyUsers}_active_doctor', jsonStr);
    } catch (e) {
      debugPrint('Error guardando perfil doctor: $e');
    }
  }
}
