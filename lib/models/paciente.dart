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
    final fn = map['fecha_nacimiento'] ?? map['fechaNacimiento'];
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
    final String fechaStr = fechaNacimiento.toIso8601String().split('T')[0];
    return {
      'id': id,
      'nombre': nombre,
      'apellido': apellido,
      'email': email,
      'telefono': telefono,
      'fecha_nacimiento': fechaStr,
      'fechaNacimiento': fechaStr,
      'genero': genero,
      'direccion': direccion,
    };
  }
}
