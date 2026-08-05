import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';

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
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _loadingPacientes = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.from('pacientes').select();
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
    final pacienteNombre = _pacienteSeleccionado != null
        ? '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}'
        : 'Paciente General';

    // Guardar en Supabase vinculado al paciente seleccionado
    final supabase = Supabase.instance.client;
    
    final evaluacionData = {
      'id': 'fonseca_${DateTime.now().millisecondsSinceEpoch}',
      'paciente_id': _pacienteSeleccionado?.id ?? 'paciente_general',
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
                  label: const Text('Exportar PDF al Paciente', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                  onPressed: () => _generatePdf(score, diagnosis, pacienteNombre),
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

  void _generatePdf(int score, String diagnosis, String pacienteNombre) async {
    final pdf = pw.Document();
    final fechaStr = DateTime.now().toString().split(' ')[0];

    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text('The Clinical Sanctuary • TEST ANAMNÉSICO FONSECA ATM', style: const pw.TextStyle(fontSize: 12)),
                      ],
                    ),
                    pw.Text('Fecha: $fechaStr', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('PACIENTE: $pacienteNombre', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 16),
                pw.Text('RESULTADO DEL DIAGNÓSTICO:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 8),
                pw.Text('Puntuación Total: $score / 100 Puntos', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.Text('Clasificación: $diagnosis', style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('PREGUNTAS Y RESPUESTAS CLÍNICAS:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                for (var i = 0; i < _questions.length; i++)
                  pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Text('${i + 1}. ${_questions[i]['question']} -> ${_questions[i]['answer'] ?? "No respondido"}'),
                  ),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Text('Rizo Dental Sanctuary • Expediente Clínico de Paciente', style: const pw.TextStyle(fontSize: 10)),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'test_fonseca_${_pacienteSeleccionado?.id ?? "paciente"}.pdf',
    );
  }

  void _selectAnswer(String answer) {
    setState(() {
      _questions[_currentQuestionIndex]['answer'] = answer;
    });

    if (_currentQuestionIndex < _questions.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showResults();
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
    final progress = (_currentQuestionIndex + 1) / _questions.length;

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
                  'Test Anamnésico de Fonseca',
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
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Patient Selection Top Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Paciente Evaluado:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 6),
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
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress Bar
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 8,
                              backgroundColor: AppColors.surfaceContainerLow,
                              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          '${_currentQuestionIndex + 1}/${_questions.length}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Question Cards PageView
                    Expanded(
                      child: PageView.builder(
                        controller: _pageController,
                        physics: const NeverScrollableScrollPhysics(),
                        onPageChanged: (index) {
                          setState(() {
                            _currentQuestionIndex = index;
                          });
                        },
                        itemCount: _questions.length,
                        itemBuilder: (context, index) {
                          final question = _questions[index];
                          final currentAnswer = question['answer'];

                          return Container(
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
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Pregunta ${index + 1}',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                    letterSpacing: 1.0,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  question['question'],
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.onSurface,
                                    height: 1.3,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 36),

                                // Option Buttons
                                _buildOptionButton('Sí', currentAnswer == 'Sí'),
                                const SizedBox(height: 12),
                                _buildOptionButton('A veces', currentAnswer == 'A veces'),
                                const SizedBox(height: 12),
                                _buildOptionButton('No', currentAnswer == 'No'),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildOptionButton(String text, bool isSelected) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _btnScale = 0.98),
      onTapUp: (_) => setState(() => _btnScale = 1.0),
      onTapCancel: () => setState(() => _btnScale = 1.0),
      child: AnimatedScale(
        scale: _btnScale,
        duration: const Duration(milliseconds: 120),
        child: Container(
          width: double.infinity,
          height: 52,
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primaryContainer : AppColors.surfaceContainerLow,
            borderRadius: BorderRadius.circular(26),
          ),
          child: ElevatedButton(
            onPressed: () => _selectAnswer(text),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.transparent,
              shadowColor: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(26),
              ),
            ),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
