import 'package:flutter/material.dart';
import '../models/paciente.dart';
import '../services/supabase_service.dart';
import '../constants/colors.dart';
import 'fonseca_test_screen.dart';

class PatientRegisterScreen extends StatefulWidget {
  const PatientRegisterScreen({super.key});

  @override
  State<PatientRegisterScreen> createState() => _PatientRegisterScreenState();
}

class _PatientRegisterScreenState extends State<PatientRegisterScreen> {
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();

  // Controllers Step 1: Datos Personales
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  DateTime _fechaNacimiento = DateTime(1995, 6, 15);
  String _genero = 'Femenino';

  // Step 2: Antecedentes Odontológicos & ATM
  String _motivoConsulta = 'Dolor en la mandíbula / Apretamiento dental';
  bool _tieneBruxismo = true;
  bool _tieneChasquido = false;
  bool _tieneDolorCabeza = true;

  bool _isLoading = false;
  double _btnScale = 1.0;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _selectFechaNacimiento(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaNacimiento,
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: AppColors.surfaceContainerLowest,
              onSurface: AppColors.onSurface,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _fechaNacimiento) {
      setState(() {
        _fechaNacimiento = picked;
      });
    }
  }

  void _guardarPacienteEnSupabase() async {
    setState(() => _isLoading = true);

    try {
      final nuevoId = 'paciente_${DateTime.now().millisecondsSinceEpoch}';
      final paciente = Paciente(
        id: nuevoId,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        email: _emailController.text.trim(),
        telefono: _telefonoController.text.trim(),
        fechaNacimiento: _fechaNacimiento,
        genero: _genero,
        direccion: _direccionController.text.trim(),
      );

      // Conexión Supabase
      final supabaseService = SupabaseService();
      await supabaseService.guardarPaciente(paciente);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Paciente ${paciente.nombre} guardado exitosamente en Supabase!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );

      // Ofrecer iniciar el Test de Fonseca directamente
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'Registro Exitoso',
            style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          content: Text(
            'El expediente clínico del paciente ${paciente.nombre} ${paciente.apellido} ha sido creado.\n\n¿Deseas iniciar la Evaluación de Fonseca (ATM) ahora?',
            style: const TextStyle(color: AppColors.textLight, height: 1.4),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context, paciente);
              },
              child: const Text('Volver al Inicio', style: TextStyle(color: AppColors.textLight)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const FonsecaTestScreen()),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Iniciar Test ATM'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar paciente: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
    }
    if (_currentStep < 2) {
      setState(() => _currentStep++);
    } else {
      _guardarPacienteEnSupabase();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
    } else {
      Navigator.pop(context);
    }
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
          onPressed: _previousStep,
        ),
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 32,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.person_add_alt_1,
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
                  'Expediente Clínico de Paciente',
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
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Rizo Dental Custom Progress Navigator (Soft Minimalism)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStepIndicator(0, 'Datos', Icons.person_outline),
                    _buildStepLine(0),
                    _buildStepIndicator(1, 'Síntomas ATM', Icons.medical_information_outlined),
                    _buildStepLine(1),
                    _buildStepIndicator(2, 'Confirmar', Icons.check_circle_outline),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Step Content Area (Tonal Layering No-Line Rule)
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _buildCurrentStepWidget(),
              ),
              const SizedBox(height: 28),

              // Bottom Action Buttons
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: SizedBox(
                        height: 54,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _previousStep,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                          ),
                          child: const Text(
                            'Anterior',
                            style: TextStyle(
                              color: AppColors.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 14),
                  Expanded(
                    flex: 2,
                    child: GestureDetector(
                      onTapDown: (_) => setState(() => _btnScale = 0.98),
                      onTapUp: (_) => setState(() => _btnScale = 1.0),
                      onTapCancel: () => setState(() => _btnScale = 1.0),
                      child: AnimatedScale(
                        scale: _btnScale,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          height: 54,
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
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(30),
                              ),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _currentStep == 2
                                        ? 'Guardar Paciente en Supabase'
                                        : 'Siguiente Paso',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return Column(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: isActive
                ? AppColors.primary
                : (isCompleted ? AppColors.primaryContainer : AppColors.surfaceContainerLow),
            shape: BoxShape.circle,
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: (isActive || isCompleted) ? Colors.white : AppColors.textLight,
            size: 22,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive ? AppColors.primary : AppColors.textLight,
          ),
        ),
      ],
    );
  }

  Widget _buildStepLine(int afterStep) {
    final isPassed = _currentStep > afterStep;
    return Expanded(
      child: Container(
        height: 2.5,
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 16),
        decoration: BoxDecoration(
          color: isPassed ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildCurrentStepWidget() {
    switch (_currentStep) {
      case 0:
        return _buildStep1Form();
      case 1:
        return _buildStep2ClinicalForm();
      case 2:
        return _buildStep3Confirmation();
      default:
        return Container();
    }
  }

  // STEP 1: DATOS PERSONALES
  Widget _buildStep1Form() {
    return Container(
      key: const ValueKey('step1'),
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
      child: Form(
        key: _formKeyStep1,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '1. Datos Personales',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Información general de identificación del paciente',
              style: TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),

            // Nombre
            TextFormField(
              controller: _nombreController,
              keyboardType: TextInputType.name,
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa el nombre' : null,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Nombre(s)', Icons.person_outline),
            ),
            const SizedBox(height: 16),

            // Apellido
            TextFormField(
              controller: _apellidoController,
              keyboardType: TextInputType.name,
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa los apellidos' : null,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Apellidos', Icons.badge_outlined),
            ),
            const SizedBox(height: 16),

            // Correo
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              validator: (v) {
                if (v == null || v.isEmpty) return 'Ingresa el correo';
                if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                  return 'Correo no válido';
                }
                return null;
              },
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Correo electrónico', Icons.email_outlined),
            ),
            const SizedBox(height: 16),

            // Teléfono
            TextFormField(
              controller: _telefonoController,
              keyboardType: TextInputType.phone,
              validator: (v) => (v == null || v.isEmpty) ? 'Ingresa el teléfono' : null,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Teléfono de contacto', Icons.phone_outlined),
            ),
            const SizedBox(height: 16),

            // Seleccionar Fecha de Nacimiento
            InkWell(
              onTap: () => _selectFechaNacimiento(context),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ghostOutline, width: 1.0),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Fecha de Nacimiento del Paciente',
                            style: TextStyle(fontSize: 11, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${_fechaNacimiento.day.toString().padLeft(2, '0')} / ${_fechaNacimiento.month.toString().padLeft(2, '0')} / ${_fechaNacimiento.year}',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.edit_calendar_outlined, color: AppColors.primary, size: 20),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Género Select
            const Text(
              'Género',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _buildGenderChip('Femenino'),
                const SizedBox(width: 10),
                _buildGenderChip('Masculino'),
                const SizedBox(width: 10),
                _buildGenderChip('Otro'),
              ],
            ),
            const SizedBox(height: 16),

            // Dirección
            TextFormField(
              controller: _direccionController,
              keyboardType: TextInputType.streetAddress,
              style: const TextStyle(color: AppColors.onSurface),
              decoration: _inputDecoration('Dirección de residencia', Icons.location_on_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenderChip(String label) {
    final isSelected = _genero == label;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) setState(() => _genero = label);
      },
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceContainerLow,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.onSurface,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide.none,
      ),
    );
  }

  // STEP 2: ANTECEDENTES CLINICOS & SÍNTOMAS ATM
  Widget _buildStep2ClinicalForm() {
    return Container(
      key: const ValueKey('step2'),
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
          const Text(
            '2. Antecedentes & Síntomas ATM',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Indicadores clínicos preliminares para la evaluación de Fonseca',
            style: TextStyle(fontSize: 13, color: AppColors.textLight),
          ),
          const SizedBox(height: 24),

          // Motivo de Consulta
          const Text(
            'Motivo Principal de Consulta',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _motivoConsulta,
            decoration: _inputDecoration('Motivo', Icons.medical_services_outlined),
            dropdownColor: AppColors.surfaceContainerLowest,
            items: const [
              DropdownMenuItem(
                value: 'Dolor en la mandíbula / Apretamiento dental',
                child: Text('Dolor / Apretamiento mandibular'),
              ),
              DropdownMenuItem(
                value: 'Chasquidos o ruidos al masticar',
                child: Text('Chasquidos / Ruidos articulación'),
              ),
              DropdownMenuItem(
                value: 'Cefaleas frecuentes y dolor de cuello',
                child: Text('Cefaleas y dolor de cuello'),
              ),
              DropdownMenuItem(
                value: 'Chequeo Odontológico General',
                child: Text('Chequeo Odontológico General'),
              ),
            ],
            onChanged: (val) {
              if (val != null) setState(() => _motivoConsulta = val);
            },
          ),
          const SizedBox(height: 20),

          // Switch 1: Bruxismo
          _buildSymptomSwitch(
            title: '¿Presenta apretamiento o rechinamiento dental (Bruxismo)?',
            subtitle: 'Hábito incontrolado de apretar los dientes durante el día o la noche.',
            value: _tieneBruxismo,
            onChanged: (v) => setState(() => _tieneBruxismo = v),
          ),
          const SizedBox(height: 14),

          // Switch 2: Chasquidos
          _buildSymptomSwitch(
            title: '¿Siente ruidos o chasquidos en la articulación (ATM)?',
            subtitle: 'Sensación de "click" o salto al abrir o cerrar la boca.',
            value: _tieneChasquido,
            onChanged: (v) => setState(() => _tieneChasquido = v),
          ),
          const SizedBox(height: 14),

          // Switch 3: Cefaleas
          _buildSymptomSwitch(
            title: '¿Sufre de dolores de cabeza recurrentes o dolor en el cuello?',
            subtitle: 'Tensión muscular extendida a zona temporal o cervical.',
            value: _tieneDolorCabeza,
            onChanged: (v) => setState(() => _tieneDolorCabeza = v),
          ),
        ],
      ),
    );
  }

  Widget _buildSymptomSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
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

  // STEP 3: CONFIRMACIÓN DE RESUMEN
  Widget _buildStep3Confirmation() {
    return Container(
      key: const ValueKey('step3'),
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
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '3. Resumen de Expediente',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.onSurface,
                    ),
                  ),
                  Text(
                    'Verifica los datos antes de sincronizar con Supabase',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Resumen de Datos
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                _buildSummaryRow('Paciente', '${_nombreController.text} ${_apellidoController.text}'),
                _buildSummaryRow('Correo', _emailController.text),
                _buildSummaryRow('Teléfono', _telefonoController.text),
                _buildSummaryRow('Género', _genero),
                _buildSummaryRow('Motivo', _motivoConsulta),
                _buildSummaryRow('Bruxismo', _tieneBruxismo ? 'Sí' : 'No'),
                _buildSummaryRow('Chasquidos ATM', _tieneChasquido ? 'Sí' : 'No'),
                _buildSummaryRow('Dolores de Cabeza', _tieneDolorCabeza ? 'Sí' : 'No'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textLight)),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              textAlign: TextAlign.end,
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textLight),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      prefixIcon: Icon(icon, color: AppColors.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.ghostOutline, width: 1.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.error, width: 1.5),
      ),
    );
  }
}
