import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../utils/pdf_generator.dart';
import '../services/supabase_service.dart';

class FonsecaTestScreen extends StatefulWidget {
  final Paciente? pacienteInicial;
  const FonsecaTestScreen({super.key, this.pacienteInicial});

  @override
  State<FonsecaTestScreen> createState() => _FonsecaTestScreenState();
}

class _FonsecaTestScreenState extends State<FonsecaTestScreen> {
  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;
  bool _loadingPacientes = true;
  bool _isSaving = false;
  double _btnScale = 1.0;

  final List<Map<String, dynamic>> _questions = [
    {
      'id': 1,
      'question': '¿Tiene dificultad para abrir la boca?',
      'answer': null,
    },
    {
      'id': 2,
      'question': '¿Tiene dificultad para mover la mandíbula hacia los lados?',
      'answer': null,
    },
    {
      'id': 3,
      'question': '¿Siente cansancio o fatiga en los músculos de la masticación?',
      'answer': null,
    },
    {
      'id': 4,
      'question': '¿Tiene dolor en la articulación de la mandíbula (ATM)?',
      'answer': null,
    },
    {
      'id': 5,
      'question': '¿Tiene dolor en el cuello o la nuca?',
      'answer': null,
    },
    {
      'id': 6,
      'question': '¿Tiene dolor de cabeza (cefalea) frecuente?',
      'answer': null,
    },
    {
      'id': 7,
      'question': '¿Tiene dolor o molestia en los oídos?',
      'answer': null,
    },
    {
      'id': 8,
      'question': '¿Ha notado ruidos o chasquidos (click) al masticar o abrir la boca?',
      'answer': null,
    },
    {
      'id': 9,
      'question': '¿Ha notado si aprieta o rechina los dientes (bruxismo)?',
      'answer': null,
    },
    {
      'id': 10,
      'question': '¿Siente que sus dientes no articulan o encajan bien?',
      'answer': null,
    },
  ];

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _loadingPacientes = true);
    try {
      final supabaseService = SupabaseService();
      final list = await supabaseService.obtenerPacientes();

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
            genero: 'Masculino',
            direccion: 'Guatemala',
          );
        }
      });
    } catch (e) {
      debugPrint('Error al cargar pacientes en Fonseca: $e');
    } finally {
      if (mounted) setState(() => _loadingPacientes = false);
    }
  }

  int _calculateScore() {
    int score = 0;
    for (var question in _questions) {
      if (question['answer'] == 'Sí') {
        score += 10;
      } else if (question['answer'] == 'A veces') {
        score += 5;
      }
    }
    return score;
  }

  int _countAnswered() {
    return _questions.where((q) => q['answer'] != null).length;
  }

  String _getDiagnosis(int score) {
    if (score >= 0 && score <= 15) {
      return 'Sin Disfunción Temporomandibular';
    } else if (score >= 20 && score <= 40) {
      return 'Disfunción Temporomandibular Leve';
    } else if (score >= 45 && score <= 65) {
      return 'Disfunción Temporomandibular Moderada';
    } else if (score >= 70 && score <= 100) {
      return 'Disfunción Temporomandibular Severa';
    }
    return 'Resultado no válido';
  }

  Color _getSeverityColor(int score) {
    if (score <= 15) return AppColors.success;
    if (score <= 40) return AppColors.primary;
    if (score <= 65) return AppColors.warning;
    return AppColors.error;
  }

  void _setAllAnswers(String answer) {
    setState(() {
      for (var q in _questions) {
        q['answer'] = answer;
      }
    });
  }

  void _guardarYMostrarResultados() async {
    final sinResponder = _questions.where((q) => q['answer'] == null).length;
    if (sinResponder > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Por favor responde las $sinResponder preguntas restantes'),
          backgroundColor: AppColors.warning,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final score = _calculateScore();
    final diagnosis = _getDiagnosis(score);
    final severityColor = _getSeverityColor(score);
    final pacienteNombre = _pacienteSeleccionado != null
        ? '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}'
        : 'Paciente General';

    final supabaseService = SupabaseService();
    
    final evaluacionData = {
      'id': 'fonseca_${DateTime.now().millisecondsSinceEpoch}',
      'paciente_id': _pacienteSeleccionado?.id ?? 'paciente_general',
      'pacienteId': _pacienteSeleccionado?.id ?? 'paciente_general',
      'paciente_nombre': pacienteNombre,
      'fecha': DateTime.now().toIso8601String(),
      'puntuacion': score,
      'diagnostico': diagnosis,
      'respuestas': {
        for (var i = 0; i < _questions.length; i++)
          'q${i + 1}': _questions[i]['answer'] ?? ''
      },
    };

    try {
      await supabaseService.guardarEvaluacion(evaluacionData);
    } catch (e) {
      debugPrint('Error al guardar evaluación en Fonseca: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }

    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
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
                  Icons.health_and_safety_outlined,
                  size: 52,
                  color: severityColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Diagnóstico Anamnésico ATM',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                'Paciente: $pacienteNombre',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Puntuación: $score / 100 Puntos',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                diagnosis,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: severityColor,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              const Text(
                'El expediente clínico del paciente ha sido actualizado en el histórico de Supabase.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Export PDF Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf, size: 20, color: AppColors.primary),
                  label: const Text('Exportar PDF Rizo Dental', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  onPressed: () => _generatePdf(score, diagnosis),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Button to Return to Home
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    'Finalizar y Volver al Inicio',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _generatePdf(int score, String diagnosis) async {
    final supabase = Supabase.instance.client;
    final doctorRes = await supabase.from('users').select().eq('email', supabase.auth.currentUser?.email ?? '').maybeSingle();

    if (_pacienteSeleccionado != null) {
      await PdfGenerator.generarPdfFonseca(
        paciente: _pacienteSeleccionado!,
        score: score,
        diagnostico: diagnosis,
        preguntas: _questions,
        doctorInfo: doctorRes,
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final int score = _calculateScore();
    final int answered = _countAnswered();
    final double progress = answered / _questions.length;
    final Color severityColor = _getSeverityColor(score);
    final String currentDiagnosis = _getDiagnosis(score);

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
                Icons.assignment_outlined,
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
                  'Test Anamnésico de Fonseca (Modo Rápido)',
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
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Top Patient Selection & Diagnostic Status Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paciente Evaluado:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Paciente>(
                            value: _pacienteSeleccionado,
                            decoration: _inputDecoration('Seleccionar Paciente'),
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
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Progreso: $answered / ${_questions.length} respondidas',
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    currentDiagnosis,
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: severityColor),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: severityColor.withOpacity(0.12),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Text(
                                  '$score pts',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: severityColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceContainerLow,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Quick Fill Bar (Acciones Rápidas)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(18),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 12, offset: Offset(0, 4)),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.flash_on, color: AppColors.primary, size: 20),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Llenado Rápido:',
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                            ),
                          ),
                          InkWell(
                            onTap: () => _setAllAnswers('No'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.success.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Todo "No"',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.success),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          InkWell(
                            onTap: () => _setAllAnswers('A veces'),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.warning.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
                              ),
                              child: const Text(
                                'Todo "A veces"',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.warning),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Lista continua de las 10 preguntas
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _questions.length,
                      itemBuilder: (context, index) {
                        final q = _questions[index];
                        final String? selectedAnswer = q['answer'];

                        return Container(
                          margin: const EdgeInsets.only(bottom: 14),
                          padding: const EdgeInsets.all(18),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(22),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowSoft,
                                blurRadius: 16,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 28,
                                    height: 28,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      q['question'],
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.onSurface,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              // Segmented Options: Sí (10 pts) | A veces (5 pts) | No (0 pts)
                              Row(
                                children: [
                                  Expanded(
                                    child: _buildChoiceChip(
                                      text: 'Sí (+10)',
                                      value: 'Sí',
                                      isSelected: selectedAnswer == 'Sí',
                                      activeColor: AppColors.error,
                                      onTap: () => setState(() => q['answer'] = 'Sí'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildChoiceChip(
                                      text: 'A veces (+5)',
                                      value: 'A veces',
                                      isSelected: selectedAnswer == 'A veces',
                                      activeColor: AppColors.warning,
                                      onTap: () => setState(() => q['answer'] = 'A veces'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildChoiceChip(
                                      text: 'No (0)',
                                      value: 'No',
                                      isSelected: selectedAnswer == 'No',
                                      activeColor: AppColors.success,
                                      onTap: () => setState(() => q['answer'] = 'No'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Submit Button (Guardar y Ver Diagnóstico)
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
                              colors: [
                                AppColors.primary,
                                AppColors.primaryContainer,
                              ],
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
                            onPressed: _isSaving ? null : _guardarYMostrarResultados,
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                            label: _isSaving
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
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildChoiceChip({
    required String text,
    required String value,
    required bool isSelected,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? activeColor : AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : AppColors.ghostOutline,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: activeColor.withOpacity(0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              color: isSelected ? Colors.white : AppColors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
