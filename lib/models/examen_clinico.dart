class ExamenClinico {
  final String id;
  final String pacienteId;
  final String pacienteNombre;
  final String titulo;
  final String tipo; // 'radiografia', 'pdf', 'imagen', 'otro'
  final String subtipo; // 'Panorámica', 'Periapical', 'Cefalométrica', 'Tomografía CBCT', 'Foto Intraoral', 'Estudio PDF', etc.
  final String zona; // 'General', 'Arcada Superior', 'Arcada Inferior', 'ATM Derecha', 'ATM Izquierda', etc.
  final DateTime fecha;
  final String observaciones;
  final String fileName;
  final String fileType; // 'pdf', 'image', 'other'
  final int fileSizeBytes;
  final String? fileBase64;
  final String? fileUrl;
  final DateTime createdAt;

  ExamenClinico({
    required this.id,
    required this.pacienteId,
    required this.pacienteNombre,
    required this.titulo,
    required this.tipo,
    required this.subtipo,
    required this.zona,
    required this.fecha,
    required this.observaciones,
    required this.fileName,
    required this.fileType,
    required this.fileSizeBytes,
    this.fileBase64,
    this.fileUrl,
    required this.createdAt,
  });

  bool get isPdf =>
      fileType.toLowerCase() == 'pdf' ||
      fileName.toLowerCase().endsWith('.pdf');

  bool get isImage =>
      fileType.toLowerCase() == 'image' ||
      tipo == 'radiografia' ||
      tipo == 'imagen' ||
      fileName.toLowerCase().endsWith('.jpg') ||
      fileName.toLowerCase().endsWith('.jpeg') ||
      fileName.toLowerCase().endsWith('.png') ||
      fileName.toLowerCase().endsWith('.webp');

  String get formattedSize {
    if (fileSizeBytes <= 0) return '0 KB';
    if (fileSizeBytes < 1024 * 1024) {
      final kb = (fileSizeBytes / 1024).toStringAsFixed(1);
      return '$kb KB';
    }
    final mb = (fileSizeBytes / (1024 * 1024)).toStringAsFixed(1);
    return '$mb MB';
  }

  String get tipoLabel {
    switch (tipo.toLowerCase()) {
      case 'radiografia':
        return 'Radiografía';
      case 'pdf':
        return 'Estudio PDF';
      case 'imagen':
        return 'Foto Clínica';
      default:
        return 'Examen / Estudio';
    }
  }

  factory ExamenClinico.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedFecha;
    final f = map['fecha'];
    if (f is DateTime) {
      parsedFecha = f;
    } else if (f is String) {
      parsedFecha = DateTime.tryParse(f) ?? DateTime.now();
    } else {
      parsedFecha = DateTime.now();
    }

    DateTime parsedCreated;
    final c = map['created_at'] ?? map['createdAt'];
    if (c is DateTime) {
      parsedCreated = c;
    } else if (c is String) {
      parsedCreated = DateTime.tryParse(c) ?? DateTime.now();
    } else {
      parsedCreated = DateTime.now();
    }

    final rawSize = map['file_size_bytes'] ?? map['fileSizeBytes'];
    int size = 0;
    if (rawSize is int) {
      size = rawSize;
    } else if (rawSize is num) {
      size = rawSize.toInt();
    } else if (rawSize is String) {
      size = int.tryParse(rawSize) ?? 0;
    }

    return ExamenClinico(
      id: documentId,
      pacienteId: map['paciente_id']?.toString() ?? map['pacienteId']?.toString() ?? '',
      pacienteNombre: map['paciente_nombre']?.toString() ?? map['pacienteNombre']?.toString() ?? '',
      titulo: map['titulo']?.toString() ?? 'Examen Clínico',
      tipo: map['tipo']?.toString() ?? 'radiografia',
      subtipo: map['subtipo']?.toString() ?? 'Panorámica',
      zona: map['zona']?.toString() ?? 'General',
      fecha: parsedFecha,
      observaciones: map['observaciones']?.toString() ?? '',
      fileName: map['file_name']?.toString() ?? map['fileName']?.toString() ?? 'archivo',
      fileType: map['file_type']?.toString() ?? map['fileType']?.toString() ?? 'image',
      fileSizeBytes: size,
      fileBase64: map['file_base64']?.toString() ?? map['fileBase64']?.toString(),
      fileUrl: map['file_url']?.toString() ?? map['fileUrl']?.toString(),
      createdAt: parsedCreated,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'paciente_id': pacienteId,
      'pacienteId': pacienteId,
      'paciente_nombre': pacienteNombre,
      'pacienteNombre': pacienteNombre,
      'titulo': titulo,
      'tipo': tipo,
      'subtipo': subtipo,
      'zona': zona,
      'fecha': fecha.toIso8601String().split('T')[0],
      'observaciones': observaciones,
      'file_name': fileName,
      'fileName': fileName,
      'file_type': fileType,
      'fileType': fileType,
      'file_size_bytes': fileSizeBytes,
      'fileSizeBytes': fileSizeBytes,
      if (fileBase64 != null) 'file_base64': fileBase64,
      if (fileBase64 != null) 'fileBase64': fileBase64,
      if (fileUrl != null) 'file_url': fileUrl,
      if (fileUrl != null) 'fileUrl': fileUrl,
      'created_at': createdAt.toIso8601String(),
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
