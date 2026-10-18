import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reporte.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';
import '../models/paciente.dart';
import '../utils/pdf_generator.dart';
import '../widgets/signature_pad.dart';

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
      final supabaseService = SupabaseService();
      final response = await supabaseService.obtenerEvaluaciones();

      setState(() {
        _evaluacionesHistoricas = response;
      });
    } catch (e) {
      debugPrint('Error al cargar histórico: $e');
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
    final firmaData = await SignaturePadDialog.pedirFirma(
      context,
      tituloDocumento: 'Informe Oficial de Evaluación ATM',
    );
    if (firmaData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requiere la firma del odontólogo para emitir y certificar el informe.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    final String diagnostico = eval['diagnostico'] ?? 'Evaluación Clínica ATM';
    final int score = eval['puntuacion'] ?? 0;
    final String pacienteNombre = eval['paciente_nombre'] ?? 'Paciente General';
    final String pacienteId = eval['paciente_id'] ?? eval['pacienteId'] ?? 'temp_id';

    final paciente = Paciente(
      id: pacienteId,
      nombre: pacienteNombre,
      apellido: '',
      email: '',
      telefono: '',
      fechaNacimiento: DateTime(1995, 1, 1),
      genero: 'No especificado',
      direccion: 'Ciudad de Guatemala',
    );

    List<Map<String, dynamic>> preguntas = [];
    if (eval['respuestas'] is Map) {
      for (var entry in (eval['respuestas'] as Map).entries) {
        preguntas.add({
          'question': entry.key.toString(),
          'answer': entry.value.toString(),
        });
      }
    }

    final supabaseService = SupabaseService();
    String emailOrId = '';
    try {
      final u = Supabase.instance.client.auth.currentUser;
      if (u != null) emailOrId = u.email ?? u.id;
    } catch (_) {}
    final doctorInfo = await supabaseService.obtenerPerfilDoctor(emailOrId);

    await PdfGenerator.generarPdfFonseca(
      paciente: paciente,
      score: score,
      diagnostico: diagnostico,
      preguntas: preguntas,
      doctorInfo: doctorInfo,
      signaturePngBytes: firmaData.pngBytes,
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
