import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../services/supabase_service.dart';
import 'fonseca_test_screen.dart';
import 'treatments_screen.dart';

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

  // Nuevos campos para Consulta Clinica Integral
  String _tipoConsulta = 'Consulta General';
  final List<String> _tiposConsulta = [
    'Consulta General',
    'Limpieza Dental',
    'Ortodoncia',
    'Cirugia',
    'Blanqueamiento',
    'Endodoncia',
    'ATM / Dolor Articular'
  ];

  final TextEditingController _motivoCtrl = TextEditingController();
  final TextEditingController _diagnosticoGeneralCtrl = TextEditingController();

  // Variables específicas para ATM
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

  @override
  void dispose() {
    _motivoCtrl.dispose();
    _diagnosticoGeneralCtrl.dispose();
    super.dispose();
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
        }
      });
    } catch (e) {
      debugPrint('Error al cargar pacientes en Consulta Clínica: $e');
    } finally {
      if (mounted) setState(() => _loadingPacientes = false);
    }
  }

  int _calcularPuntajeATM() {
    int score = (_dolorLevel * 5).toInt(); // 0 a 50 pts
    if (_bloqueoMandibula) score += 20;
    if (_chasquidosDolorosos) score += 10;
    if (_bruxismoNocturno) score += 10;
    if (_cefaleaCervical) score += 10;
    return score.clamp(0, 100);
  }

  String _obtenerDiagnostico() {
    if (_tipoConsulta == 'ATM / Dolor Articular') {
      final score = _calcularPuntajeATM();
      if (score < 30) {
        return 'Riesgo ATM Bajo • Control Preventivo';
      } else if (score < 65) {
        return 'Riesgo ATM Moderado • Férula de Descarga Indicada';
      } else {
        return 'Riesgo ATM Alto / Agudo • Intervención Especialista Recomendada';
      }
    } else {
      return _diagnosticoGeneralCtrl.text.isNotEmpty 
          ? _diagnosticoGeneralCtrl.text 
          : 'Consulta de evaluación de $_tipoConsulta completada.';
    }
  }

  Color _obtenerColorRiesgo() {
    if (_tipoConsulta == 'ATM / Dolor Articular') {
      final score = _calcularPuntajeATM();
      if (score < 30) return AppColors.success;
      if (score < 65) return AppColors.warning;
      return AppColors.error;
    }
    return AppColors.primary; // Color normal para consultas generales
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

    if (_motivoCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor ingresa el motivo de la consulta'), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isLoading = true);
    final diagnostico = _obtenerDiagnostico();
    final severityColor = _obtenerColorRiesgo();
    final pacienteNombre = '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}';

    Map<String, dynamic> respuestasMap = {
      'tipo_consulta': _tipoConsulta,
      'motivo': _motivoCtrl.text,
      'diagnostico_general': _diagnosticoGeneralCtrl.text,
    };

    if (_tipoConsulta == 'ATM / Dolor Articular') {
      respuestasMap.addAll({
        'nivel_dolor': _dolorLevel.toInt(),
        'bloqueo_mandibula': _bloqueoMandibula ? 'Sí' : 'No',
        'chasquidos_dolorosos': _chasquidosDolorosos ? 'Sí' : 'No',
        'bruxismo_nocturno': _bruxismoNocturno ? 'Sí' : 'No',
        'cefalea_cervical': _cefaleaCervical ? 'Sí' : 'No',
        'puntaje_atm': _calcularPuntajeATM(),
      });
    }

    final supabaseService = SupabaseService();
    final evaluacionData = {
      'id': 'eval_rapida_${DateTime.now().millisecondsSinceEpoch}',
      'paciente_id': _pacienteSeleccionado!.id,
      'pacienteId': _pacienteSeleccionado!.id,
      'paciente_nombre': pacienteNombre,
      'fecha': DateTime.now().toIso8601String(),
      'puntuacion': _tipoConsulta == 'ATM / Dolor Articular' ? _calcularPuntajeATM() : 0,
      'diagnostico': diagnostico,
      'respuestas': respuestasMap,
    };

    try {
      await supabaseService.guardarEvaluacion(evaluacionData);
    } catch (e) {
      debugPrint('Error al guardar consulta: $e');
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
                _tipoConsulta == 'ATM / Dolor Articular' && _calcularPuntajeATM() >= 65 
                    ? Icons.warning_amber_rounded 
                    : Icons.check_circle_outline_rounded,
                size: 52,
                color: severityColor,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Consulta Finalizada',
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
              'La información de la consulta se ha guardado en el expediente clínico del paciente.',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.4),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Botón Crear Plan de Tratamiento y Presupuesto
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.medical_services_outlined, size: 18, color: Colors.white),
                label: const Text('Iniciar Plan de Tratamiento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => TreatmentsScreen(paciente: _pacienteSeleccionado)),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 8),

            if (_tipoConsulta == 'ATM / Dolor Articular')
              SizedBox(
                width: double.infinity,
                height: 44,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.assignment_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Derivar a Test de Fonseca', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (context) => const FonsecaTestScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primary, width: 1.2),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Botón Volver al Dashboard
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Cerrar Consulta', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
            ),
          ],
        ),
      ),
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
                Icons.medical_information,
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
                  'Consulta Clínica Integrada',
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
                    // Patient Selection
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
                            'Paciente en Consulta:',
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

                    // Tipo de Consulta
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Tipo de Consulta Clínica:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<String>(
                            value: _tipoConsulta,
                            decoration: _inputDecoration('Especialidad o Área'),
                            dropdownColor: AppColors.surfaceContainerLowest,
                            items: _tiposConsulta.map((t) {
                              return DropdownMenuItem<String>(
                                value: t,
                                child: Text(t),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _tipoConsulta = val);
                            },
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Motivo Principal (Dolor, Síntomas, Revisión):',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _motivoCtrl,
                            maxLines: 3,
                            decoration: _inputDecoration('Ej. Paciente refiere dolor al masticar en cuadrante inferior derecho...'),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Diagnóstico / Hallazgos Clínicos:',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _diagnosticoGeneralCtrl,
                            maxLines: 3,
                            decoration: _inputDecoration('Ej. Presencia de caries profunda en pieza 46, se recomienda endodoncia...'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Sección condicional para Evaluación ATM
                    if (_tipoConsulta == 'ATM / Dolor Articular') ...[
                      const Padding(
                        padding: EdgeInsets.only(left: 8, bottom: 12, top: 10),
                        child: Text(
                          'Evaluación Específica ATM',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary),
                        ),
                      ),
                      
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
                    ],

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
                            icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 22),
                            label: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Finalizar Consulta',
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
