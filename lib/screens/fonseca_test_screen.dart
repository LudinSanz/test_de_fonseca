import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
      'question':
          '¿Siente cansancio o fatiga en los músculos de la masticación?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor en la articulación de la mandíbula (ATM)?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor en el cuello?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor de cabeza (cefalea)?',
      'answer': null,
    },
    {
      'question': '¿Tiene dolor de oídos?',
      'answer': null,
    },
    {
      'question':
          '¿Ha notado algún ruido en la articulación temporomandibular (ATM) al masticar o abrir la boca?',
      'answer': null,
    },
    {
      'question': '¿Ha notado que rechina o aprieta los dientes?',
      'answer': null,
    },
    {
      'question': '¿Siente que su mordida no encaja bien?',
      'answer': null,
    },
  ];

  int _currentQuestionIndex = 0;
  final PageController _pageController = PageController();

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

  void _showResults() async {
    final score = _calculateScore();
    final diagnosis = _getDiagnosis(score);

    // Crear PDF
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Header(level: 0, child: pw.Text('Resultados Test de Fonseca')),
              pw.SizedBox(height: 20),
              pw.Text('Puntuación: $score/100 puntos', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.Text('Diagnóstico: $diagnosis'),
              pw.SizedBox(height: 20),
              pw.Text('Respuestas:'),
              for (var i = 0; i < _questions.length; i++)
                pw.Text('${i + 1}. ${_questions[i]['question']}: ${_questions[i]['answer']}'),
            ],
          );
        },
      ),
    );

    // Guardar o compartir el PDF
    await Printing.sharePdf(bytes: await pdf.save(), filename: 'test-fonseca-resultados.pdf');

    final supabase = Supabase.instance.client;
    final currentUserId = supabase.auth.currentUser?.id ?? '';
    final pacienteData = {
      'nombre': 'Paciente Demo',
      'fechaNacimiento': DateTime(2000, 1, 1).toIso8601String(),
      'genero': 'No especificado',
      'creadoPor': currentUserId,
    };

    String pacienteId = '';
    try {
      final query = await supabase
          .from('pacientes')
          .select()
          .eq('nombre', pacienteData['nombre']!)
          .limit(1);

      if (query.isEmpty) {
        final doc = await supabase.from('pacientes').insert(pacienteData).select().single();
        pacienteId = doc['id'].toString();
      } else {
        pacienteId = query.first['id'].toString();
      }
    } catch (e) {
      print('Error al guardar/obtener paciente en Supabase: $e');
    }

    final evaluacionData = {
      'pacienteId': pacienteId,
      'fechaEvaluacion': DateTime.now().toIso8601String(),
      'fonseca': {
        for (var i = 0; i < _questions.length; i++)
          'q${i + 1}': _questions[i]['answer'] ?? ''
      },
      'examenClinico': {},
      'puntuacionTotal': score,
      'severidad': diagnosis,
      'alerta': score >= 45,
    };
    try {
      await supabase.from('evaluaciones').insert(evaluacionData);
      print('Evaluación guardada correctamente');
    } catch (e) {
      print('Error al guardar evaluación: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar evaluación: $e')),
        );
      }
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Resultados del Test de Fonseca'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Puntuación: $score/100 puntos',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              Text('Diagnóstico: $diagnosis'),
              const SizedBox(height: 16),
              const Text(
                'Nota: Este test es solo una herramienta de screening. Consulte con un profesional para un diagnóstico preciso.',
                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context, {
                  'score': score,
                  'diagnosis': diagnosis,
                });
              },
              child: const Text('Finalizar'),
            ),
          ],
        );
      },
    );
  }

  void _answerQuestion(String answer) {
    setState(() {
      _questions[_currentQuestionIndex]['answer'] = answer;

      // Avanzar a la siguiente pregunta o mostrar resultados
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _showResults();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test de Fonseca'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          LinearProgressIndicator(
            value: (_currentQuestionIndex + 1) / _questions.length,
            backgroundColor: Colors.grey[300],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
          ),
          Expanded(
            child: PageView.builder(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _questions.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Pregunta ${index + 1} de ${_questions.length}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        _questions[index]['question'],
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 40),
                      Column(
                        children: [
                          _buildAnswerButton('Sí', Colors.green),
                          const SizedBox(height: 15),
                          _buildAnswerButton('A veces', Colors.orange),
                          const SizedBox(height: 15),
                          _buildAnswerButton('No', Colors.red),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnswerButton(String text, Color color) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _answerQuestion(text),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          text,
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }
}
