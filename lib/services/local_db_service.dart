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
  static const String _keyTratamientos = 'db_tratamientos_v2';
  static const String _keyExamenes = 'db_examenes_v2';

  // Seed Data Initializers
  static final List<Map<String, dynamic>> _seedPacientes = [
    {
      'id': 'pac_catarina_ramirez',
      'nombre': 'Catarina',
      'apellido': 'Ramirez',
      'email': 'catarina.ramirez@pacientes.rizo.gt',
      'telefono': '+502 5123 4567',
      'fecha_nacimiento': '1972-04-12',
      'fechaNacimiento': '1972-04-12',
      'genero': 'Femenino',
      'direccion': 'Ciudad de Guatemala (54 años)',
    },
    {
      'id': 'pac_josue_naz',
      'nombre': 'Josue David',
      'apellido': 'Naz Morales',
      'email': 'josue.naz@pacientes.rizo.gt',
      'telefono': '+502 5432 9876',
      'fecha_nacimiento': '1998-06-20',
      'fechaNacimiento': '1998-06-20',
      'genero': 'Masculino',
      'direccion': 'Guatemala (28 años)',
    },
    {
      'id': 'pac_maria_giron',
      'nombre': 'María',
      'apellido': 'Girón',
      'email': 'maria.giron@pacientes.rizo.gt',
      'telefono': '+502 4111 2233',
      'fecha_nacimiento': '1993-09-14',
      'fechaNacimiento': '1993-09-14',
      'genero': 'Femenino',
      'direccion': 'Mixco, Guatemala (33 años)',
    },
    {
      'id': 'pac_cesar_lopez',
      'nombre': 'Cesar Augusto',
      'apellido': 'López Rodríguez',
      'email': 'cesar.lopez@pacientes.rizo.gt',
      'telefono': '+502 5888 7766',
      'fecha_nacimiento': '1977-02-18',
      'fechaNacimiento': '1977-02-18',
      'genero': 'Masculino',
      'direccion': 'Zona 14, Ciudad de Guatemala (49 años)',
    },
    {
      'id': 'pac_adriana_lemus',
      'nombre': 'Adriana Guadalupe',
      'apellido': 'Lemus',
      'email': 'adriana.lemus@pacientes.rizo.gt',
      'telefono': '+502 4222 3344',
      'fecha_nacimiento': '2006-11-05',
      'fechaNacimiento': '2006-11-05',
      'genero': 'Femenino',
      'direccion': 'Carretera a El Salvador, Guatemala (20 años)',
    },
    {
      'id': 'pac_alfonso_rosales',
      'nombre': 'Alfonso Dorian',
      'apellido': 'Rosales Cisneros',
      'email': 'alfonso.rosales@pacientes.rizo.gt',
      'telefono': '+502 5999 8811',
      'fecha_nacimiento': '1953-05-10',
      'fechaNacimiento': '1953-05-10',
      'genero': 'Masculino',
      'direccion': 'Zona 1, Ciudad de Guatemala (DPI: 1983 58555 0101, 73 años)',
    },
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
      'id': 'eval_catarina_1',
      'paciente_id': 'pac_catarina_ramirez',
      'pacienteId': 'pac_catarina_ramirez',
      'paciente_nombre': 'Catarina Ramirez',
      'fecha': '2026-10-20',
      'puntuacion': 15,
      'diagnostico': 'Pérdida total de piezas dentales y reabsorción ósea grave. Desajuste de prótesis removible por pérdida ósea.',
      'respuestas': {
        'motivo': 'Pérdida total de piezas dentales y reabsorción ósea grave',
        'detalles': 'Desajuste de prótesis removible por pérdida ósea. Tratamiento: Colocación de implantes subperiósticos en ambas arcadas para colocación de prótesis provisional atornillada sobre implantes dentales.',
        'edad': '54 años',
      },
    },
    {
      'id': 'eval_josue_1',
      'paciente_id': 'pac_josue_naz',
      'pacienteId': 'pac_josue_naz',
      'paciente_nombre': 'Josue David Naz Morales',
      'fecha': '2026-10-21',
      'puntuacion': 10,
      'diagnostico': 'Pieza 31 con caries profunda no restaurable.',
      'respuestas': {
        'motivo': 'Caries profunda no restaurable en pieza 31',
        'detalles': 'Tratamiento: Se extrae quirúrgicamente pieza 31 y se rehabilita con colocación de implante dental en pieza 31 para restauración de pieza ausente. Requiere regeneración ósea y membrana de colágeno. Se rehabilita posteriormente con corona de zirconio atornillada sobre implante.',
        'edad': '28 años',
      },
    },
    {
      'id': 'eval_maria_1',
      'paciente_id': 'pac_maria_giron',
      'pacienteId': 'pac_maria_giron',
      'paciente_nombre': 'María Girón',
      'fecha': '2026-10-19',
      'puntuacion': 14,
      'diagnostico': 'Piezas 18, 19, 3 y 4 ausentes. Pérdida ósea',
      'respuestas': {
        'motivo': 'Piezas 18, 19, 3 y 4 ausentes. Pérdida ósea',
        'detalles': 'Tratamiento: Se colocan implantes dentales en piezas 18, 19, 3 y 4 para reposición de piezas dentales ausentes. Es necesario regeneración ósea y membrana en piezas 18 y 19. Se rehabilita con coronas de zirconio.',
        'edad': '33 años',
      },
    },
    {
      'id': 'eval_cesar_1',
      'paciente_id': 'pac_cesar_lopez',
      'pacienteId': 'pac_cesar_lopez',
      'paciente_nombre': 'Cesar Augusto López Rodríguez',
      'fecha': '2026-10-21',
      'puntuacion': 11,
      'diagnostico': 'Resto radicular de pieza 8 no restaurable.',
      'respuestas': {
        'motivo': 'Resto radicular de pieza 8 no restaurable',
        'detalles': 'Tratamiento: Extracción quirúrgica de resto radicular y colocación de implante dental para reponer pieza 8. Se realiza regeneración ósea y membrana de tejido conectivo para protección de injerto.',
        'edad': '49 años',
      },
    },
    {
      'id': 'eval_adriana_1',
      'paciente_id': 'pac_adriana_lemus',
      'pacienteId': 'pac_adriana_lemus',
      'paciente_nombre': 'Adriana Guadalupe Lemus',
      'fecha': '2026-10-18',
      'puntuacion': 18,
      'diagnostico': 'Ameloblastoma en cuerpo mandibular izquierdo.',
      'respuestas': {
        'motivo': 'Ameloblastoma en cuerpo mandibular izquierdo',
        'detalles': 'Tratamiento: Remoción quirúrgica de Ameloblastoma en cuerpo mandibular izquierdo, injerto microvascularizado de peroné para reconstrucción mandibular, colocación de placa de reconstrucción y posterior, colocación de implante dental subperióstico para rehabilitación y repoisción de piezas dentales ausentes.',
        'edad': '20 años',
      },
    },
    {
      'id': 'eval_alfonso_1',
      'paciente_id': 'pac_alfonso_rosales',
      'pacienteId': 'pac_alfonso_rosales',
      'paciente_nombre': 'Alfonso Dorian Rosales Cisneros',
      'fecha': '2026-10-21',
      'puntuacion': 16,
      'diagnostico': 'Quiste nasopalatino.',
      'respuestas': {
        'motivo': 'Quiste nasopalatino. DPI: 1983 58555 0101',
        'detalles': 'Tratamiento: Biopsia escisional para retiro de quiste nasopalatino en sala de operaciones, 24 hrs hospitalización, más estudio histopatológico.',
        'edad': '73 años',
        'dpi': '1983 58555 0101',
      },
    },
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

  static final List<Map<String, dynamic>> _seedExamenes = [
    {
      'id': 'exam_demo_1',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'paciente_nombre': 'María Mercedes Morales',
      'pacienteNombre': 'María Mercedes Morales',
      'titulo': 'Radiografía Panorámica Digital (Control ATM)',
      'tipo': 'radiografia',
      'subtipo': 'Panorámica',
      'zona': 'ATM y Maxilares',
      'fecha': '2026-10-08',
      'observaciones': 'Evaluación de cóndilos mandibulares y espacio articular. No se observan erosiones corticales severas en cóndilo derecho; leve aplanamiento en polo anterosuperior. Sin hallazgos periapicales agudos.',
      'file_name': 'panoramica_atm_control.jpg',
      'fileName': 'panoramica_atm_control.jpg',
      'file_type': 'image',
      'fileType': 'image',
      'file_size_bytes': 1420000,
      'fileSizeBytes': 1420000,
      'created_at': DateTime.now().subtract(const Duration(days: 4)).toIso8601String(),
    },
    {
      'id': 'exam_demo_2',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'paciente_nombre': 'María Mercedes Morales',
      'pacienteNombre': 'María Mercedes Morales',
      'titulo': 'Estudio Cefalométrico y Diagnóstico ATM',
      'tipo': 'pdf',
      'subtipo': 'Estudio PDF',
      'zona': 'Craneo-mandibular',
      'fecha': '2026-10-06',
      'observaciones': 'Informe cefalométrico digital. Ángulo ANB aumentado indicativo de Clase II esqueletal leve. Guía incisiva disminuida favorable para placa oclusal miorrelajante.',
      'file_name': 'informe_cefalometrico_rizo.pdf',
      'fileName': 'informe_cefalometrico_rizo.pdf',
      'file_type': 'pdf',
      'fileType': 'pdf',
      'file_size_bytes': 850000,
      'fileSizeBytes': 850000,
      'created_at': DateTime.now().subtract(const Duration(days: 6)).toIso8601String(),
    },
  ];

  static final List<Map<String, dynamic>> _seedTratamientos = [
    {
      'id': 'trat_catarina_1',
      'paciente_id': 'pac_catarina_ramirez',
      'pacienteId': 'pac_catarina_ramirez',
      'diente': 0,
      'categoria': 'cirugia_implantes',
      'tratamiento': 'Implantes Subperiósticos Bimaxilares + Prótesis Atornillada',
      'subtipo': 'Cirugía de Implantes Subperiósticos en Ambas Arcadas',
      'diagnostico': 'Pérdida total de piezas dentales y reabsorción ósea grave. Desajuste de prótesis removible por pérdida ósea.',
      'evolucion': 'Planificación Quirúrgica & Diseño 3D',
      'etapa_actual_index': 1,
      'etapas': [
        'Tomografía CBCT & Escaneo 3D',
        'Diseño y Manufactura de Malla Subperióstica',
        'Colocación Quirúrgica en Ambas Arcadas',
        'Colocación de Prótesis Provisional Atornillada',
        'Cicatrización y Osteointegración',
        'Rehabilitación Definitiva'
      ],
      'precio_gtq': 38000.0,
      'abono_gtq': 15000.0,
      'estado': 'En Proceso',
      'zona': 'Ambas arcadas (Maxilar Superior y Mandíbula)',
      'notas': 'Colocación de implantes subperiósticos en ambas arcadas para colocación de prótesis provisional atornillada sobre implantes dentales.',
      'fecha': '2026-10-20',
    },
    {
      'id': 'trat_josue_1',
      'paciente_id': 'pac_josue_naz',
      'pacienteId': 'pac_josue_naz',
      'diente': 31,
      'categoria': 'cirugia_implantes',
      'tratamiento': 'Extracción Quirúrgica Pza. 31 + Implante Dental + Regeneración Ósea',
      'subtipo': 'Implante Inmediato con Membrana de Colágeno',
      'diagnostico': 'Pieza 31 con caries profunda no restaurable.',
      'evolucion': 'Fase Quirúrgica Programada',
      'etapa_actual_index': 1,
      'etapas': [
        'Evaluación Clínica & Periapical',
        'Extracción Quirúrgica Pieza 31',
        'Colocación de Implante Dental Pza 31',
        'Regeneración Ósea y Membrana de Colágeno',
        'Periodo de Osteointegración',
        'Corona de Zirconio Atornillada sobre Implante'
      ],
      'precio_gtq': 6500.0,
      'abono_gtq': 3000.0,
      'estado': 'Programado',
      'zona': 'Pieza 31 (Incisivo Central Inferior Izquierdo)',
      'notas': 'Se extrae quirúrgicamente pieza 31 y se rehabilita con colocación de implante dental en pieza 31 para restauración de pieza ausente. Requiere regeneración ósea y membrana de colágeno. Se rehabilita posteriormente con corona de zirconio atornillada sobre implante.',
      'fecha': '2026-10-21',
    },
    {
      'id': 'trat_maria_1',
      'paciente_id': 'pac_maria_giron',
      'pacienteId': 'pac_maria_giron',
      'diente': 18,
      'categoria': 'cirugia_implantes',
      'tratamiento': 'Colocación de Implantes Dentales en Piezas 18, 19, 3 y 4',
      'subtipo': 'Implantes Múltiples con Regeneración y Membrana',
      'diagnostico': 'Piezas 18, 19, 3 y 4 ausentes. Pérdida ósea',
      'evolucion': 'Regeneración Ósea y Fase Quirúrgica',
      'etapa_actual_index': 1,
      'etapas': [
        'Estudio Tomográfico & Guía Quirúrgica',
        'Colocación de Implantes (Piezas 18, 19, 3 y 4)',
        'Regeneración Ósea y Membrana en Piezas 18 y 19',
        'Osteointegración Bimaxilar',
        'Toma de Impresiones Digitales',
        'Rehabilitación con Coronas de Zirconio'
      ],
      'precio_gtq': 24000.0,
      'abono_gtq': 8000.0,
      'estado': 'En Proceso',
      'zona': 'Piezas 18, 19, 3 y 4 (Sectores Posteriores)',
      'notas': 'Se colocan implantes dentales en piezas 18, 19, 3 y 4 para reposición de piezas dentales ausentes. Es necesario regeneración ósea y membrana en piezas 18 y 19. Se rehabilita con coronas de zirconio.',
      'fecha': '2026-10-19',
    },
    {
      'id': 'trat_cesar_1',
      'paciente_id': 'pac_cesar_lopez',
      'pacienteId': 'pac_cesar_lopez',
      'diente': 8,
      'categoria': 'cirugia_implantes',
      'tratamiento': 'Extracción Quirúrgica Resto Radicular Pza. 8 + Implante + Injerto Conectivo',
      'subtipo': 'Implante Dental con Membrana de Tejido Conectivo',
      'diagnostico': 'Resto radicular de pieza 8 no restaurable.',
      'evolucion': 'Programación Quirúrgica',
      'etapa_actual_index': 1,
      'etapas': [
        'Valoración Estética Anterior y CBCT',
        'Extracción Quirúrgica de Resto Radicular Pza 8',
        'Colocación de Implante Dental Inmediato',
        'Regeneración Ósea + Membrana de Tejido Conectivo',
        'Provisionalización Inmediata',
        'Rehabilitación Definitiva Zirconio'
      ],
      'precio_gtq': 8500.0,
      'abono_gtq': 4000.0,
      'estado': 'Programado',
      'zona': 'Pieza 8 (Incisivo Central Superior Derecho)',
      'notas': 'Extracción quirúrgica de resto radicular y colocación de implante dental para reponer pieza 8. Se realiza regeneración ósea y membrana de tejido conectivo para protección de injerto.',
      'fecha': '2026-10-21',
    },
    {
      'id': 'trat_adriana_1',
      'paciente_id': 'pac_adriana_lemus',
      'pacienteId': 'pac_adriana_lemus',
      'diente': 0,
      'categoria': 'cirugia_maxilofacial',
      'tratamiento': 'Remoción de Ameloblastoma + Injerto de Peroné + Placa + Implante Subperióstico',
      'subtipo': 'Cirugía Maxilofacial Reconstructiva Microvascular',
      'diagnostico': 'Ameloblastoma en cuerpo mandibular izquierdo.',
      'evolucion': 'Planificación Hospitalaria & VSP 3D',
      'etapa_actual_index': 1,
      'etapas': [
        'Tomografía 3D y Angiografía Peroné',
        'Planificación Virtual Quirúrgica (VSP)',
        'Remoción Quirúrgica de Ameloblastoma',
        'Injerto Microvascularizado de Peroné',
        'Colocación de Placa de Reconstrucción Mandibular',
        'Colocación de Implante Dental Subperióstico',
        'Rehabilitación y Reposición de Piezas Ausentes'
      ],
      'precio_gtq': 75000.0,
      'abono_gtq': 30000.0,
      'estado': 'En Proceso',
      'zona': 'Cuerpo Mandibular Izquierdo',
      'notas': 'Remoción quirúrgica de Ameloblastoma en cuerpo mandibular izquierdo, injerto microvascularizado de peroné para reconstrucción mandibular, colocación de placa de reconstrucción y posterior, colocación de implante dental subperióstico para rehabilitación y repoisción de piezas dentales ausentes.',
      'fecha': '2026-10-18',
    },
    {
      'id': 'trat_alfonso_1',
      'paciente_id': 'pac_alfonso_rosales',
      'pacienteId': 'pac_alfonso_rosales',
      'diente': 0,
      'categoria': 'cirugia_maxilofacial',
      'tratamiento': 'Biopsia Escisional de Quiste Nasopalatino en Quirófano + Estudio Histopatológico',
      'subtipo': 'Cirugía Hospitalaria y Enucleación de Quiste',
      'diagnostico': 'Quiste nasopalatino.',
      'evolucion': 'Programación en Sala de Operaciones',
      'etapa_actual_index': 1,
      'etapas': [
        'Estudio Tomográfico CBCT Palatino',
        'Evaluación Preanestésica & Laboratorios',
        'Biopsia Escisional en Sala de Operaciones',
        'Hospitalización Postoperatoria (24 horas)',
        'Estudio Histopatológico de Tejido',
        'Control y Retiro de Suturas (8 días)',
        'Alta y Seguimiento Oclusal'
      ],
      'precio_gtq': 14500.0,
      'abono_gtq': 5000.0,
      'estado': 'Programado',
      'zona': 'Conducto Nasopalatino / Paladar Anterior',
      'notas': 'DPI: 1983 58555 0101. Biopsia escisional para retiro de quiste nasopalatino en sala de operaciones, 24 hrs hospitalización, más estudio histopatológico.',
      'fecha': '2026-10-21',
    },
    {
      'id': 'trat_demo_1',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'diente': 0,
      'categoria': 'estetica_facial',
      'tratamiento': 'Lipopapada Enzimática',
      'subtipo': 'Enzimas Recombinantes PB Serum',
      'diagnostico': 'Adiposidad submentoniana localizada moderada con pérdida de definición del ángulo cérvico-mandibular.',
      'evolucion': 'Sesión 1',
      'etapa_actual_index': 3,
      'etapas': [
        'Valoración Facial & Marcaje',
        'Presupuesto',
        'Consentimiento Informado',
        'Sesión 1 (Aplicación)',
        'Control 15 días',
        'Sesión 2 (Refuerzo)',
        'Alta Definitiva'
      ],
      'precio_gtq': 1800.0,
      'abono_gtq': 1000.0,
      'estado': 'En Proceso',
      'zona': 'Submentón y reborde mandibular',
      'notas': 'Primera dosis aplicada con técnica retrotrazante en abanico. Indicada mentonera 12h/día, abundante hidratación.',
      'fecha': '2026-10-14',
    },
    {
      'id': 'trat_demo_2',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'diente': 0,
      'categoria': 'estetica_facial',
      'tratamiento': 'Bichectomía Quirúrgica Bilateral',
      'subtipo': 'Extracción de Bolsas de Bichat',
      'diagnostico': 'Hipertrofia de cojinetes adiposos de Bichat, asimetría leve del tercio inferior facial.',
      'evolucion': 'Consentimiento Quirúrgico',
      'etapa_actual_index': 2,
      'etapas': [
        'Valoración & Fotografía',
        'Presupuesto & Preoperatorios',
        'Consentimiento Quirúrgico',
        'Cirugía Ambulatoria',
        'Control 48 Horas',
        'Retiro de Puntos (7 días)',
        'Alta & Control 30 días'
      ],
      'precio_gtq': 3500.0,
      'abono_gtq': 1500.0,
      'estado': 'Pendiente',
      'zona': 'Bolsas de Bichat bilaterales',
      'notas': 'Exámenes preoperatorios aprobados (Tiempos de coagulación y hemograma normales). Consentimiento entregado.',
      'fecha': '2026-10-12',
    },
    {
      'id': 'trat_demo_3',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'diente': 0,
      'categoria': 'atm',
      'tratamiento': 'Férula Oclusal Miorrelajante Tipo Michigan',
      'subtipo': 'Dispositivo Oclusal Acrílico',
      'diagnostico': 'Bruxismo céntrico y sobrecarga articular témporomandibular moderada.',
      'evolucion': 'En Proceso',
      'etapa_actual_index': 2,
      'etapas': [
        'Evaluación Fonseca',
        'Toma de Impresiones',
        'Entrega y Ajuste Oclusal',
        'Control 15 días',
        'Control 3 meses'
      ],
      'precio_gtq': 1200.0,
      'abono_gtq': 1200.0,
      'estado': 'En Proceso',
      'zona': 'Arcada Superior',
      'notas': 'Férula acrílica rígida entregada. Contactos oclusales balanceados y guías caninas verificadas.',
      'fecha': '2026-10-08',
    },
    {
      'id': 'trat_demo_4',
      'paciente_id': 'paciente_demo',
      'pacienteId': 'paciente_demo',
      'diente': 16,
      'categoria': 'odontologia',
      'tratamiento': 'Resina',
      'subtipo': 'Restauración Estética Fotocurable',
      'diagnostico': 'Caries de esmalte y dentina en fosa oclusal de primer molar superior derecho.',
      'evolucion': 'Terminado',
      'etapa_actual_index': 3,
      'etapas': [
        'Evaluación',
        'Presupuesto',
        'Preparación Cavitaria',
        'Restauración y Pulido'
      ],
      'precio_gtq': 350.0,
      'abono_gtq': 350.0,
      'estado': 'Tratado',
      'zona': 'Pieza 16 - Cara Oclusal',
      'notas': 'Aislamiento relativo, grabado ácido, adhesivo universal y resina nanohíbrida color A2. Oclusión verificada.',
      'fecha': '2026-10-05',
    },
  ];

  // Helper Methods to Read/Write Lists to SharedPreferences
  static Future<List<Map<String, dynamic>>> getList(String key, List<Map<String, dynamic>> defaultSeed) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        final list = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        bool updated = false;
        for (var seed in defaultSeed) {
          final sId = seed['id']?.toString();
          if (sId != null && !list.any((item) => item['id']?.toString() == sId)) {
            list.add(Map<String, dynamic>.from(seed));
            updated = true;
          }
        }
        if (updated) {
          await saveList(key, list);
        }
        return list;
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

  static Future<void> clearActiveDoctorSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('${_keyUsers}_active_doctor');
    } catch (e) {
      debugPrint('Error al limpiar sesión activa de doctor: $e');
    }
  }

  // ==================== NO-SEED VARIANTS ====================
  // Retorna datos reales del cache SIN incluir datos demo/seed.

  static Future<List<Map<String, dynamic>>> getPacientesMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyPacientes);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        final list = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Error leyendo pacientes NoSeed: $e');
    }
    return await getPacientesMap();
  }

  static Future<List<Map<String, dynamic>>> getEvaluacionesMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyEvaluaciones);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        final list = decoded.map((item) => Map<String, dynamic>.from(item)).toList();
        if (list.isNotEmpty) return list;
      }
    } catch (e) {
      debugPrint('Error leyendo evaluaciones NoSeed: $e');
    }
    return await getEvaluacionesMap();
  }

  static Future<List<Map<String, dynamic>>> getCitasMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyCitas);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error leyendo citas NoSeed: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getInventarioMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyInventario);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error leyendo inventario NoSeed: $e');
    }
    return [];
  }

  static Future<List<Map<String, dynamic>>> getRecetasMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyRecetas);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error leyendo recetas NoSeed: $e');
    }
    return [];
  }

  // TRATAMIENTOS
  static Future<List<Map<String, dynamic>>> getTratamientosMap() async {
    return await getList(_keyTratamientos, _seedTratamientos);
  }

  static Future<List<Map<String, dynamic>>> getTratamientosMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyTratamientos);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error leyendo tratamientos NoSeed: $e');
    }
    return List<Map<String, dynamic>>.from(_seedTratamientos);
  }

  static Future<void> saveTratamientosMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyTratamientos, list);
  }

  static Future<void> deleteTratamientoMap(String id) async {
    final list = await getTratamientosMap();
    list.removeWhere((t) => t['id'] == id);
    await saveTratamientosMap(list);
  }

  static Future<void> upsertTratamientoMap(Map<String, dynamic> data) async {
    final list = await getTratamientosMap();
    final String id = data['id']?.toString() ?? 'trat_${DateTime.now().millisecondsSinceEpoch}';
    data['id'] = id;
    final index = list.indexWhere((t) => t['id'].toString() == id);
    if (index >= 0) {
      list[index] = data;
    } else {
      list.insert(0, data);
    }
    await saveTratamientosMap(list);
  }

  // ==================== EXÁMENES & RADIOGRAFÍAS 360° ====================
  static Future<List<Map<String, dynamic>>> getExamenesMap() async {
    return await getList(_keyExamenes, _seedExamenes);
  }

  static Future<List<Map<String, dynamic>>> getExamenesMapNoSeed() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_keyExamenes);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        final List decoded = jsonDecode(jsonStr);
        return decoded.map((item) => Map<String, dynamic>.from(item)).toList();
      }
    } catch (e) {
      debugPrint('Error leyendo exámenes NoSeed: $e');
    }
    return [];
  }

  static Future<void> saveExamenesMap(List<Map<String, dynamic>> list) async {
    await saveList(_keyExamenes, list);
  }

  static Future<void> deleteExamenMap(String id) async {
    final list = await getExamenesMap();
    list.removeWhere((e) => e['id'] == id);
    await saveExamenesMap(list);
  }

  static Future<void> upsertExamenMap(Map<String, dynamic> data) async {
    final list = await getExamenesMap();
    final String id = data['id']?.toString() ?? 'exam_${DateTime.now().millisecondsSinceEpoch}';
    data['id'] = id;
    final index = list.indexWhere((e) => e['id'].toString() == id);
    if (index >= 0) {
      list[index] = data;
    } else {
      list.insert(0, data);
    }
    await saveExamenesMap(list);
  }
}
