import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';

class QuickEvaluationScreen extends StatefulWidget {
  final Paciente? pacienteInicial;

  const QuickEvaluationScreen({super.key, this.pacienteInicial});

  @override
  State<QuickEvaluationScreen> createState() => _QuickEvaluationScreenState();
}

class _QuickEvaluationScreenState extends State<QuickEvaluationScreen> {
  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;
  bool _loadingPacientes = true;

  double _dolorLevel = 3.0; // 0 a 10
  bool _bloqueoMandibula = false;
  bool _chasquidosDolorosos = true;
  bool _bruxismoNocturno = true;
  bool _cefaleaCervical = false;

  bool _isLoading = false;
  double _btnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _loadingPacientes = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.from('pacientes').select().order('nombre');
      final list = (res as List)
          .map((m) => Paciente.fromMap(Map<String, dynamic>.from(m), m['id'].toString()))
          .toList();

      setState(() {
        _pacientes = list;
        if (widget.pacienteInicial != null) {
          _pacienteSeleccionado = widget.pacienteInicial;
        } else if (list.isNotEmpty) {
          _pacienteSeleccionado = list.first;
        } else {
          _pacienteSeleccionado = Paciente(
            id: 'paciente_general',
            nombre: 'Paciente',
            apellido: 'General',
            email: 'paciente@clinic.com',
            telefono: '+50255551234',
            fechaNacimiento: DateTime(1995, 1, 1),
            genero: 'No especificado',
            direccion: 'Guatemala',
          );
        }
      });
    } catch (e) {
      debugPrint('Error al cargar pacientes en Evaluación Rápida: $e');
    } finally {
      if (mounted) setState(() => _loadingPacientes = false);
    }
  }

  int _calcularPuntaje() {
    int score = (_dolorLevel * 5).toInt(); // 0 a 50 pts
    if (_bloqueoMandibula) score += 20;
    if (_chasquidosDolorosos) score += 10;
    if (_bruxismoNocturno) score += 10;
    if (_cefaleaCervical) score += 10;
    return score.clamp(0, 100);
  }

  String _obtenerDiagnostico(int score) {
    if (score < 30) {
      return 'Riesgo ATM Bajo • Control Preventivo';
    } else if (score < 65) {
      return 'Riesgo ATM Moderado • Férula de Descarga Indicada';
    } else {
      return 'Riesgo ATM Alto / Agudo • Intervención Especialista Recomendada';
    }
  }

  Color _obtenerColorRiesgo(int score) {
    if (score < 30) return AppColors.success;
    if (score < 65) return AppColors.warning;
    return AppColors.error;
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
    );
  }

  Future<void> _guardarYGenerarReporte() async {
    if (_pacienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un paciente primero'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    final score = _calcularPuntaje();
    final diagnostico = _obtenerDiagnostico(score);
    final severityColor = _obtenerColorRiesgo(score);

    final pacienteNombre = '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}';

    final respuestasMap = {
      'nivel_dolor': _dolorLevel.toInt(),
      'bloqueo_mandibula': _bloqueoMandibula ? 'Sí' : 'No',
      'chasquidos_dolorosos': _chasquidosDolorosos ? 'Sí' : 'No',
      'bruxismo_nocturno': _bruxismoNocturno ? 'Sí' : 'No',
      'cefalea_cervical': _cefaleaCervical ? 'Sí' : 'No',
    };

    // Sincronización automática a Supabase vinculada al historial del paciente
    final supabase = Supabase.instance.client;
    final evaluacionData = {
      'id': 'eval_rapida_${DateTime.now().millisecondsSinceEpoch}',
      'paciente_id': _pacienteSeleccionado!.id,
      'pacienteId': _pacienteSeleccionado!.id,
      'paciente_nombre': pacienteNombre,
      'fecha': DateTime.now().toIso8601String(),
      'puntuacion': score,
      'diagnostico': diagnostico,
      'respuestas': respuestasMap,
    };

    try {
      await supabase.from('evaluaciones').upsert(evaluacionData);
    } catch (e) {
      debugPrint('Error al guardar evaluación rápida en Supabase: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    // Mostrar Diálogo Rizo Dental
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        contentPadding: const EdgeInsets.all(28),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                score >= 65 ? Icons.warning_amber_rounded : Icons.health_and_safety_outlined,
                size: 52,
                color: severityColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Evaluación Rápida',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'Paciente: $pacienteNombre',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: severityColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Índice de Riesgo: $score / 100',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: severityColor,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              diagnostico,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: severityColor,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const Text(
              'El registro clínico se ha sincronizado en el historial 360° del paciente en Supabase.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Botón Exportar PDF
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                icon: const Icon(Icons.picture_as_pdf, size: 20, color: AppColors.primary),
                label: const Text(
                  'Exportar Informe PDF Rizo',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary),
                ),
                onPressed: () => _generarPDFCompartir(score, diagnostico, respuestasMap),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botón Volver al Dashboard
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Finalizar y Volver al Inicio', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarPDFCompartir(int score, String diagnostico, Map<String, dynamic> respuestas) async {
    final pdf = pw.Document();
    final fechaStr = DateTime.now().toString().split(' ')[0];
    final pacienteNombre = _pacienteSeleccionado != null
        ? '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}'
        : 'Paciente General';

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(28),
            child: pw.Column(
              cross: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      cross: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
                        pw.Text('The Clinical Sanctuary • Evaluación Rápida', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Text('Fecha: $fechaStr', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('RESULTADO DE EVALUACIÓN CLÍNICA RÁPIDA', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Paciente: $pacienteNombre', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 12),
                pw.Container(
                  padding: const pw.EdgeInsets.all(16),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.grey100,
                    borderRadius: pw.BorderRadius.circular(10),
                  ),
                  child: pw.Column(
                    cross: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('Puntuación de Riesgo: $score / 100 Puntos', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.SizedBox(height: 6),
                      pw.Text('Diagnóstico Presuntivo: $diagnostico', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
                pw.Text('Síntomas Evaluados en Consulta:'),
                pw.SizedBox(height: 10),
                pw.Text('1. Nivel de Dolor Registrado (0-10): ${respuestas['nivel_dolor']} / 10'),
                pw.Text('2. Bloqueo de Mandíbula: ${respuestas['bloqueo_mandibula']}'),
                pw.Text('3. Chasquidos Dolorosos Articulación: ${respuestas['chasquidos_dolorosos']}'),
                pw.Text('4. Bruxismo Nocturno (Apretamiento): ${respuestas['bruxismo_nocturno']}'),
                pw.Text('5. Cefalea / Dolor Cervical Frecuente: ${respuestas['cefalea_cervical']}'),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text('Rizo Dental Sanctuary • Expediente Clínico 360°', style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'rizo_evaluacion_rapida_$fechaStr.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final int puntajeActual = _calcularPuntaje();
    final Color colorActual = _obtenerColorRiesgo(puntajeActual);

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
                Icons.speed,
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
                  'Evaluación Rápida',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: _loadingPacientes
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Patient Selection Top Card (Precision Layering)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowSoft,
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paciente a Evaluar:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Paciente>(
                            value: _pacienteSeleccionado,
                            decoration: _inputDecoration('Seleccionar Paciente de la Lista'),
                            dropdownColor: AppColors.surfaceContainerLowest,
                            items: _pacientes.map((p) {
                              return DropdownMenuItem<Paciente>(
                                value: p,
                                child: Text('${p.nombre} ${p.apellido} (${p.telefono})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _pacienteSeleccionado = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Header Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowSoft,
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Evaluación Rápida',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorActual.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Riesgo: $puntajeActual%',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: colorActual,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Evaluación rápida de 5 factores clave durante la consulta dental.',
                            style: TextStyle(fontSize: 13, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Factor 1: Pain Level Slider
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '1. Nivel de dolor articular / muscular',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                              ),
                              Text(
                                '${_dolorLevel.toInt()} / 10',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Slider(
                            value: _dolorLevel,
                            min: 0,
                            max: 10,
                            divisions: 10,
                            activeColor: AppColors.primary,
                            inactiveColor: AppColors.surfaceContainerLow,
                            onChanged: (val) => setState(() => _dolorLevel = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Factor 2: Bloqueo Mandíbula
                    _buildClinicalSwitch(
                      title: '2. ¿Ha experimentado bloqueo de mandíbula?',
                      subtitle: 'Imposibilidad temporal para abrir o cerrar la boca por completo.',
                      value: _bloqueoMandibula,
                      onChanged: (v) => setState(() => _bloqueoMandibula = v),
                    ),
                    const SizedBox(height: 14),

                    // Factor 3: Chasquidos Dolorosos
                    _buildClinicalSwitch(
                      title: '3. ¿Siente chasquidos (clicks) dolorosos?',
                      subtitle: 'Ruidos articulares acompañados de molestia al masticar.',
                      value: _chasquidosDolorosos,
                      onChanged: (v) => setState(() => _chasquidosDolorosos = v),
                    ),
                    const SizedBox(height: 14),

                    // Factor 4: Bruxismo
                    _buildClinicalSwitch(
                      title: '4. ¿Identifica bruxismo (apretamiento)?',
                      subtitle: 'Rechinamiento nocturno o tensión mandibular matutina.',
                      value: _bruxismoNocturno,
                      onChanged: (v) => setState(() => _bruxismoNocturno = v),
                    ),
                    const SizedBox(height: 14),

                    // Factor 5: Cefalea / Cervical
                    _buildClinicalSwitch(
                      title: '5. ¿Sufre cefaleas o dolor en el cuello?',
                      subtitle: 'Tensión muscular referida hacia la cabeza o zona cervical.',
                      value: _cefaleaCervical,
                      onChanged: (v) => setState(() => _cefaleaCervical = v),
                    ),
                    const SizedBox(height: 28),

                    // Submit Button (Linear Gradient & Scale Animation)
                    GestureDetector(
                      onTapDown: (_) => setState(() => _btnScale = 0.98),
                      onTapUp: (_) => setState(() => _btnScale = 1.0),
                      onTapCancel: () => setState(() => _btnScale = 1.0),
                      child: AnimatedScale(
                        scale: _btnScale,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          height: 56,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowSoft,
                                blurRadius: 20,
                                offset: Offset(0, 6),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isLoading ? null : _guardarYGenerarReporte,
                            icon: const Icon(Icons.assessment, color: Colors.white, size: 22),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Guardar y Generar Diagnóstico',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildClinicalSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            activeColor: AppColors.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
