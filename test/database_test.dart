import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_de_fonseca/constants/supabase_constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Pruebas de Conexión a Base de Datos (Supabase)', () {
    late SupabaseClient client;

    setUpAll(() async {
      await Supabase.initialize(
        url: SupabaseConstants.supabaseUrl,
        anonKey: SupabaseConstants.supabaseAnonKey,
      );
      client = Supabase.instance.client;
    });

    test('1. Conexión y lectura de la tabla "users"', () async {
      final response = await client.from('users').select().limit(5);
      expect(response, isA<List>());
      print('✅ Supabase "users": ${response.length} registros encontrados.');
    });

    test('2. Conexión y lectura de la tabla "pacientes"', () async {
      final response = await client.from('pacientes').select().limit(5);
      expect(response, isA<List>());
      print('✅ Supabase "pacientes": ${response.length} registros encontrados.');
    });

    test('3. Conexión y lectura de la tabla "evaluaciones"', () async {
      final response = await client.from('evaluaciones').select().limit(5);
      expect(response, isA<List>());
      print('✅ Supabase "evaluaciones": ${response.length} registros encontrados.');
    });

    test('4. Conexión y lectura de la tabla "citas"', () async {
      final response = await client.from('citas').select().limit(5);
      expect(response, isA<List>());
      print('✅ Supabase "citas": ${response.length} registros encontrados.');
    });

    test('5. Operaciones Escritura / Lectura / Eliminación (CRUD Test)', () async {
      const testId = 'test_db_ping_123';
      
      // Upsert
      await client.from('configuracion').upsert({
        'id': testId,
        'tema': 'dark',
        'notificaciones': true,
      });

      // Select
      final data = await client.from('configuracion').select().eq('id', testId).maybeSingle();
      expect(data, isNotNull);
      expect(data!['id'], equals(testId));
      print('✅ Escritura y lectura en Supabase "configuracion" exitosas.');

      // Delete
      await client.from('configuracion').delete().eq('id', testId);
      final checkDelete = await client.from('configuracion').select().eq('id', testId).maybeSingle();
      expect(checkDelete, isNull);
      print('✅ Eliminación de registro de prueba en Supabase exitosa.');
    });
  });
}
