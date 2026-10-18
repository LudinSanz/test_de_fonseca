import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'treatments_screen.dart';
import 'messages_screen.dart';
import 'notifications_screen.dart';
import '../models/paciente.dart';
import '../services/firestore_service.dart';
import '../services/supabase_service.dart';
import '../constants/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  int _selectedIndex = 0;
  final List<Reporte> _reportes = [];
  final FirestoreService _firestoreService = FirestoreService();
  Paciente? _pacienteEjemplo;
  String _doctorNombre = 'Especialista Odontologia';
  String _doctorEmail = 'doctor@rizodental.com';
  String _doctorEspecialidad = 'Especialista en Disfuncion ATM';
  late AnimationController _fadeCtrl;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _cargarPacienteEjemplo();
    _cargarDatosDoctor();
    _fadeCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosDoctor() async {
    try {
      final supabaseService = SupabaseService();
      String emailOrId = '';
      try {
        final u = Supabase.instance.client.auth.currentUser;
        if (u != null) emailOrId = u.email ?? u.id;
      } catch (_) {}
      final data = await supabaseService.obtenerPerfilDoctor(emailOrId);
      if (data != null && mounted) {
        setState(() {
          if (data['name'] != null && data['name'].toString().isNotEmpty) _doctorNombre = data['name'];
          if (data['email'] != null && data['email'].toString().isNotEmpty) _doctorEmail = data['email'];
          if (data['especialidad'] != null && data['especialidad'].toString().isNotEmpty) _doctorEspecialidad = data['especialidad'];
        });
      }
    } catch (e) {
      debugPrint('Error al cargar datos del doctor: $e');
    }
  }

  Future<void> _cargarPacienteEjemplo() async {
    Paciente? paciente = await _firestoreService.obtenerPaciente('paciente_demo');
    if (mounted) setState(() => _pacienteEjemplo = paciente);
  }

  Future<void> _guardarPacienteEjemplo() async {
    Paciente paciente = Paciente(
      id: 'paciente_demo', nombre: 'Juan', apellido: 'Perez',
      email: 'juan.perez@email.com', telefono: '555-1234',
      fechaNacimiento: DateTime(1990, 5, 20), genero: 'Masculino', direccion: 'Ciudad de Guatemala',
    );
    await _firestoreService.guardarPaciente(paciente);
    if (mounted) {
      setState(() => _pacienteEjemplo = paciente);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Paciente sincronizado'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating),
      );
    }
  }

  void _onItemTapped(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 0: break;
      case 1: Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen())); break;
      case 2: Navigator.push(context, MaterialPageRoute(builder: (_) => const TreatmentsScreen())); break;
      case 3: Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen())); break;
      case 4: Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen())); break;
    }
  }

  void _startFonsecaTest() async {
    final result = await Navigator.push<Map<String, dynamic>>(context, MaterialPageRoute(builder: (_) => const FonsecaTestScreen()));
    if (result != null && result.containsKey('score') && result.containsKey('diagnosis')) {
      setState(() {
        _reportes.add(Reporte(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          pacienteId: _pacienteEjemplo?.id ?? 'desconocido',
          fecha: DateTime.now(), tipo: 'fonseca',
          contenido: 'Puntuacion: ${result["score"]}, Diagnostico: ${result["diagnosis"]}',
        ));
      });
    }
  }

  void _logout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Cerrar Sesion', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
        content: const Text('Deseas salir?', style: TextStyle(color: AppColors.textLight)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => const LoginScreen()), (_) => false);
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: const Text('Cerrar Sesion'),
          ),
        ],
      ),
    );
  }

  void _showEvaluationOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
        decoration: const BoxDecoration(color: AppColors.surfaceContainerLowest, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.ghostOutline, borderRadius: BorderRadius.circular(2)))),
            const SizedBox(height: 20),
            const Text('Nueva Accion', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.onSurface)),
            const Text('Selecciona lo que deseas hacer', style: TextStyle(fontSize: 12, color: AppColors.textLight)),
            const SizedBox(height: 20),
            _sheetOpt(Icons.person_add_alt_1_outlined, AppColors.primary, 'Registrar Nuevo Paciente', 'Crear expediente en Supabase', () async {
              Navigator.pop(ctx);
              final p = await Navigator.push<Paciente>(context, MaterialPageRoute(builder: (_) => const PatientRegisterScreen()));
              if (p != null) setState(() => _pacienteEjemplo = p);
            }),
            const SizedBox(height: 10),
            _sheetOpt(Icons.assessment_outlined, Color(0xFF4A6FA5), 'Test de Fonseca (ATM)', 'Evaluacion de disfuncion temporomandibular', () { Navigator.pop(ctx); _startFonsecaTest(); }),
            const SizedBox(height: 10),
            _sheetOpt(Icons.speed_outlined, Color(0xFF007A78), 'Consulta Clinica Rapida', 'Screening expres de 5 factores', () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickEvaluationScreen())); }),
            const SizedBox(height: 10),
            _sheetOpt(Icons.folder_shared_outlined, Color(0xFF983C00), 'Directorio & Expediente 360', 'Ver historial completo de pacientes', () { Navigator.pop(ctx); Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientDirectoryScreen())); }),
          ],
        ),
      ),
    );
  }

  Widget _sheetOpt(IconData icon, Color color, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(18)),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: color, size: 22)),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface)),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
          ])),
          const Icon(Icons.chevron_right, color: AppColors.textLight, size: 20),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12 ? 'Buenos dias' : hour < 18 ? 'Buenas tardes' : 'Buenas noches';

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        centerTitle: false,
        title: Row(children: [
          Image.asset('assets/images/rizo_logo.png', height: 34, fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.medical_services, color: AppColors.primary, size: 22),
            ),
          ),
          const SizedBox(width: 10),
          const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('RIZO DENTAL', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: AppColors.primary)),
            Text('Clinica Dental Especializada', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
          ]),
        ]),
        actions: [
          IconButton(
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_outlined, color: AppColors.primary, size: 24),
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(minWidth: 8, minHeight: 8),
                  ),
                ),
              ],
            ),
            tooltip: 'Centro de Notificaciones y Alertas',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            color: AppColors.surfaceContainerLowest,
            onSelected: (v) {
              if (v == 'profile') Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
              else if (v == 'help') Navigator.push(context, MaterialPageRoute(builder: (_) => const HelpScreen()));
              else if (v == 'logout') _logout();
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'profile', child: ListTile(leading: Icon(Icons.person_outline, color: AppColors.primary), title: Text('Perfil del Especialista'), contentPadding: EdgeInsets.zero)),
              const PopupMenuItem(value: 'help', child: ListTile(leading: Icon(Icons.help_outline, color: AppColors.primary), title: Text('Centro de Ayuda'), contentPadding: EdgeInsets.zero)),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'logout', child: ListTile(leading: Icon(Icons.logout, color: AppColors.error), title: Text('Cerrar Sesion', style: TextStyle(color: AppColors.error)), contentPadding: EdgeInsets.zero)),
            ],
          ),
        ],
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // HERO CARD Doctor
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryContainer], begin: Alignment.topLeft, end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 24, offset: const Offset(0, 10))],
                  ),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const CircleAvatar(radius: 28, backgroundColor: Colors.white24, child: Icon(Icons.person, size: 32, color: Colors.white)),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('$greeting 👋', style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(_doctorNombre, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                        child: Text(_doctorEspecialidad, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
                      ),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                      child: Column(children: [
                        Text('${_reportes.length}', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                        const Text('Eval.', style: TextStyle(color: Colors.white70, fontSize: 10)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),

                // GRID ACCESO RAPIDO 3x2
                const Text('Acceso Rapido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                const SizedBox(height: 12),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 3,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 0.95,
                  children: [
                    _quickGrid(Icons.folder_shared_outlined, 'Directorio\n360', AppColors.primary, () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientDirectoryScreen()))),
                    _quickGrid(Icons.calendar_month_outlined, 'Citas &\nAgenda', const Color(0xFF983C00), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AppointmentsScreen()))),
                    _quickGrid(Icons.medical_services_outlined, 'Tratamientos\n& Estetica', const Color(0xFF007A78), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TreatmentsScreen()))),
                    _quickGrid(Icons.medication_outlined, 'Receta\nMedica', const Color(0xFF0056B3), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrescriptionScreen()))),
                    _quickGrid(Icons.inventory_2_outlined, 'Inventario\nClinico', const Color(0xFF6A0DAD), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InventoryScreen()))),
                    _quickGrid(Icons.chat_outlined, 'Mensajes\nWA', const Color(0xFF25D366), () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()))),
                  ],
                ),
                const SizedBox(height: 24),

                // CARD EVALUACION ATM
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6))],
                  ),
                  child: Column(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 18, 20, 14),
                      child: Row(children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                          child: const Icon(Icons.health_and_safety_outlined, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Evaluacion Clinica & ATM', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                          Text('Test de Fonseca y consultas clinicas', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                        ])),
                      ]),
                    ),
                    const Divider(height: 1, color: AppColors.ghostOutline, indent: 20, endIndent: 20),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(children: [
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton.icon(
                            onPressed: _startFonsecaTest,
                            icon: const Icon(Icons.assessment, size: 20, color: Colors.white),
                            label: const Text('Iniciar Test de Fonseca (ATM)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Row(children: [
                          Expanded(child: OutlinedButton.icon(
                            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const QuickEvaluationScreen())),
                            icon: const Icon(Icons.speed, size: 16, color: AppColors.primary),
                            label: const Text('Consulta Clinica', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 12)),
                          )),
                          const SizedBox(width: 10),
                          Expanded(child: OutlinedButton.icon(
                            onPressed: () async {
                              final p = await Navigator.push<Paciente>(context, MaterialPageRoute(builder: (_) => const PatientRegisterScreen()));
                              if (p != null) setState(() => _pacienteEjemplo = p);
                            },
                            icon: const Icon(Icons.person_add_alt_1_outlined, size: 16, color: AppColors.primary),
                            label: const Text('Nuevo Paciente', style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600)),
                            style: OutlinedButton.styleFrom(side: const BorderSide(color: AppColors.primary, width: 1.2), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)), padding: const EdgeInsets.symmetric(vertical: 12)),
                          )),
                        ]),
                      ]),
                    ),
                  ]),
                ),

                if (_reportes.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Evaluaciones Recientes', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ReportsScreen(reportes: _reportes))),
                      child: const Text('Ver todas', style: TextStyle(color: AppColors.primary, fontSize: 12)),
                    ),
                  ]),
                  const SizedBox(height: 8),
                  ...List.generate(_reportes.length > 2 ? 2 : _reportes.length, (i) {
                    final r = _reportes[_reportes.length - 1 - i];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(color: AppColors.surfaceContainerLow, borderRadius: BorderRadius.circular(16)),
                      child: Row(children: [
                        Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.assignment_turned_in_outlined, color: AppColors.primary, size: 18)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          const Text('Test Fonseca ATM', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface)),
                          Text(r.contenido, style: const TextStyle(fontSize: 11, color: AppColors.textLight), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ])),
                      ]),
                    );
                  }),
                ],
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showEvaluationOptions,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Nueva Accion', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        elevation: 6,
      ),
      bottomNavigationBar: Container(
        margin: const EdgeInsets.only(left: 16, right: 16, bottom: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest.withOpacity(0.95),
          borderRadius: BorderRadius.circular(32),
          boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8))],
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
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11),
            unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Inicio'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_month_outlined), activeIcon: Icon(Icons.calendar_month), label: 'Citas'),
              BottomNavigationBarItem(icon: Icon(Icons.medical_services_outlined), activeIcon: Icon(Icons.medical_services), label: 'Trat.'),
              BottomNavigationBarItem(icon: Icon(Icons.chat_outlined), activeIcon: Icon(Icons.chat), label: 'Mensajes'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outlined), activeIcon: Icon(Icons.person), label: 'Perfil'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _quickGrid(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: AppColors.shadowSoft, blurRadius: 14, offset: Offset(0, 4))],
        ),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.onSurface, height: 1.3), textAlign: TextAlign.center, maxLines: 2, overflow: TextOverflow.ellipsis),
        ]),
      ),
    );
  }
}
