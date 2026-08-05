import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/paciente.dart';
import '../constants/colors.dart';
import '../utils/pdf_generator.dart';
import 'fonseca_test_screen.dart';
import 'appointments_screen.dart';
import 'prescription_screen.dart';

class PatientHistoryScreen extends StatefulWidget {
  final Paciente? selectedPatient;

  const PatientHistoryScreen({super.key, this.selectedPatient});

  @override
  State<PatientHistoryScreen> createState() => _PatientHistoryScreenState();
}

class _PatientHistoryScreenState extends State<PatientHistoryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();

  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;
  bool _isLoadingPacientes = true;

  List<Map<String, dynamic>> _evaluaciones = [];
  List<Map<String, dynamic>> _recetas = [];
  List<Map<String, dynamic>> _citas = [];
  bool _isLoadingHistorial = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarPacientes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _isLoadingPacientes = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('pacientes').select().order('nombre');
      final list = (response as List).map((p) => Paciente.fromMap(Map<String, dynamic>.from(p), p['id'].toString())).toList();

      setState(() {
        _pacientes = list;
        if (widget.selectedPatient != null) {
          _pacienteSeleccionado = list.firstWhere(
            (p) => p.id == widget.selectedPatient!.id,
            orElse: () => widget.selectedPatient!,
          );
        } else if (list.isNotEmpty) {
          _pacienteSeleccionado = list.first;
        }
      });

      if (_pacienteSeleccionado != null) {
        _cargarHistorialPaciente(_pacienteSeleccionado!);
      }
    } catch (e) {
      debugPrint('Error al cargar pacientes: $e');
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
      debugPrint('Error al cargar historial: $e');
    } finally {
      if (mounted) setState(() => _isLoadingHistorial = false);
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
              'Histórico Clínico del Paciente',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      ),
      body: _isLoadingPacientes
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
                // Patient Selector Header Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
                      const Text(
                        'Seleccionar Paciente',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textLight,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLow,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.ghostOutline, width: 1.0),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<Paciente>(
                            value: _pacienteSeleccionado,
                            isExpanded: true,
                            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                            items: _pacientes.map((p) {
                              return DropdownMenuItem<Paciente>(
                                value: p,
                                child: Text(
                                  '${p.nombre} ${p.apellido} • Tel: ${p.telefono}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: AppColors.onSurface,
                                  ),
                                ),
                              );
                            }).toList(),
                            onChanged: (p) {
                              if (p != null) {
                                setState(() => _pacienteSeleccionado = p);
                                _cargarHistorialPaciente(p);
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_pacienteSeleccionado != null) ...[
                  // Patient Info Banner
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
                                _pacienteSeleccionado!.nombre.isNotEmpty
                                    ? _pacienteSeleccionado!.nombre[0].toUpperCase()
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
                                    '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${_calcularEdad(_pacienteSeleccionado!.fechaNacimiento)} años (${_pacienteSeleccionado!.genero}) • ${_pacienteSeleccionado!.telefono}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (_pacienteSeleccionado!.email.isNotEmpty)
                                    Text(
                                      _pacienteSeleccionado!.email,
                                      style: TextStyle(
                                        color: Colors.white.withOpacity(0.8),
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
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
                                ).then((_) => _cargarHistorialPaciente(_pacienteSeleccionado!));
                              },
                            ),
                            _buildQuickActionButton(
                              icon: Icons.medication_outlined,
                              label: 'Nueva Receta',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const PrescriptionScreen()),
                                ).then((_) => _cargarHistorialPaciente(_pacienteSeleccionado!));
                              },
                            ),
                            _buildQuickActionButton(
                              icon: Icons.calendar_month_outlined,
                              label: 'Agendar Cita',
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AppointmentsScreen()),
                                ).then((_) => _cargarHistorialPaciente(_pacienteSeleccionado!));
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Tab Bar
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
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: const [
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
                              _buildEvaluacionesList(),
                              _buildRecetasList(),
                              _buildCitasList(),
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
            Icon(icon, color: Colors.white, size: 16),
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

  // TAB 1: EVALUACIONES ATM
  Widget _buildEvaluacionesList() {
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
                      pacienteNombre: '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
                      score: score,
                      diagnostico: diagnostico,
                      respuestas: const {},
                      doctorNombre: 'Dra. María Rizo',
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

  // TAB 2: RECETAS MÉDICAS
  Widget _buildRecetasList() {
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
        final String medicamentos = receta['medicamentos'] ?? 'Medicamentos prescritos';

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
                  medicamentos,
                  style: const TextStyle(fontSize: 13, color: AppColors.onSurface, height: 1.4),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    PdfGenerator.generarPdfReceta(
                      pacienteNombre: '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
                      colegiado: '12345',
                      medicamentos: medicamentos,
                      indicaciones: receta['indicaciones'] ?? 'Tomar según prescripción clínica.',
                      doctorNombre: 'Dra. María Rizo',
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Exportar Receta en PDF', style: TextStyle(fontSize: 12, color: AppColors.primary)),
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

  // TAB 3: CITAS MÉDICAS
  Widget _buildCitasList() {
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
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    PdfGenerator.generarPdfCita(
                      pacienteNombre: '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
                      fechaHora: '$fecha a las $hora',
                      motivo: motivo,
                      notas: 'Por favor asistir 10 minutos antes a la clínica Rizo Dental.',
                      doctorNombre: 'Dra. María Rizo',
                    );
                  },
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 18, color: AppColors.primary),
                  label: const Text('Exportar Comprobante Cita en PDF', style: TextStyle(fontSize: 12, color: AppColors.primary)),
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
