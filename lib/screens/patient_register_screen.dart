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
  // Ahora solo 2 pasos: 0 = Datos Clínicos & Personales, 1 = Confirmar y Guardar
  int _currentStep = 0;
  final _formKeyStep1 = GlobalKey<FormState>();

  // ---- Datos Personales y de Identificación ----
  final TextEditingController _nombreController = TextEditingController();
  final TextEditingController _apellidoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _dpiController = TextEditingController();
  final TextEditingController _direccionController = TextEditingController();
  final TextEditingController _contactoEmergenciaController = TextEditingController();
  final TextEditingController _telEmergenciaController = TextEditingController();

  String _codigoPais = '+502';
  DateTime _fechaNacimiento = DateTime(1995, 6, 15);
  String _genero = 'Femenino';

  // ---- Antecedentes Médicos Generales ----
  String _alergias = 'Ninguna conocida';
  String _condicionMedica = 'Aparente buen estado de salud';
  final TextEditingController _medicacionActualController = TextEditingController();

  // ---- Motivo Principal de Consulta (Dinámico) ----
  String _motivoConsulta = 'Disfunción ATM / Dolor Mandibular';

  // Opciones Dinámicas: ATM
  bool _tieneBruxismo = true;
  bool _tieneChasquido = true;
  bool _tieneDolorCabeza = true;
  bool _tieneLimitacionApertura = false;
  bool _despiertaConTension = true;
  double _nivelDolorATM = 6.0; // Escala 0-10
  String _tiempoSintomasATM = '1 a 6 meses';

  // Opciones Dinámicas: Estética & Armonización
  final List<String> _interesesEstetica = ['Toxina botulínica'];
  bool _procedimientosPreviosEstetica = false;
  String _zonaPrioridadEstetica = 'Tercio inferior y perfil mandibular';

  // Opciones Dinámicas: Ortodoncia
  bool _haUsadoOrtodoncia = false;
  String _tipoOrtodonciaDeseada = 'Alineadores Invisibles';
  String _problemaOrtodoncia = 'Apiñamiento dental';

  // Opciones Dinámicas: Dolor Agudo / Endodoncia
  double _intensidadDolorDental = 7.0;
  String _tipoDolorDental = 'Con estímulos fríos y al masticar';
  final TextEditingController _piezaAfectadaController = TextEditingController();

  // Opciones Dinámicas: Rehabilitación / Implantes
  bool _tienePiezasFaltantes = true;
  String _necesidadProtesica = 'Implante dental fijo unitario';

  // Opciones Dinámicas: Limpieza & General
  String _ultimaVisitaDental = 'Hace más de 6 meses';
  bool _sangradoEncias = true;
  bool _sensibilidadDental = false;

  bool _isLoading = false;
  double _btnScale = 1.0;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _emailController.dispose();
    _telefonoController.dispose();
    _dpiController.dispose();
    _direccionController.dispose();
    _contactoEmergenciaController.dispose();
    _telEmergenciaController.dispose();
    _medicacionActualController.dispose();
    _piezaAfectadaController.dispose();
    super.dispose();
  }

  int _calcularEdad(DateTime fecha) {
    final now = DateTime.now();
    int edad = now.year - fecha.year;
    if (now.month < fecha.month || (now.month == fecha.month && now.day < fecha.day)) {
      edad--;
    }
    return edad < 0 ? 0 : edad;
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
      setState(() => _fechaNacimiento = picked);
    }
  }

  void _guardarPacienteEnSupabase() async {
    setState(() => _isLoading = true);

    try {
      final nuevoId = 'paciente_${DateTime.now().millisecondsSinceEpoch}';
      String rawTel = _telefonoController.text.trim();
      String telefonoFinal = rawTel;
      if (!rawTel.startsWith('+')) {
        telefonoFinal = '$_codigoPais $rawTel';
      }

      final paciente = Paciente(
        id: nuevoId,
        nombre: _nombreController.text.trim(),
        apellido: _apellidoController.text.trim(),
        email: _emailController.text.trim(),
        telefono: telefonoFinal,
        fechaNacimiento: _fechaNacimiento,
        genero: _genero,
        direccion: _direccionController.text.trim(),
      );

      final supabaseService = SupabaseService();
      await supabaseService.guardarPaciente(paciente);

      // Si el motivo es ATM o incluye síntomas mandibulares, registrar la evaluación clínica preliminar
      if (_motivoConsulta.contains('ATM') || _tieneBruxismo || _tieneChasquido) {
        await supabaseService.guardarEvaluacion({
          'paciente_id': nuevoId,
          'paciente_nombre': '${paciente.nombre} ${paciente.apellido}',
          'fecha': DateTime.now().toIso8601String(),
          'puntuacion': (_nivelDolorATM * 3).round(),
          'diagnostico': _nivelDolorATM >= 7
              ? 'Disfunción ATM Severa / Sospecha DTM'
              : (_nivelDolorATM >= 4 ? 'Disfunción ATM Moderada' : 'Disfunción ATM Leve'),
          'respuestas': {
            'motivo': _motivoConsulta,
            'bruxismo': _tieneBruxismo,
            'chasquido': _tieneChasquido,
            'dolor_cabeza': _tieneDolorCabeza,
            'limitacion_apertura': _tieneLimitacionApertura,
            'despierta_con_tension': _despiertaConTension,
            'escala_dolor': _nivelDolorATM.round(),
            'tiempo_evolucion': _tiempoSintomasATM,
            'alergias': _alergias,
            'condicion_medica': _condicionMedica,
          },
        });
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡Expediente de ${paciente.nombre} creado con éxito!'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );

      // Ofrecer iniciar Fonseca o terminar
      showDialog(
        context: context,
        builder: (dialogCtx) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: AppColors.success, size: 28),
              SizedBox(width: 10),
              Text('Expediente Creado', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.onSurface)),
            ],
          ),
          content: Text(
            'El expediente del paciente ${paciente.nombre} ${paciente.apellido} ha sido sincronizado.\n\n' +
                (_motivoConsulta.contains('ATM')
                    ? '¿Deseas realizar el Test de Fonseca (ATM) completo de 10 preguntas ahora?'
                    : '¿Deseas realizar una evaluación clínica o volver al inicio?'),
            style: const TextStyle(color: AppColors.textLight, height: 1.4, fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogCtx);
                Navigator.pop(context, paciente);
              },
              child: const Text('Volver al Directorio', style: TextStyle(color: AppColors.textLight)),
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
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _nextStep() {
    if (_currentStep == 0) {
      if (!_formKeyStep1.currentState!.validate()) return;
      setState(() => _currentStep = 1);
    } else {
      _guardarPacienteEnSupabase();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() => _currentStep = 0);
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
              errorBuilder: (_, __, ___) => const Icon(Icons.person_add_alt_1, color: AppColors.primary),
            ),
            const SizedBox(width: 8),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIZO DENTAL',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.primary),
                ),
                Text('Nuevo Expediente Clínico', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barra de Progreso Mejorada: 2 Pasos (Datos ➔ Confirmar)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4))],
                ),
                child: Row(
                  children: [
                    _buildStepIndicator(0, '1. Datos & Clínica', Icons.assignment_ind_outlined),
                    _buildStepLine(0),
                    _buildStepIndicator(1, '2. Confirmar', Icons.check_circle_outline),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Contenido del Paso Actual
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: _currentStep == 0 ? _buildStep1DatosForm() : _buildStep2Confirmacion(),
              ),
              const SizedBox(height: 24),

              // Botones de Navegación
              Row(
                children: [
                  if (_currentStep > 0)
                    Expanded(
                      child: SizedBox(
                        height: 52,
                        child: OutlinedButton(
                          onPressed: _isLoading ? null : _previousStep,
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                          ),
                          child: const Text('Modificar Datos', style: TextStyle(color: AppColors.onSurface, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ),
                  if (_currentStep > 0) const SizedBox(width: 12),
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
                          height: 52,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [AppColors.primary, AppColors.primaryContainer],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4))],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _nextStep,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        _currentStep == 0 ? 'Continuar a Resumen' : 'Guardar y Crear Expediente',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                                      ),
                                      const SizedBox(width: 8),
                                      Icon(_currentStep == 0 ? Icons.arrow_forward : Icons.cloud_upload_outlined, color: Colors.white, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepIndicator(int stepIndex, String title, IconData icon) {
    final isActive = _currentStep == stepIndex;
    final isCompleted = _currentStep > stepIndex;

    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: isActive ? AppColors.primary : (isCompleted ? AppColors.primaryContainer : AppColors.surfaceContainerLow),
            shape: BoxShape.circle,
          ),
          child: Icon(
            isCompleted ? Icons.check : icon,
            color: (isActive || isCompleted) ? Colors.white : AppColors.textLight,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
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
        margin: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isPassed ? AppColors.primary : AppColors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  // ============================================================
  // PASO 1: DATOS CLÍNICOS Y PERSONALES (CON LÓGICA DINÁMICA)
  // ============================================================
  Widget _buildStep1DatosForm() {
    final edad = _calcularEdad(_fechaNacimiento);

    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── SECCIÓN 1: IDENTIFICACIÓN Y CONTACTO ──
          _buildCardSection(
            titulo: '1. Identificación y Contacto',
            subtitulo: 'Información general de identificación del paciente',
            icono: Icons.person_outline,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _nombreController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el nombre' : null,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('Nombre(s) *', Icons.person_outline),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _apellidoController,
                        textCapitalization: TextCapitalization.words,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa los apellidos' : null,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('Apellidos *', Icons.badge_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // DPI y Correo
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dpiController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('DPI / Cédula (Opcional)', Icons.credit_card_outlined),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('Correo Electrónico', Icons.email_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Teléfono con Selector de Código de País
                Row(
                  children: [
                    Container(
                      height: 52,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.ghostOutline),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _codigoPais,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                          items: const [
                            DropdownMenuItem(value: "+502", child: Text("🇬🇹 +502", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "+503", child: Text("🇸🇻 +503", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "+504", child: Text("🇭🇳 +504", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "+505", child: Text("🇳🇮 +505", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "+506", child: Text("🇨🇷 +506", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "+52", child: Text("🇲🇽 +52", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                            DropdownMenuItem(value: "+1", child: Text("🇺🇸 +1", style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold))),
                          ],
                          onChanged: (val) {
                            if (val != null) setState(() => _codigoPais = val);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _telefonoController,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Ingresa el teléfono' : null,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('Teléfono / WhatsApp *', Icons.phone_outlined),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Fecha de Nacimiento con cálculo visual de edad
                InkWell(
                  onTap: () => _selectFechaNacimiento(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.ghostOutline),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_month_outlined, color: AppColors.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Fecha de Nacimiento', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                              const SizedBox(height: 2),
                              Text(
                                '${_fechaNacimiento.day.toString().padLeft(2, '0')}/${_fechaNacimiento.month.toString().padLeft(2, '0')}/${_fechaNacimiento.year}  ($edad años)',
                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.edit_calendar_outlined, color: AppColors.primary, size: 20),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                // Género
                const Text('Género *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _buildGenderChip('Femenino'),
                    const SizedBox(width: 8),
                    _buildGenderChip('Masculino'),
                    const SizedBox(width: 8),
                    _buildGenderChip('Otro'),
                  ],
                ),
                const SizedBox(height: 14),

                // Dirección
                TextFormField(
                  controller: _direccionController,
                  textCapitalization: TextCapitalization.sentences,
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                  decoration: _inputDecoration('Dirección de residencia (Opcional)', Icons.location_on_outlined),
                ),
                const SizedBox(height: 14),

                // Contacto de Emergencia
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _contactoEmergenciaController,
                        textCapitalization: TextCapitalization.words,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('Familiar / Contacto de Emergencia', Icons.contact_phone_outlined),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextFormField(
                        controller: _telEmergenciaController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                        decoration: _inputDecoration('Tel. Emergencia', Icons.phone_callback_outlined),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── SECCIÓN 2: ANTECEDENTES MÉDICOS Y SALUD ──
          _buildCardSection(
            titulo: '2. Historial Médico General',
            subtitulo: 'Condiciones de salud, alergias y medicación habitual',
            icono: Icons.health_and_safety_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Alergias a Medicamentos', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _alergias,
                  decoration: _inputDecoration('Alergias', Icons.warning_amber_rounded),
                  items: const [
                    DropdownMenuItem(value: "Ninguna conocida", child: Text("Ninguna conocida")),
                    DropdownMenuItem(value: "Penicilina / Amoxicilina", child: Text("Penicilina / Amoxicilina")),
                    DropdownMenuItem(value: "Anestésicos locales", child: Text("Anestésicos locales")),
                    DropdownMenuItem(value: "AINEs / Aspirina / Ibuprofeno", child: Text("AINEs / Aspirina / Ibuprofeno")),
                    DropdownMenuItem(value: "Múltiples alergias", child: Text("Múltiples alergias")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _alergias = val);
                  },
                ),
                const SizedBox(height: 14),

                const Text('Condición Sistémica Previa', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  value: _condicionMedica,
                  decoration: _inputDecoration('Condición', Icons.medical_information_outlined),
                  items: const [
                    DropdownMenuItem(value: "Aparente buen estado de salud", child: Text("Aparente buen estado de salud")),
                    DropdownMenuItem(value: "Hipertensión arterial", child: Text("Hipertensión arterial")),
                    DropdownMenuItem(value: "Diabetes Mellitus", child: Text("Diabetes Mellitus")),
                    DropdownMenuItem(value: "Cardiopatía / Coagulación", child: Text("Cardiopatía / Coagulación")),
                    DropdownMenuItem(value: "Embarazo en curso", child: Text("Embarazo en curso")),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _condicionMedica = val);
                  },
                ),
                const SizedBox(height: 14),

                TextFormField(
                  controller: _medicacionActualController,
                  style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
                  decoration: _inputDecoration('Medicamentos que toma actualmente (si aplica)', Icons.medication_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          // ── SECCIÓN 3: MOTIVO DE CONSULTA Y PREGUNTAS CONDICIONALES ──
          _buildCardSection(
            titulo: '3. Motivo de Consulta y Evaluación Específica',
            subtitulo: 'Selecciona el motivo principal para ver las preguntas clínicas relacionadas',
            icono: Icons.medical_services_outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Motivo Principal de Consulta *', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                const SizedBox(height: 8),

                // Selector de Motivos
                DropdownButtonFormField<String>(
                  value: _motivoConsulta,
                  decoration: _inputDecoration('Motivo de consulta', Icons.medical_services_outlined),
                  items: const [
                    DropdownMenuItem(
                      value: "Disfunción ATM / Dolor Mandibular",
                      child: Text("🦴 Disfunción ATM / Dolor Mandibular"),
                    ),
                    DropdownMenuItem(
                      value: "Estética Dental y Armonización Orofacial",
                      child: Text("✨ Estética & Armonización Facial"),
                    ),
                    DropdownMenuItem(
                      value: "Ortodoncia (Alineadores / Frenos)",
                      child: Text("🦷 Ortodoncia (Alineadores / Frenos)"),
                    ),
                    DropdownMenuItem(
                      value: "Dolor Agudo / Endodoncia",
                      child: Text("⚡ Dolor Dental Agudo / Endodoncia"),
                    ),
                    DropdownMenuItem(
                      value: "Rehabilitación Oral / Implantes",
                      child: Text("🛠️ Implantes / Prótesis / Coronas"),
                    ),
                    DropdownMenuItem(
                      value: "Limpieza Dental & Chequeo General",
                      child: Text("🪥 Limpieza & Chequeo General"),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _motivoConsulta = val);
                  },
                ),
                const SizedBox(height: 16),

                // ── BLOQUE CONDICIONAL SEGÚN MOTIVO ──
                _buildDynamicClinicalFields(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════
  // CAMPOS CLÍNICOS DINÁMICOS SEGÚN EL MOTIVO DE CONSULTA
  // ════════════════════════════════════════════════════════
  Widget _buildDynamicClinicalFields() {
    if (_motivoConsulta.contains('ATM') || _motivoConsulta.contains('Mandibular')) {
      // ── CASO A: DISFUNCIÓN ATM Y TRASTORNOS TEMPOROMANDIBULARES ──
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.assessment_outlined, color: AppColors.primary, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Evaluación Específica ATM & Muscular (Fonseca)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            _buildSymptomSwitch(
              title: '¿Presenta apretamiento o rechinamiento (Bruxismo)?',
              subtitle: 'Hábito diurno o nocturno de apretar dientes.',
              value: _tieneBruxismo,
              onChanged: (v) => setState(() => _tieneBruxismo = v),
            ),
            const SizedBox(height: 10),

            _buildSymptomSwitch(
              title: '¿Siente ruidos, chasquidos o clics articulares?',
              subtitle: 'Sonido tipo "pop" o roce al masticar o abrir.',
              value: _tieneChasquido,
              onChanged: (v) => setState(() => _tieneChasquido = v),
            ),
            const SizedBox(height: 10),

            _buildSymptomSwitch(
              title: '¿Dolores de cabeza recurrentes o dolor en cuello?',
              subtitle: 'Tensión en sienes, zona retroauricular o nuca.',
              value: _tieneDolorCabeza,
              onChanged: (v) => setState(() => _tieneDolorCabeza = v),
            ),
            const SizedBox(height: 10),

            _buildSymptomSwitch(
              title: '¿Dificultad o dolor al abrir la boca ampliamente?',
              subtitle: 'Traba mandibular o limitación de apertura.',
              value: _tieneLimitacionApertura,
              onChanged: (v) => setState(() => _tieneLimitacionApertura = v),
            ),
            const SizedBox(height: 10),

            _buildSymptomSwitch(
              title: '¿Despierta con cansancio o rigidez mandibular?',
              subtitle: 'Fatiga matutina de los músculos masticatorios.',
              value: _despiertaConTension,
              onChanged: (v) => setState(() => _despiertaConTension = v),
            ),
            const SizedBox(height: 14),

            // Escala Visual de Dolor EVA
            Text(
              'Intensidad del Dolor Mandibular / ATM: ${_nivelDolorATM.round()} / 10',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            Slider(
              value: _nivelDolorATM,
              min: 0,
              max: 10,
              divisions: 10,
              activeColor: _nivelDolorATM >= 7 ? AppColors.error : (_nivelDolorATM >= 4 ? AppColors.warning : AppColors.primary),
              label: '${_nivelDolorATM.round()}',
              onChanged: (v) => setState(() => _nivelDolorATM = v),
            ),
            const SizedBox(height: 6),

            // Tiempo de evolución
            const Text('Tiempo con los síntomas:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Menos de 1 mes', '1 a 6 meses', 'Más de 6 meses', 'Años'].map((tiempo) {
                final isSel = _tiempoSintomasATM == tiempo;
                return ChoiceChip(
                  label: Text(tiempo, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.onSurface)),
                  selected: isSel,
                  selectedColor: AppColors.primary,
                  backgroundColor: AppColors.surfaceContainerLow,
                  onSelected: (s) => setState(() => _tiempoSintomasATM = tiempo),
                );
              }).toList(),
            ),
          ],
        ),
      );
    } else if (_motivoConsulta.contains('Estética')) {
      // ── CASO B: ESTÉTICA Y ARMONIZACIÓN OROFACIAL ──
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF007A78).withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF007A78).withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.auto_awesome, color: Color(0xFF007A78), size: 20),
                SizedBox(width: 8),
                Text('Intereses en Armonización Facial y Estética', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF007A78))),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Procedimientos de interés del paciente:', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                'Lipopada de papada',
                'Bichectomía',
                'Toxina botulínica',
                'Carillas dentales',
                'Blanqueamiento láser',
              ].map((proc) {
                final isSel = _interesesEstetica.contains(proc);
                return FilterChip(
                  label: Text(proc, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.onSurface)),
                  selected: isSel,
                  selectedColor: const Color(0xFF007A78),
                  backgroundColor: AppColors.surfaceContainerLow,
                  onSelected: (sel) {
                    setState(() {
                      if (sel) {
                        _interesesEstetica.add(proc);
                      } else {
                        _interesesEstetica.remove(proc);
                      }
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            _buildSymptomSwitch(
              title: '¿Se ha realizado procedimientos estéticos antes?',
              subtitle: 'Toxina, rellenos, bichectomía previa u otros.',
              value: _procedimientosPreviosEstetica,
              onChanged: (v) => setState(() => _procedimientosPreviosEstetica = v),
            ),
            const SizedBox(height: 10),

            const Text('Zona de mayor prioridad estética:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
            const SizedBox(height: 6),
            DropdownButtonFormField<String>(
              value: _zonaPrioridadEstetica,
              decoration: _inputDecoration('Prioridad', Icons.face_retouching_natural),
              items: const [
                DropdownMenuItem(value: "Tercio inferior y perfil mandibular", child: Text("Tercio inferior y contorno mandibular")),
                DropdownMenuItem(value: "Sonrisa y dientes anteriores", child: Text("Diseño de sonrisa y dientes anteriores")),
                DropdownMenuItem(value: "Reducción de papada / grasa submentoniana", child: Text("Reducción de papada submentoniana")),
                DropdownMenuItem(value: "Líneas de expresión y arrugas", child: Text("Líneas de expresión y arrugas")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _zonaPrioridadEstetica = v);
              },
            ),
          ],
        ),
      );
    } else if (_motivoConsulta.contains('Ortodoncia')) {
      // ── CASO C: ORTODONCIA ──
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0056B3).withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF0056B3).withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.straighten_outlined, color: Color(0xFF0056B3), size: 20),
                SizedBox(width: 8),
                Text('Evaluación Ortodóntica Preliminar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0056B3))),
              ],
            ),
            const SizedBox(height: 12),
            _buildSymptomSwitch(
              title: '¿Ha usado ortodoncia o frenos anteriormente?',
              subtitle: 'Tratamientos previos de alineación dental.',
              value: _haUsadoOrtodoncia,
              onChanged: (v) => setState(() => _haUsadoOrtodoncia = v),
            ),
            const SizedBox(height: 12),

            const Text('Preferencia de tratamiento:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.textLight)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: ['Alineadores Invisibles', 'Brackets Metálicos', 'Brackets Zafiro/Cerámicos'].map((tipo) {
                final isSel = _tipoOrtodonciaDeseada == tipo;
                return ChoiceChip(
                  label: Text(tipo, style: TextStyle(fontSize: 11, color: isSel ? Colors.white : AppColors.onSurface)),
                  selected: isSel,
                  selectedColor: const Color(0xFF0056B3),
                  backgroundColor: AppColors.surfaceContainerLow,
                  onSelected: (s) => setState(() => _tipoOrtodonciaDeseada = tipo),
                );
              }).toList(),
            ),
          ],
        ),
      );
    } else if (_motivoConsulta.contains('Dolor Agudo') || _motivoConsulta.contains('Endodoncia')) {
      // ── CASO D: DOLOR AGUDO / ENDODONCIA ──
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.error.withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.error.withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.bolt, color: AppColors.error, size: 20),
                SizedBox(width: 8),
                Text('Urgencia & Evaluación del Dolor Dental', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.error)),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Intensidad del dolor: ${_intensidadDolorDental.round()} / 10',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            Slider(
              value: _intensidadDolorDental,
              min: 1,
              max: 10,
              divisions: 9,
              activeColor: AppColors.error,
              label: '${_intensidadDolorDental.round()}',
              onChanged: (v) => setState(() => _intensidadDolorDental = v),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _piezaAfectadaController,
              style: const TextStyle(color: AppColors.onSurface, fontSize: 14),
              decoration: _inputDecoration('Pieza o zona con dolor (ej. Muela superior derecha)', Icons.emergency_outlined),
            ),
          ],
        ),
      );
    } else if (_motivoConsulta.contains('Implantes') || _motivoConsulta.contains('Rehabilitación')) {
      // ── CASO E: REHABILITACIÓN / IMPLANTES ──
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF983C00).withOpacity(0.04),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFF983C00).withOpacity(0.3), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handyman_outlined, color: Color(0xFF983C00), size: 20),
                SizedBox(width: 8),
                Text('Requerimientos Protésicos / Implantes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF983C00))),
              ],
            ),
            const SizedBox(height: 12),
            _buildSymptomSwitch(
              title: '¿Presenta piezas dentales ausentes?',
              subtitle: 'Pérdida de dientes que requiere reposición fija o removible.',
              value: _tienePiezasFaltantes,
              onChanged: (v) => setState(() => _tienePiezasFaltantes = v),
            ),
            const SizedBox(height: 10),
            DropdownButtonFormField<String>(
              value: _necesidadProtesica,
              decoration: _inputDecoration('Tipo de prótesis deseada', Icons.build_circle_outlined),
              items: const [
                DropdownMenuItem(value: "Implante dental fijo unitario", child: Text("Implante dental fijo unitario")),
                DropdownMenuItem(value: "Puente fijo de circonio o porcelana", child: Text("Puente fijo de circonio/porcelana")),
                DropdownMenuItem(value: "Prótesis dental removible", child: Text("Prótesis dental removible")),
                DropdownMenuItem(value: "Rehabilitación completa", child: Text("Rehabilitación oral completa")),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _necesidadProtesica = v);
              },
            ),
          ],
        ),
      );
    } else {
      // ── CASO F: LIMPIEZA DENTAL & GENERAL ──
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.ghostOutline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.cleaning_services_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text('Antecedentes de Higiene y Prevención', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface)),
              ],
            ),
            const SizedBox(height: 12),
            _buildSymptomSwitch(
              title: '¿Presenta sangrado en encías al cepillarse?',
              subtitle: 'Signo de gingivitis o inflamación periodontal.',
              value: _sangradoEncias,
              onChanged: (v) => setState(() => _sangradoEncias = v),
            ),
            const SizedBox(height: 10),
            _buildSymptomSwitch(
              title: '¿Presenta sensibilidad dental con frío o dulce?',
              subtitle: 'Molestia transitoria ante estímulos térmicos.',
              value: _sensibilidadDental,
              onChanged: (v) => setState(() => _sensibilidadDental = v),
            ),
          ],
        ),
      );
    }
  }

  // ============================================================
  // PASO 2: CONFIRMACIÓN Y RESUMEN DEL EXPEDIENTE
  // ============================================================
  Widget _buildStep2Confirmacion() {
    final edad = _calcularEdad(_fechaNacimiento);

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con Avatar
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer]),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    _nombreController.text.isNotEmpty ? _nombreController.text[0].toUpperCase() : 'P',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 22),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_nombreController.text} ${_apellidoController.text}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$edad años ($_genero) • ${_telefonoController.text}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(height: 1, color: AppColors.ghostOutline),
          const SizedBox(height: 16),

          // Resumen de Identificación
          const Text('INFORMACIÓN DE IDENTIFICACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildSummaryRow('Teléfono / WhatsApp', '$_codigoPais ${_telefonoController.text}'),
          if (_emailController.text.isNotEmpty) _buildSummaryRow('Correo Electrónico', _emailController.text),
          if (_dpiController.text.isNotEmpty) _buildSummaryRow('DPI / Cédula', _dpiController.text),
          if (_direccionController.text.isNotEmpty) _buildSummaryRow('Dirección', _direccionController.text),
          if (_contactoEmergenciaController.text.isNotEmpty)
            _buildSummaryRow('Contacto Emergencia', '${_contactoEmergenciaController.text} (${_telEmergenciaController.text})'),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.ghostOutline),
          const SizedBox(height: 16),

          // Resumen de Salud
          const Text('ANTECEDENTES MÉDICOS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildSummaryRow('Alergias', _alergias),
          _buildSummaryRow('Condición Sistémica', _condicionMedica),
          if (_medicacionActualController.text.isNotEmpty)
            _buildSummaryRow('Medicamentos Actuales', _medicacionActualController.text),

          const SizedBox(height: 16),
          const Divider(height: 1, color: AppColors.ghostOutline),
          const SizedBox(height: 16),

          // Resumen del Motivo y Cuestionario Dinámico
          const Text('MOTIVO DE CONSULTA Y EVALUACIÓN', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary, letterSpacing: 0.5)),
          const SizedBox(height: 8),
          _buildSummaryRow('Motivo Principal', _motivoConsulta),

          if (_motivoConsulta.contains('ATM')) ...[
            _buildSummaryRow('Apretamiento / Bruxismo', _tieneBruxismo ? 'Sí' : 'No'),
            _buildSummaryRow('Chasquidos / Ruido Articular', _tieneChasquido ? 'Sí' : 'No'),
            _buildSummaryRow('Dolores de Cabeza / Cuello', _tieneDolorCabeza ? 'Sí' : 'No'),
            _buildSummaryRow('Limitación de Apertura', _tieneLimitacionApertura ? 'Sí' : 'No'),
            _buildSummaryRow('Rigidez al Despertar', _despiertaConTension ? 'Sí' : 'No'),
            _buildSummaryRow('Escala de Dolor ATM', '${_nivelDolorATM.round()} / 10'),
            _buildSummaryRow('Tiempo de Evolución', _tiempoSintomasATM),
          ] else if (_motivoConsulta.contains('Estética')) ...[
            _buildSummaryRow('Procedimientos de Interés', _interesesEstetica.join(', ')),
            _buildSummaryRow('Procedimientos Previos', _procedimientosPreviosEstetica ? 'Sí' : 'No'),
            _buildSummaryRow('Zona Prioritaria', _zonaPrioridadEstetica),
          ] else if (_motivoConsulta.contains('Ortodoncia')) ...[
            _buildSummaryRow('Ortodoncia Previa', _haUsadoOrtodoncia ? 'Sí' : 'No'),
            _buildSummaryRow('Preferencia', _tipoOrtodonciaDeseada),
          ] else if (_motivoConsulta.contains('Dolor Agudo')) ...[
            _buildSummaryRow('Intensidad de Dolor', '${_intensidadDolorDental.round()} / 10'),
            if (_piezaAfectadaController.text.isNotEmpty) _buildSummaryRow('Pieza Afectada', _piezaAfectadaController.text),
          ] else if (_motivoConsulta.contains('Implantes')) ...[
            _buildSummaryRow('Piezas Ausentes', _tienePiezasFaltantes ? 'Sí' : 'No'),
            _buildSummaryRow('Tipo Prótesis', _necesidadProtesica),
          ] else ...[
            _buildSummaryRow('Sangrado de Encías', _sangradoEncias ? 'Sí' : 'No'),
            _buildSummaryRow('Sensibilidad Dental', _sensibilidadDental ? 'Sí' : 'No'),
          ],
        ],
      ),
    );
  }

  // ---- HELPERS DE INTERFAZ ----
  Widget _buildCardSection({
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 18, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(icono, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(titulo, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                    Text(subtitulo, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
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
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide.none),
    );
  }

  Widget _buildSymptomSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
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

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
          const SizedBox(width: 14),
          Flexible(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.onSurface),
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
      labelStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
      errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
    );
  }
}
