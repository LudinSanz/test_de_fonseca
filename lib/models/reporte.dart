class Reporte {
  final String id;
  final String pacienteId;
  final DateTime fecha;
  final String tipo;
  final String contenido;

  Reporte({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.tipo,
    required this.contenido,
  });

  factory Reporte.fromMap(Map<String, dynamic> map, String documentId) {
    return Reporte(
      id: documentId,
      pacienteId: map['pacienteId'] ?? '',
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      tipo: map['tipo'] ?? '',
      contenido: map['contenido'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pacienteId': pacienteId,
      'fecha': fecha.toIso8601String(),
      'tipo': tipo,
      'contenido': contenido,
    };
  }
}
