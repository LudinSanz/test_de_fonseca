class SupabaseConstants {
  // Permite configurar variables mediante --dart-define en CI/CD o entornos seguros
  // manteniendo compatibilidad con valores por defecto para asegurar 100% operatividad
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://eadmcexipsdytyjbwgis.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_9xS9DlltcsHSd7qGlnKDOg_-J_ziCMK',
  );
}

