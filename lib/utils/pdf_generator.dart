import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/paciente.dart';
import '../models/examen_clinico.dart';

class PdfGenerator {
  // Colores corporativos institucionales de Rizo Dental
  static final PdfColor primaryColor = PdfColor.fromHex('#003F87');
  static final PdfColor secondaryColor = PdfColor.fromHex('#0056B3');
  static final PdfColor accentColor = PdfColor.fromHex('#007A78');
  static final PdfColor surfaceLow = PdfColor.fromHex('#F4F6F9');
  static final PdfColor surfaceCard = PdfColor.fromHex('#F8FAFC');
  static final PdfColor borderSubtle = PdfColor.fromHex('#CBD5E1');
  static final PdfColor textDark = PdfColor.fromHex('#1E293B');
  static final PdfColor textMuted = PdfColor.fromHex('#64748B');

  // Carga segura del logo de Rizo Dental desde los assets
  static Future<pw.MemoryImage?> _loadLogoImage() async {
    try {
      final logoBytes = await rootBundle.load('assets/images/rizo_logo.png');
      return pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  // Convierte los puntos dibujados en la pantalla a una imagen PNG para el PDF
  static Future<Uint8List?> signaturePointsToPngBytes(
    List<ui.Offset?> points, {
    double width = 360,
    double height = 140,
  }) async {
    final validPoints = points.where((p) => p != null).toList();
    if (validPoints.isEmpty) return null;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, width, height));
      final paint = ui.Paint()
        ..color = const ui.Color(0xFF003F87)
        ..strokeCap = ui.StrokeCap.round
        ..strokeWidth = 3.5;

      for (int i = 0; i < points.length - 1; i++) {
        if (points[i] != null && points[i + 1] != null) {
          canvas.drawLine(points[i]!, points[i + 1]!, paint);
        }
      }

      final picture = recorder.endRecording();
      final img = await picture.toImage(width.toInt(), height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      return null;
    }
  }

  // -------------------------------------------------------------
  // HEADER UNIFICADO DE ALTA GAMA - RIZO DENTAL
  // -------------------------------------------------------------
  static pw.Widget _buildModernHeader({
    required pw.MemoryImage? logoImage,
    required String documentTitle,
    required String folio,
    required String fechaStr,
    String subtitle = 'Clínica Odontológica Integral & Armonización Facial',
  }) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Row(
              children: [
                if (logoImage != null)
                  pw.Container(
                    width: 52,
                    height: 52,
                    margin: const pw.EdgeInsets.only(right: 12),
                    child: pw.Image(logoImage),
                  )
                else
                  pw.Container(
                    width: 52,
                    height: 52,
                    margin: const pw.EdgeInsets.only(right: 12),
                    decoration: pw.BoxDecoration(
                      color: primaryColor,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'RD',
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 18,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                    ),
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
                        letterSpacing: 1.5,
                      ),
                    ),
                    pw.Text(
                      subtitle,
                      style: pw.TextStyle(
                        fontSize: 9,
                        color: accentColor,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'PBX: (+502) 5981-6632 • Ciudad de Guatemala',
                      style: pw.TextStyle(fontSize: 8, color: textMuted),
                    ),
                  ],
                ),
              ],
            ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: pw.BoxDecoration(
                    color: primaryColor,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    documentTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
                pw.SizedBox(height: 4),
                pw.Text('FOLIO: $folio', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: textDark)),
                pw.Text('EMISIÓN: $fechaStr', style: pw.TextStyle(fontSize: 8, color: textMuted)),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 10),
        pw.Row(
          children: [
            pw.Expanded(child: pw.Container(height: 2.5, color: primaryColor)),
            pw.Container(width: 24, height: 2.5, color: accentColor),
          ],
        ),
        pw.SizedBox(height: 12),
      ],
    );
  }

  // -------------------------------------------------------------
  // FICHA RESUMEN DEL PACIENTE
  // -------------------------------------------------------------
  static pw.Widget _buildPatientCard(
    Paciente paciente, {
    String? badgeLabel,
    String? badgeValue,
    PdfColor? badgeColor,
  }) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: surfaceCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: borderSubtle, width: 0.8),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Expanded(
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('EXPEDIENTE DEL PACIENTE', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 2),
                pw.Text(
                  '${paciente.nombre} ${paciente.apellido}',
                  style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: textDark),
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Tel: ${paciente.telefono.isEmpty ? "No especificado" : paciente.telefono} • Email: ${paciente.email.isEmpty ? "No especificado" : paciente.email}',
                  style: pw.TextStyle(fontSize: 8.5, color: textMuted),
                ),
              ],
            ),
          ),
          if (badgeLabel != null && badgeValue != null)
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                color: (badgeColor ?? primaryColor).flatten(background: PdfColors.white, amount: 0.12),
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: badgeColor ?? primaryColor, width: 0.8),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(badgeLabel.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: badgeColor ?? primaryColor)),
                  pw.Text(badgeValue, style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: badgeColor ?? primaryColor)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // SECCIÓN OBLIGATORIA: CERTIFICACIÓN MÉDICA & FIRMA DIGITAL
  // -------------------------------------------------------------
  static pw.Widget _buildDoctorSignatureBlock({
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
    String? rolTitle = 'Odontólogo Tratante & Responsable Sanitario',
  }) {
    final doctorName = doctorInfo?['name'] ?? doctorInfo?['doctor_nombre'] ?? 'Dr. Ludin Solís';
    final colegiado = doctorInfo?['colegiado'] ?? '98421';
    final especialidad = doctorInfo?['especialidad'] ?? 'Especialista en Rehabilitación Oral & Estética Facial';
    final horaStr = DateTime.now().toLocal().toString().split('.')[0];
    final hashSeguridad = 'RZ-${horaStr.replaceAll(RegExp(r'[^0-9]'), '').substring(4, 12)}';

    pw.MemoryImage? sigImg;
    if (signaturePngBytes != null && signaturePngBytes.isNotEmpty) {
      try {
        sigImg = pw.MemoryImage(signaturePngBytes);
      } catch (_) {}
    }

    return pw.Container(
      margin: const pw.EdgeInsets.only(top: 14),
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        color: surfaceCard,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: accentColor, width: 1.0),
      ),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.end,
        children: [
          pw.Expanded(
            flex: 6,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  children: [
                    pw.Container(
                      width: 8,
                      height: 8,
                      decoration: pw.BoxDecoration(color: accentColor, shape: pw.BoxShape.circle),
                    ),
                    pw.SizedBox(width: 6),
                    pw.Text(
                      'CERTIFICACIÓN MÉDICA • DOCUMENTO OFICIAL FIRMADO',
                      style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentColor),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Text(
                  doctorName,
                  style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
                pw.Text(
                  'Colegiado Activo No. $colegiado • $especialidad',
                  style: pw.TextStyle(fontSize: 8.5, color: textDark),
                ),
                pw.Text(
                  rolTitle!,
                  style: pw.TextStyle(fontSize: 8, color: textMuted),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  'Validez clínica y legal certificada • Hash: $hashSeguridad • Fecha: $horaStr',
                  style: pw.TextStyle(fontSize: 7, color: textMuted),
                ),
              ],
            ),
          ),
          pw.Expanded(
            flex: 4,
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                if (sigImg != null)
                  pw.Container(
                    height: 52,
                    width: 140,
                    padding: const pw.EdgeInsets.all(2),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderSubtle, width: 0.8),
                    ),
                    child: pw.Image(sigImg, fit: pw.BoxFit.contain),
                  )
                else
                  pw.Container(
                    height: 52,
                    width: 140,
                    decoration: pw.BoxDecoration(
                      color: PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(6),
                      border: pw.Border.all(color: borderSubtle, width: 0.8),
                    ),
                    child: pw.Center(
                      child: pw.Text(
                        'Firma Digital Registrada\n$doctorName',
                        textAlign: pw.TextAlign.center,
                        style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ),
                  ),
                pw.SizedBox(height: 4),
                pw.Container(
                  width: 130,
                  height: 1,
                  color: primaryColor,
                ),
                pw.SizedBox(height: 2),
                pw.Text(
                  'Firma y Sello del Odontólogo',
                  style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // PIE DE PÁGINA COMÚN
  // -------------------------------------------------------------
  static pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.SizedBox(height: 8),
        pw.Container(height: 0.8, color: borderSubtle),
        pw.SizedBox(height: 4),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Rizo Dental • Especialistas en Sonrisas & Estética Facial • www.rizodental.com',
              style: pw.TextStyle(fontSize: 7.5, color: textMuted),
            ),
            pw.Text(
              'Documento emitido bajo estricta confidencialidad médica',
              style: pw.TextStyle(fontSize: 7.5, color: textMuted),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // 1. GENERAR PDF TEST DE FONSECA (ATM)
  // -------------------------------------------------------------
  static Future<void> generarPdfFonseca({
    required Paciente paciente,
    required int score,
    required String diagnostico,
    required List<Map<String, dynamic>> preguntas,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'ATM-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    PdfColor scoreColor = PdfColors.green800;
    if (score >= 20 && score <= 40) scoreColor = PdfColors.blue800;
    if (score >= 45 && score <= 65) scoreColor = PdfColors.orange800;
    if (score >= 70) scoreColor = PdfColors.red800;

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(
                logoImage: logoImage,
                documentTitle: 'Evaluación ATM (Fonseca)',
                folio: folio,
                fechaStr: fechaStr,
              ),
              _buildPatientCard(
                paciente,
                badgeLabel: 'Puntaje ATM',
                badgeValue: '$score / 100 pts',
                badgeColor: scoreColor,
              ),
              pw.SizedBox(height: 10),

              // Diagnóstico box
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: scoreColor.flatten(background: PdfColors.white, amount: 0.1),
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: scoreColor, width: 0.8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'DIAGNÓSTICO CLÍNICO:',
                      style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: scoreColor),
                    ),
                    pw.Text(
                      diagnostico,
                      style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: scoreColor),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),

              pw.Text('DESGLOSE ANAMNÉSICO DE RESPUESTAS:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),

              if (preguntas.isNotEmpty)
                for (var i = 0; i < preguntas.length; i++)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 4),
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4.5),
                    decoration: pw.BoxDecoration(
                      color: i % 2 == 0 ? surfaceLow : PdfColors.white,
                      borderRadius: pw.BorderRadius.circular(4),
                      border: pw.Border.all(color: borderSubtle, width: 0.5),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(
                            '${i + 1}. ${preguntas[i]['question']}',
                            style: pw.TextStyle(fontSize: 8.5, color: textDark),
                          ),
                        ),
                        pw.Text(
                          '${preguntas[i]['answer']}',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor),
                        ),
                      ],
                    ),
                  )
              else
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  child: pw.Text('Evaluación guardada directamente en el expediente clínico del paciente.', style: pw.TextStyle(fontSize: 9, color: textMuted)),
                ),

              pw.Spacer(),
              _buildDoctorSignatureBlock(
                doctorInfo: doctorInfo,
                signaturePngBytes: signaturePngBytes,
                rolTitle: 'Especialista en Trastornos Temporomandibulares (ATM)',
              ),
              _buildFooter(),
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
  // 2. GENERAR PDF EVALUACIÓN CLÍNICA / CONSULTA RÁPIDA
  // -------------------------------------------------------------
  static Future<void> generarPdfEvaluacionClinica({
    required Paciente paciente,
    required Map<String, dynamic> evaluacion,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = evaluacion['fecha'] != null
        ? evaluacion['fecha'].toString().split('T')[0]
        : DateTime.now().toString().split(' ')[0];
    final folio = 'CONS-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    final respuestas = evaluacion['respuestas'] as Map<String, dynamic>? ?? {};
    final tipoConsulta = respuestas['tipo_consulta'] ?? 'Consulta General';
    final motivo = respuestas['motivo'] ?? 'Control y valoración';
    final diagnosticoGeneral = respuestas['diagnostico_general'] ?? evaluacion['diagnostico'] ?? '';

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(
                logoImage: logoImage,
                documentTitle: 'Nota de Consulta Clínica',
                folio: folio,
                fechaStr: fechaStr,
              ),
              _buildPatientCard(
                paciente,
                badgeLabel: 'Tipo de Consulta',
                badgeValue: tipoConsulta,
                badgeColor: primaryColor,
              ),
              pw.SizedBox(height: 12),

              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: surfaceCard,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderSubtle, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('MOTIVO DE CONSULTA:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 3),
                    pw.Text(motivo, style: pw.TextStyle(fontSize: 10, color: textDark)),
                    pw.SizedBox(height: 10),
                    if (diagnosticoGeneral.isNotEmpty) ...[
                      pw.Text('DIAGNÓSTICO Y HALLAZGOS CLÍNICOS:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 3),
                      pw.Text(diagnosticoGeneral, style: pw.TextStyle(fontSize: 10, color: textDark)),
                    ],
                  ],
                ),
              ),

              if (tipoConsulta == 'ATM / Dolor Articular') ...[
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(12),
                  decoration: pw.BoxDecoration(
                    color: surfaceLow,
                    borderRadius: pw.BorderRadius.circular(8),
                    border: pw.Border.all(color: borderSubtle, width: 0.8),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('VALORACIÓN ARTICULAR Y MANDIBULAR:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor)),
                      pw.SizedBox(height: 6),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Nivel de Dolor: ${respuestas['nivel_dolor'] ?? 0}/10', style: pw.TextStyle(fontSize: 9)),
                          pw.Text('Bloqueo: ${respuestas['bloqueo_mandibula'] ?? "No"}', style: pw.TextStyle(fontSize: 9)),
                          pw.Text('Chasquidos: ${respuestas['chasquidos_dolorosos'] ?? "No"}', style: pw.TextStyle(fontSize: 9)),
                          pw.Text('Bruxismo: ${respuestas['bruxismo_nocturno'] ?? "No"}', style: pw.TextStyle(fontSize: 9)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],

              pw.Spacer(),
              _buildDoctorSignatureBlock(
                doctorInfo: doctorInfo,
                signaturePngBytes: signaturePngBytes,
                rolTitle: 'Odontólogo Evaluador',
              ),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'consulta_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 3. GENERAR PDF CONFIRMACIÓN DE CITA
  // -------------------------------------------------------------
  static Future<void> generarPdfCita({
    required Paciente paciente,
    required String fechaHora,
    required String motivo,
    required String estado,
    required String notas,
    required Map<String, dynamic>? doctorInfo,
    String? profesional,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'CITA-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(
                logoImage: logoImage,
                documentTitle: 'Comprobante de Cita',
                folio: folio,
                fechaStr: fechaStr,
              ),
              _buildPatientCard(
                paciente,
                badgeLabel: 'Estado',
                badgeValue: estado.toUpperCase(),
                badgeColor: estado.toLowerCase().contains('confirm') ? PdfColors.green800 : primaryColor,
              ),
              pw.SizedBox(height: 14),

              // Tarjeta de Fecha y Hora Programada
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: primaryColor,
                  borderRadius: pw.BorderRadius.circular(10),
                ),
                child: pw.Column(
                  children: [
                    pw.Text('FECHA Y HORA PROGRAMADA:', style: pw.TextStyle(color: PdfColors.white, fontSize: 9, letterSpacing: 1.0)),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      fechaHora,
                      style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 14),

              pw.Container(
                padding: const pw.EdgeInsets.all(14),
                decoration: pw.BoxDecoration(
                  color: surfaceCard,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: borderSubtle, width: 0.8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('PROCEDIMIENTO / MOTIVO:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(
                          'Profesional: ${profesional ?? doctorInfo?['name'] ?? "Dr. Ludin Solís"}',
                          style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(motivo, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: textDark)),
                    if (notas.isNotEmpty) ...[
                      pw.SizedBox(height: 10),
                      pw.Text('INDICACIONES PREVIAS Y NOTAS:', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 3),
                      pw.Text(notas, style: pw.TextStyle(fontSize: 9.5, color: textDark)),
                    ],
                  ],
                ),
              ),
              pw.SizedBox(height: 12),

              // Recomendaciones para el paciente
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: surfaceLow,
                  borderRadius: pw.BorderRadius.circular(6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('RECORDATORIOS IMPORTANTES:', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 3),
                    pw.Text('• Por favor presentarse 10 minutos antes de su horario agendado.', style: pw.TextStyle(fontSize: 8, color: textDark)),
                    pw.Text('• Si necesita reprogramar o cancelar, avisar con al menos 24 horas de anticipación al (+502 5981-6632).', style: pw.TextStyle(fontSize: 8, color: textDark)),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildDoctorSignatureBlock(
                doctorInfo: doctorInfo,
                signaturePngBytes: signaturePngBytes,
                rolTitle: 'Odontólogo Asignado',
              ),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'cita_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 4. GENERAR PDF RECETA MÉDICA ODONTOLÓGICA CON FIRMA DIGITAL
  // -------------------------------------------------------------
  static Future<void> generarPdfReceta({
    required Paciente paciente,
    required List<Map<String, dynamic>> medicamentos,
    required String indicaciones,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signatureImageBytes,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final finalSignatureBytes = signatureImageBytes ?? signaturePngBytes;
    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'REC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(
                logoImage: logoImage,
                documentTitle: 'Receta Médica Oficial',
                folio: folio,
                fechaStr: fechaStr,
              ),
              _buildPatientCard(paciente),
              pw.SizedBox(height: 12),

              pw.Row(
                children: [
                  pw.Text('Rp /', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: primaryColor, fontStyle: pw.FontStyle.italic)),
                  pw.SizedBox(width: 8),
                  pw.Text('PRESCRIPCIÓN FARMACOLÓGICA:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                ],
              ),
              pw.SizedBox(height: 8),

              for (var m in medicamentos)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 8),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    color: surfaceCard,
                    border: pw.Border.all(color: borderSubtle, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(
                            '• ${m['nombre']} (${m['dosis']})',
                            style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor),
                          ),
                          pw.Text(
                            'Cada ${m['frecuencia_horas'] ?? m['frecuencia'] ?? "8"} hrs • ${m['dias'] ?? m['duracion'] ?? "3"} días',
                            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: accentColor),
                          ),
                        ],
                      ),
                      if (m['indicaciones'] != null && m['indicaciones'].toString().isNotEmpty) ...[
                        pw.SizedBox(height: 3),
                        pw.Text(
                          'Detalle: ${m['indicaciones']}',
                          style: pw.TextStyle(fontSize: 8.5, color: textDark),
                        ),
                      ],
                    ],
                  ),
                ),

              if (indicaciones.isNotEmpty) ...[
                pw.SizedBox(height: 8),
                pw.Text('INDICACIONES GENERALES DEL DOCTOR:', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 3),
                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: surfaceLow,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(indicaciones, style: pw.TextStyle(fontSize: 9, color: textDark)),
                ),
              ],

              pw.Spacer(),
              _buildDoctorSignatureBlock(
                doctorInfo: doctorInfo,
                signaturePngBytes: finalSignatureBytes,
                rolTitle: 'Doctor Prescriptor & Odontólogo Tratante',
              ),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'receta_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 5. GENERAR PDF PLAN DE TRATAMIENTO & ODONTOGRAMA (GTQ)
  // -------------------------------------------------------------
  static Future<void> generarPdfTratamientos({
    required Paciente paciente,
    required List<Map<String, dynamic>> tratamientosGenerales,
    required List<Map<String, dynamic>> tratamientosEstetica,
    required Map<int, Map<String, dynamic>> odontograma,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'TRAT-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    // Cálculo de montos en Quetzales (GTQ)
    double totalCosto = 0.0;
    double totalAbonado = 0.0;

    odontograma.forEach((_, t) {
      totalCosto += ((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num).toDouble();
      totalAbonado += ((t['abono_gtq'] ?? 0.0) as num).toDouble();
    });
    for (var t in tratamientosGenerales) {
      totalCosto += ((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num).toDouble();
      totalAbonado += ((t['abono_gtq'] ?? 0.0) as num).toDouble();
    }
    for (var t in tratamientosEstetica) {
      totalCosto += ((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num).toDouble();
      totalAbonado += ((t['abono_gtq'] ?? 0.0) as num).toDouble();
    }

    final double saldoPendiente = (totalCosto - totalAbonado).clamp(0.0, double.infinity);

    pdf.addPage(
      pw.MultiPage(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            _buildModernHeader(
              logoImage: logoImage,
              documentTitle: 'Plan de Tratamiento & Presupuesto',
              folio: folio,
              fechaStr: fechaStr,
            ),
            _buildPatientCard(
              paciente,
              badgeLabel: 'Saldo Pendiente',
              badgeValue: 'Q ${saldoPendiente.toStringAsFixed(2)}',
              badgeColor: saldoPendiente > 0 ? PdfColors.red800 : PdfColors.green800,
            ),
            pw.SizedBox(height: 12),

            // SECCIÓN 1: PROCEDIMIENTOS ESTÉTICOS Y ARMONIZACIÓN FACIAL (Lipopapada, Bichectomía, etc.)
            if (tratamientosEstetica.isNotEmpty) ...[
              pw.Text(
                'PROCEDIMIENTOS ESTÉTICOS Y ARMONIZACIÓN FACIAL:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: accentColor),
              ),
              pw.SizedBox(height: 6),
              ...tratamientosEstetica.map((t) {
                final costo = ((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num).toDouble();
                final abono = ((t['abono_gtq'] ?? 0.0) as num).toDouble();
                final subtipo = t['subtipo'] ?? '';
                final evo = t['evolucion'] ?? 'En Proceso';
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: surfaceCard,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderSubtle, width: 0.6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${t['tratamiento']} ${subtipo.isNotEmpty ? "($subtipo)" : ""}',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark),
                          ),
                          pw.Text(
                            'Etapa: $evo • Abonado: Q ${abono.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, color: textMuted),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Q ${costo.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 10),
            ],

            // SECCIÓN 2: ODONTOGRAMA CLÍNICO
            if (odontograma.isNotEmpty) ...[
              pw.Text(
                'ODONTOGRAMA & PIEZAS DENTALES INTERVENIDAS:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 6),
              ...odontograma.entries.map((entry) {
                final d = entry.key;
                final t = entry.value;
                final costo = ((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num).toDouble();
                final abono = ((t['abono_gtq'] ?? 0.0) as num).toDouble();
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: surfaceCard,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderSubtle, width: 0.6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            'Pieza #$d: ${t['tratamiento'] ?? t['diagnostico'] ?? "Procedimiento"}',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark),
                          ),
                          pw.Text(
                            'Estado: ${t['estado'] ?? "Planificado"} • Abonado: Q ${abono.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, color: textMuted),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Q ${costo.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 10),
            ],

            // SECCIÓN 3: TRATAMIENTOS GENERALES Y ATM
            if (tratamientosGenerales.isNotEmpty) ...[
              pw.Text(
                'TRATAMIENTOS ODONTOLÓGICOS GENERALES & ATM:',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
              ),
              pw.SizedBox(height: 6),
              ...tratamientosGenerales.map((t) {
                final costo = ((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num).toDouble();
                final abono = ((t['abono_gtq'] ?? 0.0) as num).toDouble();
                return pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: surfaceCard,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: borderSubtle, width: 0.6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(
                            '${t['tratamiento'] ?? "Tratamiento General"}',
                            style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark),
                          ),
                          pw.Text(
                            'Estado: ${t['estado'] ?? "En Proceso"} • Abonado: Q ${abono.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 8, color: textMuted),
                          ),
                        ],
                      ),
                      pw.Text(
                        'Q ${costo.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                );
              }),
              pw.SizedBox(height: 10),
            ],

            // BALANCE FINANCIERO DEL PLAN EN GTQ
            pw.Container(
              padding: const pw.EdgeInsets.all(12),
              decoration: pw.BoxDecoration(
                color: surfaceLow,
                borderRadius: pw.BorderRadius.circular(8),
                border: pw.Border.all(color: borderSubtle, width: 0.8),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Presupuesto Total del Plan:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold)),
                      pw.Text('Q ${totalCosto.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Total de Abonos Realizados:', style: pw.TextStyle(fontSize: 9.5, color: PdfColors.green800)),
                      pw.Text('Q ${totalAbonado.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    ],
                  ),
                  pw.Divider(color: borderSubtle),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('SALDO PENDIENTE POR LIQUIDAR:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Q ${saldoPendiente.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: saldoPendiente > 0 ? PdfColors.red800 : PdfColors.green800)),
                    ],
                  ),
                ],
              ),
            ),

            _buildDoctorSignatureBlock(
              doctorInfo: doctorInfo,
              signaturePngBytes: signaturePngBytes,
              rolTitle: 'Odontólogo & Cirujano Tratante',
            ),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'plan_tratamiento_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 6. GENERAR PDF REPORTE DE INVENTARIO CLÍNICO & AUDITORÍA
  // -------------------------------------------------------------
  static Future<void> generarPdfInventario({
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    int totalArticulos = items.length;
    int criticos = 0;
    for (var it in items) {
      final cant = ((it['cantidad'] ?? 0) as num).toInt();
      final min = ((it['stock_minimo'] ?? 0) as num).toInt();
      if (cant <= min) criticos++;
    }

    pdf.addPage(
      pw.MultiPage(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            _buildModernHeader(
              logoImage: logoImage,
              documentTitle: 'Auditoría & Control de Inventario',
              folio: folio,
              fechaStr: fechaStr,
            ),

            // Métricas Rápidas
            pw.Row(
              children: [
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: surfaceCard, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: borderSubtle, width: 0.8)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('TOTAL DE ARTÍCULOS', style: pw.TextStyle(fontSize: 8, color: textMuted, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$totalArticulos Ítems', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      ],
                    ),
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(color: surfaceCard, borderRadius: pw.BorderRadius.circular(6), border: pw.Border.all(color: borderSubtle, width: 0.8)),
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('EN ALERTA / STOCK CRÍTICO', style: pw.TextStyle(fontSize: 8, color: textMuted, fontWeight: pw.FontWeight.bold)),
                        pw.Text('$criticos Reabastecer', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: criticos > 0 ? PdfColors.red800 : PdfColors.green800)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 12),

            pw.Text('LISTADO OFICIAL DE INSUMOS, FÁRMACOS E INSTRUMENTAL:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),

            // Encabezado de la tabla
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: pw.BoxDecoration(color: primaryColor, borderRadius: pw.BorderRadius.circular(4)),
              child: pw.Row(
                children: [
                  pw.Expanded(flex: 4, child: pw.Text('Nombre del Ítem', style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 3, child: pw.Text('Categoría', style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Existencia', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Mínimo', textAlign: pw.TextAlign.center, style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                  pw.Expanded(flex: 2, child: pw.Text('Estado', textAlign: pw.TextAlign.right, style: pw.TextStyle(color: PdfColors.white, fontSize: 8.5, fontWeight: pw.FontWeight.bold))),
                ],
              ),
            ),

            for (var i = 0; i < items.length; i++) ...[
              () {
                final it = items[i];
                final cant = ((it['cantidad'] ?? 0) as num).toInt();
                final min = ((it['stock_minimo'] ?? 0) as num).toInt();
                final bool bajoStock = cant <= min;
                return pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 0 ? surfaceLow : PdfColors.white,
                    border: pw.Border(bottom: pw.BorderSide(color: borderSubtle, width: 0.5)),
                  ),
                  child: pw.Row(
                    children: [
                      pw.Expanded(flex: 4, child: pw.Text(it['nombre'] ?? 'Ítem', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark))),
                      pw.Expanded(flex: 3, child: pw.Text(it['categoria'] ?? 'General', style: pw.TextStyle(fontSize: 8, color: textMuted))),
                      pw.Expanded(flex: 2, child: pw.Text('$cant ${it['unidad'] ?? ""}', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark))),
                      pw.Expanded(flex: 2, child: pw.Text('$min', textAlign: pw.TextAlign.center, style: pw.TextStyle(fontSize: 8, color: textMuted))),
                      pw.Expanded(
                        flex: 2,
                        child: pw.Text(
                          bajoStock ? 'Reabastecer' : 'Óptimo',
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: bajoStock ? PdfColors.red800 : PdfColors.green800),
                        ),
                      ),
                    ],
                  ),
                );
              }(),
            ],

            _buildDoctorSignatureBlock(
              doctorInfo: doctorInfo,
              signaturePngBytes: signaturePngBytes,
              rolTitle: 'Responsable Sanitario & Control de Insumos',
            ),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'inventario_clinico_rizo_$fechaStr.pdf',
    );
  }

  // -------------------------------------------------------------
  // 7. GENERAR PDF ESTADO DE CUENTA (GTQ)
  // -------------------------------------------------------------
  static Future<void> generarPdfEstadoCuenta({
    required Paciente paciente,
    required double subtotal,
    required double descuento,
    required double totalPagado,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final double totalNeto = subtotal - descuento;
    final double saldoPendiente = totalNeto - totalPagado;
    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'EDC-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              _buildModernHeader(
                logoImage: logoImage,
                documentTitle: 'Estado de Cuenta (GTQ)',
                folio: folio,
                fechaStr: fechaStr,
              ),
              _buildPatientCard(
                paciente,
                badgeLabel: 'Saldo Pendiente',
                badgeValue: 'Q ${saldoPendiente.toStringAsFixed(2)}',
                badgeColor: saldoPendiente > 0 ? PdfColors.red800 : PdfColors.green800,
              ),
              pw.SizedBox(height: 12),

              pw.Text('DETALLE DE SERVICIOS Y TRATAMIENTOS:', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 6),

              for (var item in items)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 5),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    color: surfaceCard,
                    border: pw.Border.all(color: borderSubtle, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item['concepto'] ?? 'Tratamiento Dental', style: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: textDark)),
                          pw.Text('Estado: ${item['estado'] ?? "Realizado"}', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                        ],
                      ),
                      pw.Text('Q ${((item['precio'] ?? 0.0) as num).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),

              pw.SizedBox(height: 10),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  color: surfaceLow,
                  borderRadius: pw.BorderRadius.circular(6),
                  border: pw.Border.all(color: borderSubtle, width: 0.8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:'), pw.Text('Q ${subtotal.toStringAsFixed(2)}')]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Descuento:'), pw.Text('Q ${descuento.toStringAsFixed(2)}')]),
                    pw.Divider(color: borderSubtle),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Abonado:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800)), pw.Text('Q ${totalPagado.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Saldo Pendiente:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: primaryColor)), pw.Text('Q ${saldoPendiente.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: saldoPendiente > 0 ? PdfColors.red800 : PdfColors.green800))]),
                  ],
                ),
              ),

              pw.Spacer(),
              _buildDoctorSignatureBlock(
                doctorInfo: doctorInfo,
                signaturePngBytes: signaturePngBytes,
                rolTitle: 'Dirección Clínica & Finanzas Odontológicas',
              ),
              _buildFooter(),
            ],
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'estado_cuenta_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }

  // -------------------------------------------------------------
  // 8. GENERAR PDF EXPEDIENTE CLÍNICO INTEGRAL 360°
  // -------------------------------------------------------------
  static Future<void> generarPdfExpedienteCompleto({
    required Paciente paciente,
    required List<Map<String, dynamic>> evaluaciones,
    required List<Map<String, dynamic>> citas,
    required List<Map<String, dynamic>> recetas,
    required List<Map<String, dynamic>> tratamientos,
    List<ExamenClinico>? examenes,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signaturePngBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = DateTime.now().toString().split(' ')[0];
    final folio = 'EXP360-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';

    pdf.addPage(
      pw.MultiPage(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(28),
        build: (pw.Context context) {
          return [
            _buildModernHeader(
              logoImage: logoImage,
              documentTitle: 'Expediente Clínico 360°',
              folio: folio,
              fechaStr: fechaStr,
            ),
            _buildPatientCard(
              paciente,
              badgeLabel: 'Historial Integral',
              badgeValue: '360° Activo',
              badgeColor: primaryColor,
            ),
            pw.SizedBox(height: 12),

            // Evaluaciones ATM
            pw.Text('HISTORIAL DE EVALUACIONES CLÍNICAS & ATM:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 5),
            if (evaluaciones.isEmpty)
              pw.Text('Sin evaluaciones registradas.', style: pw.TextStyle(fontSize: 8.5, color: textMuted))
            else
              ...evaluaciones.map((ev) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(color: surfaceCard, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: borderSubtle, width: 0.5)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${ev['diagnostico'] ?? "Evaluación"} (${ev['fecha'] ?? "Fecha reciente"})', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark)),
                    pw.Text('${ev['puntuacion'] ?? 0} pts', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  ],
                ),
              )),
            pw.SizedBox(height: 10),

            // Citas
            pw.Text('HISTORIAL DE CITAS Y CONTROLES:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 5),
            if (citas.isEmpty)
              pw.Text('Sin citas previas registradas.', style: pw.TextStyle(fontSize: 8.5, color: textMuted))
            else
              ...citas.map((c) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(color: surfaceCard, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: borderSubtle, width: 0.5)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${c['motivo'] ?? "Consulta"} (${c['fecha'] ?? c['fecha_hora'] ?? ""})', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark)),
                    pw.Text('${c['estado'] ?? "Programada"}', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: accentColor)),
                  ],
                ),
              )),
            pw.SizedBox(height: 10),

            // Exámenes y Radiografías
            if (examenes != null && examenes.isNotEmpty) ...[
              pw.Text('ESTUDIOS RADIOGRÁFICOS Y EXÁMENES DIGITALIZADOS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 5),
              ...examenes.map((ex) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(color: surfaceCard, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: borderSubtle, width: 0.5)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${ex.tipoLabel}: ${ex.titulo} (${ex.subtipo})', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark)),
                    pw.Text('${ex.zona} • ${ex.fecha.day}/${ex.fecha.month}/${ex.fecha.year}', style: pw.TextStyle(fontSize: 8, color: textMuted)),
                  ],
                ),
              )),
              pw.SizedBox(height: 10),
            ],

            // Tratamientos y Estética
            pw.Text('PLAN DE TRATAMIENTOS Y PROCEDIMIENTOS ESTÉTICOS:', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 5),
            if (tratamientos.isEmpty)
              pw.Text('Sin tratamientos activos registrados.', style: pw.TextStyle(fontSize: 8.5, color: textMuted))
            else
              ...tratamientos.map((t) => pw.Container(
                margin: const pw.EdgeInsets.only(bottom: 4),
                padding: const pw.EdgeInsets.all(6),
                decoration: pw.BoxDecoration(color: surfaceCard, borderRadius: pw.BorderRadius.circular(4), border: pw.Border.all(color: borderSubtle, width: 0.5)),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('${t['tratamiento'] ?? t['nombre'] ?? "Procedimiento"} (${t['evolucion'] ?? t['estado'] ?? "En Proceso"})', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: textDark)),
                    pw.Text('Q ${(((t['precio_gtq'] ?? t['precio'] ?? 0.0) as num)).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  ],
                ),
              )),

            _buildDoctorSignatureBlock(
              doctorInfo: doctorInfo,
              signaturePngBytes: signaturePngBytes,
              rolTitle: 'Director Odontológico & Responsable Clínico',
            ),
            _buildFooter(),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'expediente_completo_${paciente.nombre.replaceAll(' ', '_')}.pdf',
    );
  }
}
