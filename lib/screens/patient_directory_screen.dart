import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/paciente.dart';
import '../constants/colors.dart';
import '../utils/pdf_generator.dart';
import 'patient_register_screen.dart';
import 'fonseca_test_screen.dart';
import 'appointments_screen.dart';
import 'prescription_screen.dart';

class PatientDirectoryScreen extends StatefulWidget {
  final Paciente? selectedPatient;

  const PatientDirectoryScreen({super.key, this.selectedPatient});

  @override
  State<PatientDirectoryScreen> createState() => _PatientDirectoryScreenState();
}

class _PatientDirectoryScreenState extends State<PatientDirectoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Paciente> _allPacientes = [];
  List<Paciente> _filteredPacientes = [];
  Paciente? _selectedPaciente;
  bool _isLoadingPacientes = true;

  List<Map<String, dynamic>> _evaluaciones = [];
  List<Map<String, dynamic>> _recetas = [];
  List<Map<String, dynamic>> _citas = [];
  bool _isLoadingHistorial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController.addListener(_filterPacientes);
    _cargarPacientes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _filterPacientes() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredPacientes = List.from(_allPacientes);
      } else {
        _filteredPacientes = _allPacientes.where((p) {
          final nameMatch = p.nombre.toLowerCase().contains(query);
          final lastNameMatch = p.apellido.toLowerCase().contains(query);
          final phoneMatch = p.telefono.contains(query);
          final emailMatch = p.email.toLowerCase().contains(query);
          return nameMatch || lastNameMatch || phoneMatch || emailMatch;
        }).toList();
      }
    });
  }

  Future<void> _cargarPacientes() async {
    setState(() => _isLoadingPacientes = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('pacientes').select().order('nombre');
      final list = (response as List)
          .map((p) => Paciente.fromMap(Map<String, dynamic>.from(p), p['id'].toString()))
          .toList();

      setState(() {
        _allPacientes = list;
        _filteredPacientes = List.from(list);
        if (widget.selectedPatient != null) {
          _selectedPaciente = list.firstWhere(
            (p) => p.id == widget.selectedPatient!.id,
            orElse: () => widget.selectedPatient!,
          );
        } else if (list.isNotEmpty) {
          _selectedPaciente = list.first;
        }
      });

      if (_selectedPaciente != null) {
        _cargarHistorialPaciente(_selectedPaciente!);
      }
    } catch (e) {
      debugPrint('Error al cargar directorio de pacientes: $e');
    } finally {
      if (mounted) setState(() => _isLoadingPacientes = false);
    }
  }

  Future<void> _cargarHistorialPaciente(Paciente paciente) async {
    setState(() => _isLoadingHistorial = true);
    final supabase = Supabase.instance.client;

    try {
      // 1. Evaluaciones ATM / Fonseca
      final evalResponse = await supabase
          .from('evaluaciones')
          .select()
          .or('paciente_id.eq.${paciente.id},paciente_nombre.ilike.%${paciente.nombre}%')
          .order('created_at', ascending: false);

      // 2. Recetas Médicas
      final recetasResponse = await supabase
          .from('recetas')
          .select()
          .or('paciente_id.eq.${paciente.id},paciente_nombre.ilike.%${paciente.nombre}%')
          .order('created_at', ascending: false);

      // 3. Citas Médicas
      final citasResponse = await supabase
          .from('citas')
          .select()
          .or('paciente_id.eq.${paciente.id},paciente_nombre.ilike.%${paciente.nombre}%')
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _evaluaciones = List<Map<String, dynamic>>.from(evalResponse);
          _recetas = List<Map<String, dynamic>>.from(recetasResponse);
          _citas = List<Map<String, dynamic>>.from(citasResponse);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar expediente del paciente: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistorial = false);
    }
  }

  String _cleanPhoneForWhatsApp(String phone) {
    String clean = phone.replaceAll(RegExp(r'[^\d]'), '');
    if (!clean.startsWith('502') && clean.length == 8) {
      clean = '502$clean';
    }
    return clean;
  }

  void _abrirWhatsApp(String phone, String mensaje) async {
    final cleanPhone = _cleanPhoneForWhatsApp(phone);
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No se pudo abrir WhatsApp para el número $cleanPhone'),
          backgroundColor: AppColors.error,
        ),
      );
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

  int _calcularEdad(DateTime fechaNacimiento) {
    final now = DateTime.now();
    int age = now.year - fechaNacimiento.year;
    if (now.month < fechaNacimiento.month || (now.month == fechaNacimiento.month && now.day < fechaNacimiento.day)) {
      age--;
    }
    return age < 0 ? 0 : age;
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
        title: const Column(
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
              'Directorio de Pacientes • Expediente Clínico 360°',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_alt_1_outlined, color: AppColors.primary),
            tooltip: 'Registrar Nuevo Paciente',
            onPressed: () async {
              final nuevoPaciente = await Navigator.push<Paciente>(
                context,
                MaterialPageRoute(builder: (context) => const PatientRegisterScreen()),
              );
              if (nuevoPaciente != null) {
                _cargarPacientes();
              }
            },
          ),
        ],
      ),
      body: _isLoadingPacientes
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Search Bar & Directory Selector Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Search TextField
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppColors.onSurface),
                        decoration: InputDecoration(
                          hintText: 'Buscar paciente por nombre, teléfono o correo...',
                          hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                          prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                          filled: true,
                          fillColor: AppColors.surfaceContainerLow,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline, width: 1.0)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Patient Selector Dropdown
                      const Text(
                        'Directorio de Pacientes Registrados',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.textLight),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.ghostOutline, width: 1.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Paciente>(
                            value: _selectedPaciente,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                            items: _filteredPacientes.map((p) {
                              return DropdownMenuItem<Paciente>(
                                value: p,
                                child: Text(
                                  '${p.nombre} ${p.apellido} • Tel: ${p.telefono}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (p) {
                              if (p != null) {
                                setState(() => _selectedPaciente = p);
                                _cargarHistorialPaciente(p);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_selectedPaciente != null) ...[
                  // Patient Profile Banner Card (Asymmetry & Soft Minimalism)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryContainer],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
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
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: Colors.white.withOpacity(0.2),
                              child: Text(
                                _selectedPaciente!.nombre.isNotEmpty
                                    ? _selectedPaciente!.nombre[0].toUpperCase()
                                    : 'P',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${_selectedPaciente!.nombre} ${_selectedPaciente!.apellido}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_calcularEdad(_selectedPaciente!.fechaNacimiento)} años (${_selectedPaciente!.genero}) • ${_selectedPaciente!.telefono}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_selectedPaciente!.email.isNotEmpty)
                                    Text(
                                      _selectedPaciente!.email,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            // Direct WhatsApp Button
                            IconButton(
                              icon: const Icon(Icons.chat_outlined, color: Colors.white),
                              tooltip: 'Contactar por WhatsApp (+502)',
                              onPressed: () {
                                _abrirWhatsApp(
                                  _selectedPaciente!.telefono,
                                  'Hola ${_selectedPaciente!.nombre}, le saludamos de la clínica Rizo Dental.',
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Action Bar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildQuickActionButton(
                              icon: Icons.assignment_turned_in_outlined,
                              label: 'Test Fonseca',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const FonsecaTestScreen()),
                                ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                              },
                            ),
                            _buildQuickActionButton(
                              icon: Icons.medication_outlined,
                              label: 'Nueva Receta',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PrescriptionScreen()),
                                ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                              },
                            ),
                            _buildQuickActionButton(
                              icon: Icons.calendar_month_outlined,
                              label: 'Agendar Cita',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AppointmentsScreen()),
                                ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tab Bar (Clinical Sanctuary Navigation)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorColor: AppColors.primary,
                      labelColor: AppColors.primary,
                      unselectedLabelColor: AppColors.textLight,
                      isScrollable: true,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
                        Tab(text: 'Ficha Clínica'),
                        Tab(text: 'Evaluaciones ATM'),
                        Tab(text: 'Recetas Médicas'),
                        Tab(text: 'Citas Médicas'),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // Tab Views
                  Expanded(
                    child: _isLoadingHistorial
                        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                        : TabBarView(
                            controller: _tabController,
                            children: [
                              _buildFichaClinicaTab(),
                              _buildEvaluacionesTab(),
                              _buildRecetasTab(),
                              _buildCitasTab(),
                            ],
                          ),
                  ),
                ],
              ],
            ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 15),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // TAB 1: FICHA CLÍNICA DEL PACIENTE
  Widget _buildFichaClinicaTab() {
    final p = _selectedPaciente!;
    final fechaStr = '${p.fechaNacimiento.day}/${p.fechaNacimiento.month}/${p.fechaNacimiento.year}';

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Container(
        padding: const EdgeInsets.all(22),
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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Expediente Clínico del Paciente',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 4),
            const Text(
              'Datos personales e identificación registrados en Supabase',
              style: TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 18),

            _buildDetailRow(Icons.person_outline, 'Nombre Completo', '${p.nombre} ${p.apellido}'),
            _buildDetailRow(Icons.cake_outlined, 'Fecha de Nacimiento', '$fechaStr (${_calcularEdad(p.fechaNacimiento)} años)'),
            _buildDetailRow(Icons.wc_outlined, 'Género', p.genero),
            _buildDetailRow(Icons.phone_outlined, 'Teléfono / WhatsApp', p.telefono),
            _buildDetailRow(Icons.email_outlined, 'Correo Electrónico', p.email.isNotEmpty ? p.email : 'No registrado'),
            _buildDetailRow(Icons.location_on_outlined, 'Dirección de Residencia', p.direccion.isNotEmpty ? p.direccion : 'No registrada'),

            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Resumen de Historial Clínico',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Evaluaciones ATM: ${_evaluaciones.length} • Recetas: ${_recetas.length} • Citas: ${_citas.length}',
                          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.onSurface)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // TAB 2: EVALUACIONES ATM
  Widget _buildEvaluacionesTab() {
    if (_evaluaciones.isEmpty) {
      return _buildEmptyState('No hay evaluaciones de Fonseca (ATM) registradas para este paciente.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _evaluaciones.length,
      itemBuilder: (context, index) {
        final eval = _evaluaciones[index];
        final String diagnostico = eval['diagnostico'] ?? 'Diagnóstico de Fonseca';
        final int score = eval['puntuacion'] ?? 0;
        final String fecha = eval['fecha'] != null
            ? eval['fecha'].toString().split('T')[0]
            : (eval['created_at'] != null ? eval['created_at'].toString().split('T')[0] : 'Fecha Reciente');

        final colorSeverity = _getSeverityColor(diagnostico);

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: colorSeverity.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      diagnostico,
                      style: TextStyle(
                        color: colorSeverity,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Text(
                    'Puntuación: $score/100',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Fecha de Evaluación: $fecha',
                style: const TextStyle(fontSize: 12, color: AppColors.textLight),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    PdfGenerator.generarPdfFonseca(
                      paciente: _selectedPaciente!,
                      score: score,
                      diagnostico: diagnostico,
                      preguntas: const [],
                      doctorInfo: const {
                        'name': 'Dra. María Rizo',
                        'colegiado': '12345',
                        'especialidad': 'Especialista ATM & Odontología',
                        'firma_digital': 'Firma Digital Rizo Dental',
                      },
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Exportar PDF de Evaluación ATM', style: TextStyle(fontSize: 12, color: AppColors.primary)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ghostOutline, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 3: RECETAS MÉDICAS
  Widget _buildRecetasTab() {
    if (_recetas.isEmpty) {
      return _buildEmptyState('No se han emitido recetas médicas para este paciente.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _recetas.length,
      itemBuilder: (context, index) {
        final receta = _recetas[index];
        final String fecha = receta['fecha'] != null
            ? receta['fecha'].toString().split('T')[0]
            : (receta['created_at'] != null ? receta['created_at'].toString().split('T')[0] : 'Fecha Reciente');
        final String medicamentosTexto = receta['medicamentos'] ?? 'Medicamentos prescritos';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.medication_outlined, color: AppColors.primary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Receta Médica Oficial',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                      ),
                    ],
                  ),
                  Text(
                    fecha,
                    style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  medicamentosTexto,
                  style: const TextStyle(fontSize: 13, color: AppColors.onSurface, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        PdfGenerator.generarPdfReceta(
                          paciente: _selectedPaciente!,
                          medicamentos: [
                            {
                              'nombre': 'Prescripción Médica Rizo Dental',
                              'dosis': medicamentosTexto,
                              'frecuencia': receta['indicaciones'] ?? 'Según indicación',
                              'duracion': 'Ver indicación'
                            }
                          ],
                          indicaciones: receta['indicaciones'] ?? 'Tomar según prescripción clínica.',
                          doctorInfo: const {
                            'name': 'Dra. María Rizo',
                            'colegiado': '12345',
                            'especialidad': 'Especialista ATM & Odontología',
                            'firma_digital': 'Firma Digital Rizo Dental',
                          },
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
                      label: const Text('PDF Receta', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.ghostOutline, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _abrirWhatsApp(
                          _selectedPaciente!.telefono,
                          'Hola ${_selectedPaciente!.nombre}, adjuntamos su Receta Médica emitida en Rizo Dental:\n\n$medicamentosTexto',
                        );
                      },
                      icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
                      label: const Text('Enviar WhatsApp', style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 4: CITAS MÉDICAS
  Widget _buildCitasTab() {
    if (_citas.isEmpty) {
      return _buildEmptyState('No hay historial de citas registradas para este paciente.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _citas.length,
      itemBuilder: (context, index) {
        final cita = _citas[index];
        final String motivo = cita['motivo'] ?? 'Consulta Clínica Odontológica';
        final String fecha = cita['fecha'] ?? 'Fecha Programada';
        final String hora = cita['hora'] ?? 'Hora';
        final String estado = cita['estado'] ?? 'Confirmada';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(20),
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      motivo,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      estado,
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.event_outlined, size: 16, color: AppColors.textLight),
                  const SizedBox(width: 6),
                  Text('Fecha: $fecha', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                  const SizedBox(width: 16),
                  const Icon(Icons.access_time, size: 16, color: AppColors.textLight),
                  const SizedBox(width: 6),
                  Text('Hora: $hora', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        PdfGenerator.generarPdfCita(
                          paciente: _selectedPaciente!,
                          fechaHora: '$fecha a las $hora',
                          motivo: motivo,
                          notas: 'Por favor asistir 10 minutos antes a la clínica Rizo Dental.',
                          estado: estado,
                          doctorInfo: const {
                            'name': 'Dra. María Rizo',
                            'colegiado': '12345',
                            'especialidad': 'Especialista ATM & Odontología',
                            'firma_digital': 'Firma Digital Rizo Dental',
                          },
                        );
                      },
                      icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
                      label: const Text('PDF Cita', style: TextStyle(fontSize: 11, color: AppColors.primary)),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.ghostOutline, width: 1.0),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        _abrirWhatsApp(
                          _selectedPaciente!.telefono,
                          'Hola ${_selectedPaciente!.nombre}, te recordamos tu cita odontológica para $motivo el día $fecha a las $hora.',
                        );
                      },
                      icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
                      label: const Text('Recordatorio WA', style: TextStyle(fontSize: 11, color: Colors.white)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF25D366),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(String mensaje) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                color: AppColors.surfaceContainerLow,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.folder_open_outlined, size: 48, color: AppColors.textLight),
            ),
            const SizedBox(height: 16),
            Text(
              mensaje,
              style: const TextStyle(color: AppColors.textLight, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
