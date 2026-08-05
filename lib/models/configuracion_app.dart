class ConfiguracionApp {
  final String id;
  final String version;
  final String mensajeBienvenida;
  final Map<String, dynamic> parametros;

  ConfiguracionApp({
    required this.id,
    required this.version,
    required this.mensajeBienvenida,
    required this.parametros,
  });

  factory ConfiguracionApp.fromMap(Map<String, dynamic> map, String documentId) {
    return ConfiguracionApp(
      id: documentId,
      version: map['version'] ?? '',
      mensajeBienvenida: map['mensajeBienvenida'] ?? '',
      parametros: Map<String, dynamic>.from(map['parametros'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'version': version,
      'mensajeBienvenida': mensajeBienvenida,
      'parametros': parametros,
    };
  }
}
