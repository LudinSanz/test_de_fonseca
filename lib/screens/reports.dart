import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reporte.dart';
import '../constants/colors.dart';

class ReportsScreen extends StatefulWidget {
  final List<Reporte>? reportes;
  const ReportsScreen({super.key, this.reportes});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _evaluacionesHistoricas = [];

  @override
  void initState() {
    super.initState();
    _cargarHistoricoSupabase();
  }

  Future<void> _cargarHistoricoSupabase() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('evaluaciones')
          .select()
          .order('created_at', ascending: false);

      setState(() {
        _evaluacionesHistoricas = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint('Error al cargar histórico de Supabase: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Color _getSeverityColor(String diagnostico) {
    if (diagnostico.contains('Sin Disfunción') || diagnostico.contains('Bajo')) {
      return AppColors.success;
    }
    if (diagnostico.contains('Leve') || diagnostico.contains('Moderado')) {
      return AppColors.primary;
    }
    if (diagnostico.contains('Moderada')) {
      return AppColors.warning;
    }
    return AppColors.error;
  }

  Future<void> _compartirInformePDF(Map<String, dynamic> eval) async {
    final pdf = pw.Document();

    final String diagnostico = eval['diagnostico'] ?? 'Test de Fonseca';
    final int score = eval['puntuacion'] ?? 0;
    final String pacienteNombre = eval['paciente_nombre'] ?? 'Paciente General';
    final String fecha = eval['fecha'] != null
        ? eval['fecha'].toString().split('T')[0]
        : DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(24),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                        pw.Text('The Clinical Sanctuary • Diagnóstico ATM', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Text('Fecha: $fecha', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('HISTORIAL CLÍNICO DE EVALUACIÓN', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Paciente: $pacienteNombre', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Puntuación Anamnésica: $score / 100 Puntos', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Diagnóstico ATM: $diagnostico', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Respuestas del Cuestionario Fonseca:'),
                pw.SizedBox(height: 10),
                if (eval['respuestas'] is Map)
                  for (var entry in (eval['respuestas'] as Map).entries)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(vertical: 2),
                      child: pw.Text('${entry.key}: ${entry.value}'),
                    ),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text('Rizo Dental Sanctuary • Firma y Sello del Especialista', style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'informe_atm_${eval['id'] ?? "eval"}.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.bar_chart_outlined,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIZO DENTAL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'Histórico Clínico en Supabase',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppColors.primary),
            onPressed: _cargarHistoricoSupabase,
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _evaluacionesHistoricas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.assignment_late_outlined,
                            size: 64,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'No hay evaluaciones registradas aún',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.onSurface,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Las evaluaciones realizadas se guardarán automáticamente aquí en Supabase.',
                          style: TextStyle(fontSize: 13, color: AppColors.textLight),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _evaluacionesHistoricas.length,
                    itemBuilder: (context, index) {
                      final eval = _evaluacionesHistoricas[index];
                      final String diagnostico = eval['diagnostico'] ?? 'Evaluación ATM';
                      final String pacienteNombre = eval['paciente_nombre'] ?? 'Paciente General';
                      final int score = eval['puntuacion'] ?? 0;
                      final Color severityColor = _getSeverityColor(diagnostico);
                      final String fechaStr = eval['fecha'] != null
                          ? eval['fecha'].toString().split('T')[0]
                          : 'Reciente';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(
                              color: AppColors.shadowSoft,
                              blurRadius: 20,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: severityColor.withOpacity(0.12),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.assignment_turned_in,
                                color: severityColor,
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    pacienteNombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: AppColors.onSurface,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$diagnostico • Puntos: $score',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: severityColor,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Fecha: $fechaStr',
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.share, color: AppColors.primary),
                              tooltip: 'Compartir PDF',
                              onPressed: () => _compartirInformePDF(eval),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
