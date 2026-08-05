import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';

class FonsecaTestScreen extends StatefulWidget {
  const FonsecaTestScreen({super.key});

  @override
  State<FonsecaTestScreen> createState() => _FonsecaTestScreenState();
}

class _FonsecaTestScreenState extends State<FonsecaTestScreen> {
  final List<Map<String, dynamic>> _questions = [
    {
      'question': '¿Tiene dificultad para abrir la boca?',
      'answer': null,
    },
    {
      'question': '¿Tiene dificultad para mover la mandíbula hacia los lados?',
      'answer': null,
    },
    {
      'question': '¿Siente cansancio o fatiga en los músculos de la masticación?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor en la articulación de la mandíbula (ATM)?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor en el cuello o la nuca?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor de cabeza (cefalea) frecuente?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor o molestia en los oídos?',
      'answer': null,
    },
    {
      'question': '¿Ha notado ruidos o chasquidos (click) al masticar o abrir la boca?',
      'answer': null,
    },
    {
      'question': '¿Ha notado si aprieta o rechina los dientes (bruxismo)?',
      'answer': null,
    },
    {
      'question': '¿Siente que sus dientes no articulan o encajan bien?',
      'answer': null,
    },
  ];

  int _currentQuestionIndex = 0;
  final PageController _pageController = PageController();
  double _btnScale = 1.0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
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

  void _showResults() async {
    final score = _calculateScore();
    final diagnosis = _getDiagnosis(score);
    final severityColor = _getSeverityColor(score);

    // Guardar en Supabase
    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id ?? '';
    
    final evaluacionData = {
      'paciente_id': 'paciente_demo',
      'fecha': DateTime.now().toIso8601String(),
      'puntuacion': score,
      'diagnostico': diagnosis,
      'respuestas': {
        for (var i = 0; i < _questions.length; i++)
          'q${i + 1}': _questions[i]['answer'] ?? ''
      },
    };

    try {
      await supabase.from('evaluaciones').upsert(evaluacionData);
    } catch (e) {
      debugPrint('Error al guardar evaluación en Supabase: $e');
    }

    if (!mounted) return;

    // Diálogo Rizo Dental "The Clinical Sanctuary"
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
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  score >= 45 ? Icons.warning_amber_rounded : Icons.verified_user_outlined,
                  size: 54,
                  color: severityColor,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Diagnóstico de Fonseca',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: severityColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$score / 100 Puntos',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: severityColor,
                  ),
                ),
              ),
              const SizedBox(height: 16),
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
                'Los resultados se han guardado exitosamente en tu expediente de Supabase.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textLight,
                  height: 1.4,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Botón Exportar PDF
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 20, color: AppColors.primary),
                  label: const Text(
                    'Compartir Informe PDF',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  onPressed: () async {
                    final pdf = pw.Document();
                    pdf.addPage(
                      pw.Page(
                        build: (pw.Context context) {
                          return pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.start,
                            children: [
                              pw.Text('RIZO DENTAL - Test Anamnésico de Fonseca', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
                              pw.SizedBox(height: 10),
                              pw.Text('Puntuación Total: $score/100'),
                              pw.Text('Diagnóstico: $diagnosis'),
                              pw.SizedBox(height: 20),
                              pw.Text('Respuestas del Paciente:'),
                              for (var i = 0; i < _questions.length; i++)
                                pw.Text('${i + 1}. ${_questions[i]['question']}: ${_questions[i]['answer']}'),
                            ],
                          );
                        },
                      ),
                    );
                    await Printing.sharePdf(bytes: await pdf.save(), filename: 'rizo_fonseca_reporte.pdf');
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Botón Finalizar
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.pop(context, {
                      'score': score,
                      'diagnosis': diagnosis,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

  void _answerQuestion(String answer) {
    setState(() {
      _questions[_currentQuestionIndex]['answer'] = answer;
    });

    if (_currentQuestionIndex < _questions.length - 1) {
      _currentQuestionIndex++;
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showResults();
    }
  }

  @override
  Widget build(BuildContext context) {
    final double progress = (_currentQuestionIndex + 1) / _questions.length;

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppColors.primary),
          onPressed: () {
            if (_currentQuestionIndex > 0) {
              setState(() => _currentQuestionIndex--);
              _pageController.previousPage(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.assessment_outlined,
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
                  'Test de Fonseca • Evaluación ATM',
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
        child: Column(
          children: [
            // Rizo Dental Progress Bar Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowSoft,
                    blurRadius: 20,
                    offset: Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pregunta ${_currentQuestionIndex + 1} de ${_questions.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      Text(
                        '${(progress * 100).toInt()}% completado',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textLight,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
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
            const SizedBox(height: 12),

            // Question View (PageView with Tonal Layering Cards)
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _questions.length,
                itemBuilder: (context, index) {
                  final String currentAnswer = _questions[index]['answer'] ?? '';

                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Question Card (Signature Component)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(28),
                          decoration: BoxDecoration(
                            color: AppColors.surfaceContainerLowest,
                            borderRadius: BorderRadius.circular(28),
                            boxShadow: const [
                              BoxShadow(
                                color: AppColors.shadowSoft,
                                blurRadius: 24,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.help_outline,
                                  size: 44,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Text(
                                _questions[index]['question'],
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.onSurface,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Answer Options (Sí, A veces, No)
                        _buildOptionButton(
                          label: 'Sí (Frecuente)',
                          value: 'Sí',
                          isSelected: currentAnswer == 'Sí',
                          activeGradient: const [AppColors.primary, AppColors.primaryContainer],
                          points: '10 puntos',
                        ),
                        const SizedBox(height: 14),
                        _buildOptionButton(
                          label: 'A veces (Ocasional)',
                          value: 'A veces',
                          isSelected: currentAnswer == 'A veces',
                          activeGradient: const [AppColors.primaryContainer, Color(0xFF0288D1)],
                          points: '5 puntos',
                        ),
                        const SizedBox(height: 14),
                        _buildOptionButton(
                          label: 'No (Nunca)',
                          value: 'No',
                          isSelected: currentAnswer == 'No',
                          activeGradient: const [Color(0xFF546E7A), Color(0xFF78909C)],
                          points: '0 puntos',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOptionButton({
    required String label,
    required String value,
    required bool isSelected,
    required List<Color> activeGradient,
    required String points,
  }) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _btnScale = 0.98),
      onTapUp: (_) => setState(() => _btnScale = 1.0),
      onTapCancel: () => setState(() => _btnScale = 1.0),
      child: AnimatedScale(
        scale: _btnScale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 56,
          decoration: BoxDecoration(
            gradient: isSelected
                ? LinearGradient(
                    colors: activeGradient,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: isSelected ? null : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(30),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 16,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: ElevatedButton(
            onPressed: () => _answerQuestion(value),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? Colors.white : AppColors.onSurface,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : AppColors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    points,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppColors.textLight,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
