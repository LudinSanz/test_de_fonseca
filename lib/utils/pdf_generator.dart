import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
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

  // Convierte los puntos dibujados en la pantalla a una imagen PNG para el PDF
  static Future<Uint8List?> signaturePointsToPngBytes(List<ui.Offset?> points, {double width = 300, double height = 120}) async {
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
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final fechaStr = DateTime.now().toString().split(' ')[0];
    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
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
                            'The Clinical Sanctuary • Evaluación Anamnésica ATM (Test de Fonseca)',
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
              pw.SizedBox(height: 14),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 14),

              // Ficha del Paciente Evaluado
              pw.Container(
                padding: const pw.EdgeInsets.all(14),
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
                        pw.Text('${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Teléfono: ${paciente.telefono} • Email: ${paciente.email}', style: const pw.TextStyle(fontSize: 9)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('PUNTUACIÓN FONSECA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('$score / 100 Puntos', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text(diagnostico, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),

              // Cuestionario de Preguntas y Respuestas
              pw.Text('DESGLOSE ANAMNÉSICO DE RESPUESTAS:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 8),

              for (var i = 0; i < preguntas.length; i++)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: i % 2 == 0 ? PdfColors.grey100 : PdfColors.white,
                    borderRadius: pw.BorderRadius.circular(6),
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(
                          '${i + 1}. ${preguntas[i]['pregunta']}',
                          style: const pw.TextStyle(fontSize: 9),
                        ),
                      ),
                      pw.Text(
                        '${preguntas[i]['respuesta']}',
                        style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor),
                      ),
                    ],
                  ),
                ),

              pw.Spacer(),
              pw.Container(height: 1, color: PdfColors.grey400),
              pw.SizedBox(height: 6),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Doctor tratante: ${doctorInfo?['name'] ?? "Dr. Ludin Solis"} (Colegiado #${doctorInfo?['colegiado'] ?? "98421"})', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.Text('Rizo Dental Sanctuary • Guatemala GTQ', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
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
  // 2. GENERAR PDF CONFIRMACIÓN DE CITA
  // -------------------------------------------------------------
  static Future<void> generarPdfCita({
    required Paciente paciente,
    required String fechaHora,
    required String motivo,
    required String estado,
    required String notas,
    required Map<String, dynamic>? doctorInfo,
    String? profesional,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
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
                          pw.Text('The Clinical Sanctuary • Confirmación Oficial de Cita', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 16),

              pw.Container(
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: pw.BorderRadius.circular(12),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('DETALLES DE LA CITA PROGRAMADA', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.SizedBox(height: 10),
                    pw.Text('Paciente: ${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Motivo / Servicio: $motivo', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Fecha y Hora: $fechaHora', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    pw.Text('Profesional Asignado: ${profesional ?? doctorInfo?['name'] ?? "Dr. Ludin Solis"}', style: const pw.TextStyle(fontSize: 11)),
                    pw.Text('Estado: $estado', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
                    if (notas.isNotEmpty) pw.Text('Notas: $notas', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Rizo Dental Sanctuary • Edificio Sixtino II, Zona 10, Guatemala (+502 5981-6632)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
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
  // 3. GENERAR PDF DE RECETA MÉDICA ODONTOLÓGICA CON FIRMA DIGITAL
  // -------------------------------------------------------------
  static Future<void> generarPdfReceta({
    required Paciente paciente,
    required List<Map<String, dynamic>> medicamentos,
    required String indicaciones,
    required Map<String, dynamic>? doctorInfo,
    Uint8List? signatureImageBytes,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');
    final fechaStr = DateTime.now().toString().split(' ')[0];

    pw.MemoryImage? signaturePwImage;
    if (signatureImageBytes != null && signatureImageBytes.isNotEmpty) {
      try {
        signaturePwImage = pw.MemoryImage(signatureImageBytes);
      } catch (_) {}
    }

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
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
                        pw.Text(doctorInfo?['name'] ?? 'Dr. Ludin Solis', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Colegiado: #${doctorInfo?['colegiado'] ?? "COL-98421"}', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 20),

              // Tabla de Medicamentos Prescritos
              pw.Text('MEDICAMENTOS PRESCRITOS:', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: primaryColor)),
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
                pw.SizedBox(height: 12),
                pw.Text('INDICACIONES GENERALES DEL DOCTOR:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                pw.SizedBox(height: 4),
                pw.Text(indicaciones, style: const pw.TextStyle(fontSize: 11)),
              ],

              pw.Spacer(),

              // FIRMA DIGITAL DEL DOCTOR E IMPRESIÓN DEL CANVAS
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('FIRMA DIGITAL Y SELLO PROFESIONAL', style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.SizedBox(height: 6),

                      // Si se proporciona la firma dibujada en pantalla, se incrusta la imagen PNG
                      if (signaturePwImage != null)
                        pw.Container(
                          height: 55,
                          width: 160,
                          padding: const pw.EdgeInsets.all(4),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Image(signaturePwImage, fit: pw.BoxFit.contain),
                        )
                      else
                        pw.Container(
                          padding: const pw.EdgeInsets.all(6),
                          decoration: pw.BoxDecoration(
                            border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
                            borderRadius: pw.BorderRadius.circular(6),
                          ),
                          child: pw.Text(
                            doctorInfo?['firma_digital'] ?? '${doctorInfo?['name']} - Colegiado #${doctorInfo?['colegiado']}',
                            style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                          ),
                        ),

                      pw.SizedBox(height: 4),
                      pw.Text('${doctorInfo?['name'] ?? "Dr. Ludin Solis"} • Colegiado #${doctorInfo?['colegiado'] ?? "COL-98421"}', style: const pw.TextStyle(fontSize: 9)),
                    ],
                  ),
                  pw.Text('Rizo Dental Sanctuary • Guatemala GTQ (+502 5981-6632)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
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

  // -------------------------------------------------------------
  // 4. GENERAR PDF ESTADO DE CUENTA Y PRESUPUESTO EN QUETZALES (GTQ / Q)
  // -------------------------------------------------------------
  static Future<void> generarPdfEstadoCuenta({
    required Paciente paciente,
    required double subtotal,
    required double descuento,
    required double totalPagado,
    required List<Map<String, dynamic>> items,
    required Map<String, dynamic>? doctorInfo,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');

    final double totalNeto = subtotal - descuento;
    final double saldoPendiente = totalNeto - totalPagado;
    final fechaStr = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.Page(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Row(
                    children: [
                      if (logoImage != null)
                        pw.Container(
                          width: 50,
                          height: 50,
                          margin: const pw.EdgeInsets.only(right: 12),
                          child: pw.Image(logoImage),
                        ),
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                          pw.Text('The Clinical Sanctuary • Estado de Cuenta & Presupuesto (GTQ)', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                        ],
                      ),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('MONEDA', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                      pw.Text('Quetzales (Q)', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Container(height: 2, color: primaryColor),
              pw.SizedBox(height: 14),

              pw.Container(
                padding: const pw.EdgeInsets.all(14),
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
                        pw.Text('${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                        pw.Text('Fecha de Emisión: $fechaStr', style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text('SALDO PENDIENTE', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('Q ${saldoPendiente.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 18),

              pw.Text('DETALLE DE TRATAMIENTOS Y SERVICIOS:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
              pw.SizedBox(height: 8),

              for (var item in items)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(8),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(item['concepto'] ?? 'Tratamiento Odontológico', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Estado: ${item['estado'] ?? "Pendiente"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text('Q ${(item['precio'] ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),

              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: surfaceContainerLow,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Subtotal:'), pw.Text('Q ${subtotal.toStringAsFixed(2)}')]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Descuento:'), pw.Text('Q ${descuento.toStringAsFixed(2)}')]),
                    pw.Divider(),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Total Pagado:'), pw.Text('Q ${totalPagado.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green800))]),
                    pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('Saldo Pendiente:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)), pw.Text('Q ${saldoPendiente.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.red800))]),
                  ],
                ),
              ),

              pw.Spacer(),
              pw.Divider(),
              pw.Center(
                child: pw.Text('Rizo Dental Sanctuary • Guatemala GTQ • Moneda Oficial Quetzales (Q)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
              ),
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
  // 5. GENERAR PDF EXPEDIENTE CLÍNICO COMPLETO (MASTER RIZO DENTAL)
  // -------------------------------------------------------------
  static Future<void> generarPdfExpedienteCompleto({
    required Paciente paciente,
    required List<Map<String, dynamic>> evaluaciones,
    required List<Map<String, dynamic>> citas,
    required List<Map<String, dynamic>> recetas,
    required List<Map<String, dynamic>> tratamientos,
    required Map<String, dynamic>? doctorInfo,
  }) async {
    final pdf = pw.Document();
    final logoImage = await _loadLogoImage();
    final fontRegular = await PdfGoogleFonts.robotoRegular();
    final fontBold = await PdfGoogleFonts.robotoBold();
    final pageTheme = pw.ThemeData.withFont(base: fontRegular, bold: fontBold);

    final primaryColor = PdfColor.fromHex('#003F87');
    final surfaceContainerLow = PdfColor.fromHex('#F3F4F5');
    final fechaStr = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.MultiPage(
        theme: pageTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header con Logo Rizo Dental
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Row(
                  children: [
                    if (logoImage != null)
                      pw.Container(
                        width: 50,
                        height: 50,
                        margin: const pw.EdgeInsets.only(right: 12),
                        child: pw.Image(logoImage),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                        pw.Text('Rizo Dental — EXPEDIENTE CLÍNICO COMPLETO', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
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
            pw.SizedBox(height: 12),
            pw.Container(height: 2, color: primaryColor),
            pw.SizedBox(height: 14),

            // Section 1: Datos del Paciente
            pw.Container(
              padding: const pw.EdgeInsets.all(14),
              decoration: pw.BoxDecoration(
                color: surfaceContainerLow,
                borderRadius: pw.BorderRadius.circular(12),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FICHA DENTAL Y DATOS PERSONALES', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                  pw.SizedBox(height: 6),
                  pw.Text('${paciente.nombre} ${paciente.apellido}', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.SizedBox(height: 4),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text('Teléfono: ${paciente.telefono.isEmpty ? "Sin responder" : paciente.telefono}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Email: ${paciente.email.isEmpty ? "Sin responder" : paciente.email}', style: const pw.TextStyle(fontSize: 10)),
                      pw.Text('Género: ${paciente.genero.isEmpty ? "Sin responder" : paciente.genero}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text('Dirección: ${paciente.direccion.isEmpty ? "Sin responder" : paciente.direccion}', style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            ),
            pw.SizedBox(height: 16),

            // Section 2: Historial de Evaluaciones ATM / Fonseca
            pw.Text('HISTORIAL DE EVALUACIONES DE ATM Y TEST FONSECA:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            if (evaluaciones.isEmpty)
              pw.Text('Sin evaluaciones registradas.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              for (var ev in evaluaciones)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(ev['diagnostico'] ?? 'Evaluación Odontológica', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Fecha: ${ev['fecha'] ?? "Sin fecha"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text('${ev['puntuacion'] ?? 0} pts', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),
            pw.SizedBox(height: 16),

            // Section 3: Citas E Historial de Atenciones
            pw.Text('HISTORIAL DE CITAS Y CONTROLES:', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            if (citas.isEmpty)
              pw.Text('Sin citas previas registradas.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              for (var c in citas)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text('${c['motivo'] ?? "Consulta"} (${c['fecha'] ?? c['fecha_hora'] ?? ""})', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          if (c['notas'] != null && c['notas'].toString().isNotEmpty)
                            pw.Text('Notas: ${c['notas']}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text(c['estado'] ?? 'Programada', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.blue800)),
                    ],
                  ),
                ),
            pw.SizedBox(height: 16),

            // Section 4: Plan de Tratamiento y Presupuesto
            pw.Text('PLAN DE TRATAMIENTOS Y ESTADO DE CUENTA (QUETZALES Q):', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: primaryColor)),
            pw.SizedBox(height: 6),
            if (tratamientos.isEmpty)
              pw.Text('Sin tratamientos activos asignados.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700))
            else
              for (var t in tratamientos)
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 6),
                  padding: const pw.EdgeInsets.all(8),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Column(
                        crossAxisAlignment: pw.CrossAxisAlignment.start,
                        children: [
                          pw.Text(t['nombre'] ?? t['concepto'] ?? 'Tratamiento', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                          pw.Text('Estado: ${t['estado'] ?? "En Proceso"}', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                        ],
                      ),
                      pw.Text('Q ${(t['precio'] ?? t['costo'] ?? 0.0).toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: primaryColor)),
                    ],
                  ),
                ),

            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Doctor responsable: ${doctorInfo?['name'] ?? "Dr. Ludin Solis"} (Colegiado #${doctorInfo?['colegiado'] ?? "98421"})', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                pw.Text('Rizo Dental Sanctuary • Guatemala GTQ (+502 5981-6632)', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
              ],
            ),
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

