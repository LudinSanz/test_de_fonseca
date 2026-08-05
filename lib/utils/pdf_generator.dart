import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/paciente.dart';

class PdfGenerator {
  // Carga segura del logo de Rizo Dental desde los assets
  static Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/rizo_logo.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  // -------------------------------------------------------------
  // 1. GENERAR PDF TEST DE FONSECA (ATM) - RIZO DENTAL SANCTUARY
  // -------------------------------------------------------------
  static Future<void> generarPdfFonseca({
    required Paciente paciente,
    required int score,
    required String diagnostico,
    required List<Map<String, dynamic>> preguntas,
    required Map<String, dynamic>? doctorInfo,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fechaStr = DateTime.now().toString().split(' ')[0];

    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');
    final textDark = PdfColor.fromHex('#191C1D');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header con Logo Rizo Dental y Título Editorial
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'RIZO DENTAL',
                            style: pw.TextStyle(
                              fontSize: 22,
                              fontWeight: pw.FontWeight.bold,
                              color: primaryColor,
                            ),
                          ),
                          pw.Text(
                            'The Clinical Sanctuary • Evaluación Anamnésica ATM',
                            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                          ),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FECHA DE EMISIÓN', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text(fechaStr, style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 16),

              // Ficha del Paciente Evaluado
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PACIENTE EVALUADO', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: textDark)),
                        pw.Text('Tel: ${paciente.telefono} • Email: ${paciente.email}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('DOCTOR EVALUADOR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(doctorInfo?['name'] ?? 'Dr. Especialista Rizo Dental', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Colegiado: #${doctorInfo?['colegiado'] ?? "14890"}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Tarjeta de Diagnóstico ATM
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PUNTUACIÓN ANAMNÉSICA DE FONSECA', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                        pw.Text('$score / 100 PUNTOS', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('DIAGNÓSTICO ATM', style: const pw.TextStyle(fontSize: 10, color: PdfColors.white)),
                        pw.Text(diagnostico, style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Desglose de Preguntas y Respuestas
              pw.Text('DESGLOSE DE CUESTIONARIO FONSECA', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 8),

              for (var i = 0; i < preguntas.length; i++)
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(vertical: 6, horizontal: 10),
                  margin: const pw.EdgeInsets.only(bottom: 4),
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 0 ? surfaceContainerLow : PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text('${i + 1}. ${preguntas[i]['question']}', style: const pw.TextStyle(fontSize: 10)),
                      ),
                      pw.Text(
                        preguntas[i]['answer'] ?? 'No respondido',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ),

              pw.Spacer(),

              // Pie de Página con Firma Digital
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FIRMA Y SELLO DE VALIDEZ DIGITAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text(doctorInfo?['firma_digital'] ?? 'Rizo Dental Sanctuary Digital Seal', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Text('Documento Clínico Oficial • Rizo Dental', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'evaluacion_fonseca_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 2. GENERAR PDF DE REPORTE DE CITA ODONTOLÓGICA
  // -------------------------------------------------------------
  static Future<void> generarPdfCita({
    required Paciente paciente,
    required String fechaHora,
    required String motivo,
    required String notas,
    required String estado,
    required Map<String, dynamic>? doctorInfo,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 48,
                          height: 48,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('The Clinical Sanctuary • Comprobante de Cita Odontológica', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Text('COMPROBANTE OFICIAL', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 20),

              // Datos del Paciente
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('INFORMACIÓN DEL PACIENTE', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 6),
                    pw.Text('${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Teléfono: ${paciente.telefono} • Email: ${paciente.email}', style: const pw.TextStyle(fontSize: 11)),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Detalles de la Cita
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: primaryColor, width: 1.5),
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DETALLES DE LA CITA PROGRAMADA', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 10),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Fecha y Hora:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(fechaHora, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Motivo de Consulta:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(motivo, style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.SizedBox(height: 6),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Estado:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text(estado, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                      ],
                    ),
                    if (notas.isNotEmpty) ...[
                      pw.SizedBox(height: 8),
                      pw.Text('Notas Adicionales: $notas', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 30),

              // Información de la Clínica
              pw.Text('UBICACIÓN Y ATENCIÓN CLÍNICA', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),
              pw.Text(doctorInfo?['direccion_clinica'] ?? 'Clínica Rizo Dental Sanctuary', style: const pw.TextStyle(fontSize: 11)),
              pw.Text('Atendido por: ${doctorInfo?['name'] ?? "Dr. Rizo Dental"} (${doctorInfo?['especialidad'] ?? "ATM & Odontología"})', style: const pw.TextStyle(fontSize: 11)),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Rizo Dental Sanctuary • Confirmación Oficial de Cita', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'cita_odontologica_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 3. GENERAR PDF DE RECETA MÉDICA ODONTOLÓGICA
  // -------------------------------------------------------------
  static Future<void> generarPdfReceta({
    required Paciente paciente,
    required List<Map<String, dynamic>> medicamentos,
    required String indicaciones,
    required Map<String, dynamic>? doctorInfo,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');
    final fechaStr = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header con Logo Rizo Dental
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 52,
                          height: 52,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('The Clinical Sanctuary • RECETA MÉDICA ODONTOLÓGICA', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('FECHA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text(fechaStr, style: const pw.TextStyle(fontSize: 11)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 16),

              // Datos del Doctor y Paciente
              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('PACIENTE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Tel: ${paciente.telefono}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('DOCTOR PRESCRIPTOR', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(doctorInfo?['name'] ?? 'Dr. Rizo Dental', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Colegiado: #${doctorInfo?['colegiado'] ?? "14890"}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 24),

              // Tabla de Medicamentos Prescritos
              pw.Text('MEDICAMENTOS PRESCRITOS', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 10),

              for (var m in medicamentos)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 10),
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 1),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        '• ${m['nombre']} (${m['dosis']})',
                        style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Tomar cada ${m['frecuencia_horas']} horas por un periodo de ${m['dias']} días.',
                        style: const pw.TextStyle(fontSize: 11),
                      ),
                      if (m['indicaciones'] != null && m['indicaciones'].toString().isNotEmpty)
                        pw.Text(
                          'Indicación específica: ${m['indicaciones']}',
                          style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800),
                        ),
                    ],
                  ),
                ),

              if (indicaciones.isNotEmpty) ...[
                pw.SizedBox(height: 16),
                pw.Text('INDICACIONES GENERALES DEL DOCTOR:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 4),
                pw.Text(indicaciones, style: const pw.TextStyle(fontSize: 11)),
              ],

              pw.Spacer(),

              // Firma Digital del Doctor
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FIRMA DIGITAL Y SELLO PROFESIONAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 4),
                      pw.Text(doctorInfo?['firma_digital'] ?? '${doctorInfo?['name']} - Colegiado #${doctorInfo?['colegiado']}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.Text('Rizo Dental Sanctuary • Receta Médica Oficial', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
                ],
              ),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'receta_medica_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }
}
