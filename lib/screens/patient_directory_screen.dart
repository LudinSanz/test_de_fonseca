import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/paciente.dart';
import '../models/examen_clinico.dart';
import '../constants/colors.dart';
import '../utils/pdf_generator.dart';
import 'patient_register_screen.dart';
import 'fonseca_test_screen.dart';
import 'appointments_screen.dart';
import 'prescription_screen.dart';
import 'upload_exam_screen.dart';
import 'exam_viewer_screen.dart';
import 'treatments_screen.dart';
import '../services/supabase_service.dart';

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
  List<Map<String, dynamic>> _tratamientos = [];
  List<ExamenClinico> _examenes = [];
  String _filtroTipoExamen = 'todos';
  bool _isLoadingHistorial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
      final supabaseService = SupabaseService();
      final list = await supabaseService.obtenerPacientes();

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
    final supabaseService = SupabaseService();

    try {
      final results = await Future.wait([
        supabaseService.obtenerEvaluaciones(pacienteId: paciente.id),
        supabaseService.obtenerRecetas(pacienteId: paciente.id),
        supabaseService.obtenerCitas(pacienteId: paciente.id),
        supabaseService.obtenerExamenes(pacienteId: paciente.id),
        supabaseService.obtenerTratamientos(pacienteId: paciente.id),
      ]);

      if (mounted) {
        setState(() {
          _evaluaciones = results[0] as List<Map<String, dynamic>>;
          _recetas = results[1] as List<Map<String, dynamic>>;
          _citas = results[2] as List<Map<String, dynamic>>;
          _examenes = results[3] as List<ExamenClinico>;
          _tratamientos = results[4] as List<Map<String, dynamic>>;
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

  void _imprimirExpedienteCompleto() async {
    if (_selectedPaciente == null) return;
    try {
      final supabaseService = SupabaseService();
      String emailOrId = '';
      try {
        final u = Supabase.instance.client.auth.currentUser;
        if (u != null) emailOrId = u.email ?? u.id;
      } catch (_) {}
      final doctorInfo = await supabaseService.obtenerPerfilDoctor(emailOrId);

      await PdfGenerator.generarPdfExpedienteCompleto(
        paciente: _selectedPaciente!,
        evaluaciones: _evaluaciones,
        citas: _citas,
        recetas: _recetas,
        tratamientos: _tratamientos,
        examenes: _examenes,
        doctorInfo: doctorInfo,
      );
    } catch (e) {
      debugPrint('Error al imprimir expediente completo: $e');
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
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
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
                              const SizedBox(width: 8),
                              _buildQuickActionButton(
                                icon: Icons.medical_services_outlined,
                                label: 'Tratamientos & Estética',
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => TreatmentsScreen(paciente: _selectedPaciente!)),
                                  ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                                },
                              ),
                              const SizedBox(width: 8),
                              _buildQuickActionButton(
                                icon: Icons.cloud_upload_outlined,
                                label: 'Subir Examen',
                                onTap: () async {
                                  final nuevo = await Navigator.push<ExamenClinico>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UploadExamScreen(paciente: _selectedPaciente!),
                                    ),
                                  );
                                  if (nuevo != null) {
                                    _cargarHistorialPaciente(_selectedPaciente!);
                                  }
                                },
                              ),
                              const SizedBox(width: 8),
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
                              const SizedBox(width: 8),
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
                              const SizedBox(width: 8),
                              _buildQuickActionButton(
                                icon: Icons.picture_as_pdf_outlined,
                                label: 'Expediente PDF',
                                onTap: _imprimirExpedienteCompleto,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Tab Bar (Navegaci�n)
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
                      tabs: [
                        const Tab(text: 'Ficha Clínica'),
                        Tab(text: 'Tratamientos (${_tratamientos.length})'),
                        Tab(text: 'Exámenes & Rayos X (${_examenes.length})'),
                        Tab(text: 'Evaluaciones ATM (${_evaluaciones.length})'),
                        Tab(text: 'Recetas (${_recetas.length})'),
                        Tab(text: 'Citas (${_citas.length})'),
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
                              _buildTratamientosTab(),
                              _buildExamenesTab(),
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
                          'Exámenes & Rayos X: ${_examenes.length} • Consultas: ${_evaluaciones.length} • Recetas: ${_recetas.length} • Citas: ${_citas.length}',
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

  // TAB 2: EXÁMENES & RADIOGRAFÍAS 360°
  Widget _buildExamenesTab() {
    List<ExamenClinico> listaFiltrada = _examenes;
    if (_filtroTipoExamen != 'todos') {
      listaFiltrada = _examenes.where((e) => e.tipo == _filtroTipoExamen).toList();
    }

    return Column(
      children: [
        // Action & Filter Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildExamenFilterChip('Todos (${_examenes.length})', 'todos'),
                      const SizedBox(width: 6),
                      _buildExamenFilterChip('🩻 Rayos X', 'radiografia'),
                      const SizedBox(width: 6),
                      _buildExamenFilterChip('📄 PDFs', 'pdf'),
                      const SizedBox(width: 6),
                      _buildExamenFilterChip('📷 Fotos', 'imagen'),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: () async {
                  final nuevo = await Navigator.push<ExamenClinico>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => UploadExamScreen(paciente: _selectedPaciente!),
                    ),
                  );
                  if (nuevo != null) {
                    _cargarHistorialPaciente(_selectedPaciente!);
                  }
                },
                icon: const Icon(Icons.add_photo_alternate_outlined, size: 16, color: Colors.white),
                label: const Text('Subir', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),

        // List or Empty
        Expanded(
          child: listaFiltrada.isEmpty
              ? _buildEmptyExamenesState()
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: listaFiltrada.length,
                  itemBuilder: (context, index) {
                    final examen = listaFiltrada[index];
                    return _buildExamenCard(examen);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildExamenFilterChip(String label, String value) {
    final isSelected = _filtroTipoExamen == value;
    return GestureDetector(
      onTap: () => setState(() => _filtroTipoExamen = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.ghostOutline,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : AppColors.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildExamenCard(ExamenClinico examen) {
    final fechaStr = '${examen.fecha.day}/${examen.fecha.month}/${examen.fecha.year}';
    Color badgeColor;
    IconData badgeIcon;

    switch (examen.tipo.toLowerCase()) {
      case 'radiografia':
        badgeColor = const Color(0xFF0284C7);
        badgeIcon = Icons.biotech_outlined;
        break;
      case 'pdf':
        badgeColor = const Color(0xFFE11D48);
        badgeIcon = Icons.picture_as_pdf_outlined;
        break;
      case 'imagen':
        badgeColor = const Color(0xFF059669);
        badgeIcon = Icons.camera_alt_outlined;
        break;
      default:
        badgeColor = const Color(0xFF7C3AED);
        badgeIcon = Icons.folder_open_outlined;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(badgeIcon, size: 14, color: badgeColor),
                    const SizedBox(width: 6),
                    Text(
                      '${examen.tipoLabel} • ${examen.subtipo}',
                      style: TextStyle(
                        color: badgeColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Text(
                    fechaStr,
                    style: const TextStyle(fontSize: 11, color: AppColors.textLight, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.textLight),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: 'Eliminar Estudio',
                    onPressed: () => _eliminarExamenConfirmar(examen),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 10),

          Text(
            examen.titulo,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: AppColors.onSurface,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Zona: ${examen.zona} • Archivo: ${examen.fileName} (${examen.formattedSize})',
            style: const TextStyle(fontSize: 11, color: AppColors.textLight),
          ),

          const SizedBox(height: 12),

          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ExamViewerScreen(examen: examen, paciente: _selectedPaciente),
                ),
              );
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: examen.fileBase64 != null && examen.fileBase64!.isNotEmpty
                  ? (examen.isPdf
                      ? Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEF2F2),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFECACA)),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 28),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      examen.fileName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${examen.formattedSize} • Toca para abrir y visualizar PDF',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.open_in_new, size: 18, color: AppColors.primary),
                            ],
                          ),
                        )
                      : Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Image.memory(
                              base64Decode(examen.fileBase64!),
                              width: double.infinity,
                              height: 140,
                              fit: BoxFit.cover,
                            ),
                            Container(
                              margin: const EdgeInsets.all(8),
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.zoom_in, color: Colors.white, size: 14),
                                  SizedBox(width: 4),
                                  Text('Ver Rayos X', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                        ))
                  : Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.ghostOutline),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.12),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(badgeIcon, color: badgeColor, size: 26),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  examen.titulo,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'Estudio clínico digitalizado • Toca para ver detalle',
                                  style: TextStyle(fontSize: 11, color: AppColors.textLight),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right, color: AppColors.primary),
                        ],
                      ),
                    ),
            ),
          ),

          if (examen.observaciones.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                examen.observaciones,
                style: const TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExamViewerScreen(examen: examen, paciente: _selectedPaciente),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility_outlined, size: 16, color: AppColors.primary),
                  label: const Text('Visor Clínico 360°', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ghostOutline, width: 1.0),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _compartirExamenWhatsApp(examen),
                  icon: const Icon(Icons.chat_outlined, size: 16, color: Colors.white),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
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
  }

  Widget _buildEmptyExamenesState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.biotech_outlined, size: 48, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'No hay exámenes o radiografías cargadas',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            const Text(
              'Presiona el botón para digitalizar radiografías panorámicas, periapicales, estudios en PDF o fotografías clínicas desde el celular.',
              style: TextStyle(color: AppColors.textLight, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final nuevo = await Navigator.push<ExamenClinico>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => UploadExamScreen(paciente: _selectedPaciente!),
                  ),
                );
                if (nuevo != null) {
                  _cargarHistorialPaciente(_selectedPaciente!);
                }
              },
              icon: const Icon(Icons.cloud_upload_outlined, color: Colors.white),
              label: const Text('Jalar Examen desde el Celular', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _compartirExamenWhatsApp(ExamenClinico examen) {
    if (_selectedPaciente == null) return;
    final mensaje = '🦷 *RIZO DENTAL • EXPEDIENTE CLÍNICO 360°*\n\n'
        'Estimado(a) *${_selectedPaciente!.nombre} ${_selectedPaciente!.apellido}*,\n'
        'Le enviamos la ficha de su estudio radiográfico / clínico realizado:\n\n'
        '📋 *Estudio:* ${examen.titulo}\n'
        '🩻 *Tipo:* ${examen.tipoLabel} (${examen.subtipo})\n'
        '📅 *Fecha:* ${examen.fecha.day}/${examen.fecha.month}/${examen.fecha.year}\n'
        '🎯 *Zona:* ${examen.zona}\n\n'
        '📝 *Hallazgos Clínicos del Especialista:*\n'
        '${examen.observaciones.isNotEmpty ? examen.observaciones : "Estudio archivado en su expediente digital sin novedades patológicas inmediatas."}\n\n'
        '📍 *Rizo Dental Sanctuary*\n'
        'Dra. María Rizo • Especialista ATM & Odontología Integral';

    _abrirWhatsApp(_selectedPaciente!.telefono, mensaje);
  }

  void _eliminarExamenConfirmar(ExamenClinico examen) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar examen clínico?'),
        content: Text('Se eliminará "${examen.titulo}" del expediente del paciente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final supabaseService = SupabaseService();
              await supabaseService.eliminarExamen(examen.id);
              _cargarHistorialPaciente(_selectedPaciente!);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Examen eliminado del expediente.')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // TAB 3: CONSULTAS CLÍNICAS
  Widget _buildEvaluacionesTab() {
    if (_evaluaciones.isEmpty) {
      return _buildEmptyState('No hay consultas clínicas registradas para este paciente.');
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: _evaluaciones.length,
      itemBuilder: (context, index) {
        final eval = _evaluaciones[index];
        final String diagnostico = eval['diagnostico'] ?? 'Diagnóstico de Consulta';
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

  // TAB 2: TRATAMIENTOS & ESTÉTICA FACIAL
  Widget _buildTratamientosTab() {
    double totalPresupuesto = 0;
    double totalAbonado = 0;
    for (var t in _tratamientos) {
      totalPresupuesto += ((t['precio_gtq'] as num?) ?? 0.0).toDouble();
      totalAbonado += ((t['abono_gtq'] as num?) ?? 0.0).toDouble();
    }
    final saldo = (totalPresupuesto - totalAbonado).clamp(0.0, double.infinity);

    return Column(
      children: [
        // Action Header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Tratamientos: ${_tratamientos.length} registros',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.onSurface,
                  ),
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => TreatmentsScreen(paciente: _selectedPaciente!),
                    ),
                  ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                },
                icon: const Icon(Icons.tune_outlined, size: 16, color: Colors.white),
                label: const Text('Gestionar', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),

        // Financial mini banner if treatments exist
        if (_tratamientos.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total: Q ${totalPresupuesto.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                Text('Abonado: Q ${totalAbonado.toStringAsFixed(2)}', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.success)),
                Text('Saldo: Q ${saldo.toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: saldo > 0 ? AppColors.error : AppColors.success)),
              ],
            ),
          ),

        // List or Empty
        Expanded(
          child: _tratamientos.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.medical_services_outlined, size: 48, color: AppColors.textLight),
                      const SizedBox(height: 12),
                      const Text('No hay tratamientos asignados a este paciente.', style: TextStyle(color: AppColors.textLight, fontSize: 13)),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Crear Primer Tratamiento'),
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => TreatmentsScreen(paciente: _selectedPaciente!),
                            ),
                          ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                        },
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: _tratamientos.length,
                  itemBuilder: (context, index) {
                    final t = _tratamientos[index];
                    final String nombre = t['tratamiento'] ?? 'Tratamiento';
                    final String subtipo = t['subtipo'] ?? '';
                    final String cat = t['categoria'] ?? '';
                    final int diente = t['diente'] ?? 0;
                    final String evo = t['evolucion'] ?? 'En Proceso';
                    final String estado = t['estado'] ?? 'Pendiente';
                    final double costo = ((t['precio_gtq'] as num?) ?? 0.0).toDouble();
                    final double abono = ((t['abono_gtq'] as num?) ?? 0.0).toDouble();
                    final double sal = (costo - abono).clamp(0.0, double.infinity);

                    Color estadoColor = AppColors.warning;
                    if (estado == 'Completado' || estado == 'Tratado') estadoColor = AppColors.success;
                    if (estado == 'En Proceso' || estado == 'Problema') estadoColor = AppColors.primary;

                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TreatmentsScreen(paciente: _selectedPaciente!),
                          ),
                        ).then((_) => _cargarHistorialPaciente(_selectedPaciente!));
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(color: AppColors.shadowSoft, blurRadius: 14, offset: Offset(0, 3)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Row(
                                    children: [
                                      Icon(
                                        cat == 'estetica_facial' ? Icons.spa_outlined : Icons.healing_outlined,
                                        size: 18,
                                        color: AppColors.primary,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          diente > 0 ? '$nombre (Pieza #$diente)' : nombre,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: estadoColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(estado, style: TextStyle(color: estadoColor, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ),
                            if (subtipo.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(subtipo, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                            ],
                            const SizedBox(height: 6),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Etapa: $evo', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
                                Text('Q ${costo.toStringAsFixed(2)} (Saldo: Q ${sal.toStringAsFixed(2)})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
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
