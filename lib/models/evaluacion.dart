class Evaluacion {
  final String id;
  final String pacienteId;
  final DateTime fecha;
  final String evaluador;
  final Map<String, dynamic> datos;

  Evaluacion({
    required this.id,
    required this.pacienteId,
    required this.fecha,
    required this.evaluador,
    required this.datos,
  });

  factory Evaluacion.fromMap(Map<String, dynamic> map, String documentId) {
    return Evaluacion(
      id: documentId,
      pacienteId: map['pacienteId'] ?? '',
      fecha: DateTime.parse(map['fecha'] ?? DateTime.now().toIso8601String()),
      evaluador: map['evaluador'] ?? '',
      datos: Map<String, dynamic>.from(map['datos'] ?? {}),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'pacienteId': pacienteId,
      'fecha': fecha.toIso8601String(),
      'evaluador': evaluador,
      'datos': datos,
    };
  }
}
