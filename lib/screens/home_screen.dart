import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'fonseca_test_screen.dart';
import 'patient_register_screen.dart';
import 'quick_evaluation_screen.dart';
import 'prescription_screen.dart';
import 'inventory_screen.dart';
import 'appointments_screen.dart';
import 'reports.dart';
import '../models/reporte.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';
import 'help_screen.dart';
import 'patient_history_screen.dart';
import 'patient_directory_screen.dart';
import '../models/paciente.dart';
import '../services/firestore_service.dart';
import '../constants/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  final List<Reporte> _reportes = [];
  final FirestoreService _firestoreService = FirestoreService();
  Paciente? _pacienteEjemplo;
  double _primaryBtnScale = 1.0;

  String _doctorNombre = 'Especialista Odontología';
  String _doctorEmail = 'doctor@rizodental.com';
  String _doctorEspecialidad = 'Especialista en Disfunción ATM';

  @override
  void initState() {
    super.initState();
    _cargarPacienteEjemplo();
    _cargarDatosDoctor();
  }

  Future<void> _cargarDatosDoctor() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        if (user.email != null && user.email!.isNotEmpty) {
          _doctorEmail = user.email!;
        }

        var res = await Supabase.instance.client
            .from('users')
            .select()
            .eq('id', user.id)
            .maybeSingle();

        if (res == null && user.email != null) {
          res = await Supabase.instance.client
              .from('users')
              .select()
              .eq('email', user.email!)
              .maybeSingle();
        }

        if (res != null) {
          final data = Map<String, dynamic>.from(res);
          setState(() {
            if (data['name'] != null && data['name'].toString().isNotEmpty) {
              _doctorNombre = data['name'];
            }
            if (data['email'] != null && data['email'].toString().isNotEmpty) {
              _doctorEmail = data['email'];
            }
            if (data['especialidad'] != null && data['especialidad'].toString().isNotEmpty) {
              _doctorEspecialidad = data['especialidad'];
            }
          });
        } else {
          final String userMetaName = user.userMetadata?['full_name'] ?? user.userMetadata?['name'] ?? '';
          if (userMetaName.isNotEmpty) {
            setState(() {
              _doctorNombre = userMetaName;
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error al cargar datos del doctor en HomeScreen: $e');
    }
  }

  Future<void> _cargarPacienteEjemplo() async {
    const pacienteId = 'paciente_demo';
    Paciente? paciente = await _firestoreService.obtenerPaciente(pacienteId);
    setState(() {
      _pacienteEjemplo = paciente;
    });
  }

  Future<void> _guardarPacienteEjemplo() async {
    const pacienteId = 'paciente_demo';
    Paciente paciente = Paciente(
      id: pacienteId,
      nombre: 'Juan',
      apellido: 'Pérez',
      email: 'juan.perez@email.com',
      telefono: '555-1234',
      fechaNacimiento: DateTime(1990, 5, 20),
      genero: 'Masculino',
      direccion: 'Ciudad de Guatemala',
    );
    await _firestoreService.guardarPaciente(paciente);
    setState(() {
      _pacienteEjemplo = paciente;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Paciente de ejemplo sincronizado en Supabase'),
          backgroundColor: AppColors.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        break;
      case 1:
        _showEvaluationOptions();
        break;
      case 2:
        _showReports();
        break;
      case 3:
        _showSettings();
        break;
    }
  }

  void _showEvaluationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(28),
          decoration: const BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: AppColors.shadowSoft,
                blurRadius: 24,
                offset: Offset(0, -8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.ghostOutline,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Opciones de Evaluación',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Selecciona el tipo de diagnóstico a realizar',
                style: TextStyle(fontSize: 13, color: AppColors.textLight),
              ),
              const SizedBox(height: 24),
              
              // Evaluation Card 0: Registrar Paciente
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
                  ),
                  title: const Text(
                    'Registrar Nuevo Paciente',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  subtitle: const Text(
                    'Crear expediente clínico de 3 pasos en Supabase',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  onTap: () async {
                    Navigator.pop(context);
                    final paciente = await Navigator.push<Paciente>(
                      context,
                      MaterialPageRoute(builder: (context) => const PatientRegisterScreen()),
                    );
                    if (paciente != null) {
                      setState(() {
                        _pacienteEjemplo = paciente;
                      });
                    }
                  },
                ),
              ),

              // Evaluation Card 1
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.assessment_outlined, color: AppColors.primaryContainer),
                  ),
                  title: const Text(
                    'Test de Fonseca (ATM)',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  subtitle: const Text(
                    'Evaluación clínica de disfunción temporomandibular',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _startFonsecaTest();
                  },
                ),
              ),

              // Evaluation Card 2: Evaluación Rápida
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.speed_outlined, color: AppColors.primary),
                  ),
                  title: const Text(
                    'Evaluación Rápida ATM',
                    style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
                  ),
                  subtitle: const Text(
                    'Screening exprés de 5 factores de riesgo en consulta',
                    style: TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => const QuickEvaluationScreen()),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  void _showReports() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReportsScreen(reportes: _reportes),
      ),
    );
  }

  void _addReport(int score, String diagnosis) {
    setState(() {
      _reportes.add(
        Reporte(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pacienteId: _pacienteEjemplo?.id ?? 'desconocido',
          fecha: DateTime.now(),
          tipo: 'fonseca',
          contenido: 'Puntuación: $score, Diagnóstico: $diagnosis',
        ),
      );
    });
  }

  void _startFonsecaTest() async {
    final result = await Navigator.push<Map<String, dynamic>>(
      context,
      MaterialPageRoute(
        builder: (context) => const FonsecaTestScreen(),
      ),
    );
    if (result != null &&
        result.containsKey('score') &&
        result.containsKey('diagnosis')) {
      _addReport(result['score'], result['diagnosis']);
    }
  }

  void _showSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }

  void _showFeatureInDevelopment() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚧 Función clínica en desarrollo'),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Cerrar Sesión',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          content: const Text(
            '¿Estás seguro de que deseas salir del Santuario Clínico?',
            style: TextStyle(color: AppColors.textLight),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(color: AppColors.textLight),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.error,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Cerrar Sesión'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final String nombreUsuario = _pacienteEjemplo != null
        ? '${_pacienteEjemplo!.nombre} ${_pacienteEjemplo!.apellido}'
        : 'Dr. Usuario Rizo';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(
          children: [
            Image.asset(
              'assets/images/rizo_logo.png',
              height: 36,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.medical_services,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'RIZO DENTAL',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: AppColors.primary,
                  ),
                ),
                Text(
                  'The Clinical Sanctuary',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            color: AppColors.surfaceContainerLowest,
            onSelected: (String value) {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ProfileScreen()),
                  );
                  break;
                case 'help':
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HelpScreen()),
                  );
                  break;
                case 'logout':
                  _logout();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              const PopupMenuItem<String>(
                value: 'profile',
                child: ListTile(
                  leading: Icon(Icons.person_outline, color: AppColors.primary),
                  title: Text('Perfil del Especialista'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem<String>(
                value: 'help',
                child: ListTile(
                  leading: Icon(Icons.help_outline, color: AppColors.primary),
                  title: Text('Centro de Ayuda'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: ListTile(
                  leading: Icon(Icons.logout, color: AppColors.error),
                  title: Text(
                    'Cerrar Sesión',
                    style: TextStyle(color: AppColors.error),
                  ),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Patient & Specialist Profile Card (Asymmetry & Precision Layering)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(24), // xl radius
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowSoft,
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryContainer],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                      ),
                      child: const CircleAvatar(
                        radius: 28,
                        backgroundColor: AppColors.surfaceContainerLow,
                        child: Icon(
                          Icons.person,
                          size: 32,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _doctorNombre,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _doctorEmail,
                            style: const TextStyle(
                              color: AppColors.textLight,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              _doctorEspecialidad,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.sync, color: AppColors.primary),
                      tooltip: 'Sincronizar Paciente',
                      onPressed: _guardarPacienteEjemplo,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Clinical Metrics Summary (Precision Layering)
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 20),
                              ),
                              Text(
                                '${_reportes.length}',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Evaluaciones',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          const Text(
                            'Realizadas en la app',
                            style: TextStyle(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.success.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.health_and_safety_outlined, color: AppColors.success, size: 20),
                              ),
                              const Text(
                                'ATM',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Diagnóstico',
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          const Text(
                            'Test Fonseca listo',
                            style: TextStyle(fontSize: 11, color: AppColors.textLight),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),

              // Main Assessment Action Module (Clinical Sanctuary Signature Card)
              Container(
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
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.06),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medical_services_outlined,
                        size: 64,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Evaluación de Disfunción ATM',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Test Anamnésico de Fonseca para medir el grado de gravedad de la articulación temporomandibular.',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textLight,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 28),

                    // Primary Gradient Pill Button with Scale Micro-Animation
                    GestureDetector(
                      onTapDown: (_) => setState(() => _primaryBtnScale = 0.98),
                      onTapUp: (_) => setState(() => _primaryBtnScale = 1.0),
                      onTapCancel: () => setState(() => _primaryBtnScale = 1.0),
                      child: AnimatedScale(
                        scale: _primaryBtnScale,
                        duration: const Duration(milliseconds: 120),
                        child: Container(
                          width: double.infinity,
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
                            onPressed: _startFonsecaTest,
                            icon: const Icon(Icons.assessment, size: 22, color: Colors.white),
                            label: const Text(
                              'Iniciar Test de Fonseca',
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
                    const SizedBox(height: 16),

                    // Secondary Outlined History Button
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _showReports,
                            icon: const Icon(Icons.history, size: 18, color: AppColors.primary),
                            label: const Text(
                              'Diagnósticos',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              backgroundColor: AppColors.surfaceContainerLowest,
                              side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientDirectoryScreen()));
                            },
                            icon: const Icon(Icons.folder_shared_outlined, size: 18, color: Colors.white),
                            label: const Text(
                              'Directorio 360°',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Módulos Clínicos Sanctuary (Grid de Acceso Rápido)
              const Text(
                'Módulos Clínicos Sanctuary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 14),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  // Card 1: Directorio de Pacientes & Expediente 360°
                  _buildDashboardModuleCard(
                    title: 'Directorio Pacientes',
                    subtitle: 'Expediente & Histórico 360°',
                    icon: Icons.folder_shared_outlined,
                    color: AppColors.primary,
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientDirectoryScreen()));
                    },
                  ),

                  // Card 2: Receta Médica
                  _buildDashboardModuleCard(
                    title: 'Receta Médica',
                    subtitle: 'Firma digital & WhatsApp',
                    icon: Icons.medical_services_outlined,
                    color: const Color(0xFF0056B3),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PrescriptionScreen()));
                    },
                  ),

                  // Card 3: Inventario
                  _buildDashboardModuleCard(
                    title: 'Inventario Clínico',
                    subtitle: 'Insumos & Alertas Stock',
                    icon: Icons.inventory_2_outlined,
                    color: const Color(0xFF007A78),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const InventoryScreen()));
                    },
                  ),

                  // Card 4: Gestión de Citas
                  _buildDashboardModuleCard(
                    title: 'Gestión de Citas',
                    subtitle: 'Agenda & Recordatorios WA',
                    icon: Icons.calendar_month_outlined,
                    color: const Color(0xFF983C00),
                    onTap: () {
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const AppointmentsScreen()));
                    },
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),

      // Glassmorphic Floating Navigation Bar
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withOpacity(0.92),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 24,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: AppColors.primary,
            unselectedItemColor: AppColors.textLight,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: 11,
            ),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined),
                activeIcon: Icon(Icons.home),
                label: 'Inicio',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.assessment_outlined),
                activeIcon: Icon(Icons.assessment),
                label: 'Evaluar',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.bar_chart_outlined),
                activeIcon: Icon(Icons.bar_chart),
                label: 'Reportes',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.settings_outlined),
                activeIcon: Icon(Icons.settings),
                label: 'Config',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardModuleCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(24),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowSoft,
              blurRadius: 18,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textLight,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
