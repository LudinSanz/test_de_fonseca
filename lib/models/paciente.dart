class Paciente {
  final String id;
  final String nombre;
  final String apellido;
  final String email;
  final String telefono;
  final DateTime fechaNacimiento;
  final String genero;
  final String direccion;

  Paciente({
    required this.id,
    required this.nombre,
    required this.apellido,
    required this.email,
    required this.telefono,
    required this.fechaNacimiento,
    required this.genero,
    required this.direccion,
  });

  factory Paciente.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedDate;
    final fn = map['fechaNacimiento'] ?? map['fecha_nacimiento'];
    if (fn is DateTime) {
      parsedDate = fn;
    } else if (fn is String) {
      parsedDate = DateTime.tryParse(fn) ?? DateTime.now();
    } else {
      parsedDate = DateTime.now();
    }

    return Paciente(
      id: documentId,
      nombre: map['nombre'] ?? '',
      apellido: map['apellido'] ?? '',
      email: map['email'] ?? '',
      telefono: map['telefono'] ?? '',
      fechaNacimiento: parsedDate,
      genero: map['genero'] ?? '',
      direccion: map['direccion'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
      'fechaNacimiento': fechaNacimiento.toIso8601String(),
      'genero': genero,
      'direccion': direccion,
    };
  }
}
