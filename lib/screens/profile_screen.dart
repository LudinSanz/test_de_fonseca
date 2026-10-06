import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../services/supabase_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _isLoading = true;
  bool _isSaving = false;

  final TextEditingController _nombreController = TextEditingController(text: 'Dr. Ludin Solis');
  final TextEditingController _especialidadController = TextEditingController(text: 'Especialista en Disfunción ATM y Odontología');
  final TextEditingController _colegiadoController = TextEditingController(text: 'COL-98421');
  final TextEditingController _telefonoController = TextEditingController(text: '+502 5555 9999');
  final TextEditingController _whatsappClinicaController = TextEditingController(text: '+502 5555 8888');
  final TextEditingController _emailController = TextEditingController(text: 'doctor@clinic.gt');
  final TextEditingController _direccionController = TextEditingController(text: 'Edificio Sixtino II, Nivel 7, Oficina 702, Zona 10, Guatemala');

  double _btnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _cargarPerfilDoctor();
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _especialidadController.dispose();
    _colegiadoController.dispose();
    _telefonoController.dispose();
    _whatsappClinicaController.dispose();
    _emailController.dispose();
    _direccionController.dispose();
    super.dispose();
  }

  Future<void> _cargarPerfilDoctor() async {
    setState(() => _isLoading = true);
    try {
      final supabaseService = SupabaseService();
      String emailOrId = '';
      try {
        final u = Supabase.instance.client.auth.currentUser;
        if (u != null) emailOrId = u.email ?? u.id;
      } catch (_) {}

      final data = await supabaseService.obtenerPerfilDoctor(emailOrId);

      if (data != null) {
        if (data['name'] != null && data['name'].toString().isNotEmpty) {
          _nombreController.text = data['name'];
        }
        if (data['especialidad'] != null && data['especialidad'].toString().isNotEmpty) {
          _especialidadController.text = data['especialidad'];
        }
        if (data['colegiado'] != null && data['colegiado'].toString().isNotEmpty) {
          _colegiadoController.text = data['colegiado'];
        }
        if (data['telefono'] != null && data['telefono'].toString().isNotEmpty) {
          _telefonoController.text = data['telefono'];
        }
        if (data['telefono_whatsapp_clinica'] != null && data['telefono_whatsapp_clinica'].toString().isNotEmpty) {
          _whatsappClinicaController.text = data['telefono_whatsapp_clinica'];
        } else if (data['telefono'] != null && data['telefono'].toString().isNotEmpty) {
          _whatsappClinicaController.text = data['telefono'];
        }
        if (data['email'] != null && data['email'].toString().isNotEmpty) {
          _emailController.text = data['email'];
        }
        if (data['direccion_clinica'] != null && data['direccion_clinica'].toString().isNotEmpty) {
          _direccionController.text = data['direccion_clinica'];
        }
      }
    } catch (e) {
      debugPrint('Error al cargar perfil de Supabase: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _guardarPerfilDoctor() async {
    setState(() => _isSaving = true);
    try {
      final supabaseService = SupabaseService();
      String userId = 'usr_doctor_demo';
      try {
        final u = Supabase.instance.client.auth.currentUser;
        if (u != null) userId = u.id;
      } catch (_) {}

      final doctorData = {
        'id': userId,
        'name': _nombreController.text.trim(),
        'email': _emailController.text.trim(),
        'colegiado': _colegiadoController.text.trim(),
        'especialidad': _especialidadController.text.trim(),
        'telefono': _telefonoController.text.trim(),
        'telefono_whatsapp_clinica': _whatsappClinicaController.text.trim(),
        'direccion_clinica': _direccionController.text.trim(),
        'firma_digital': '${_nombreController.text.trim()} - Colegiado #${_colegiadoController.text.trim()}',
      };

      await supabaseService.guardarPerfilDoctor(doctorData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('¡Perfil profesional y WhatsApp de clínica guardados exitosamente!'),
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar perfil: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
      prefixIcon: Icon(icon, color: AppColors.primary, size: 20),
      filled: true,
      fillColor: AppColors.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline, width: 1.0)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
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
                Icons.person_pin_outlined,
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
                  'Perfil Profesional & Bot WhatsApp de la Clínica',
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
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Doctor Header Card
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 72,
                            height: 72,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [AppColors.primary, AppColors.primaryContainer],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(color: AppColors.primary.withOpacity(0.25), blurRadius: 16, offset: const Offset(0, 4)),
                              ],
                            ),
                            child: const Center(
                              child: Icon(Icons.person, size: 40, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _nombreController.text,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _especialidadController.text,
                                  style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                ),
                                const SizedBox(height: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    'No. Colegiado: ${_colegiadoController.text}',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Doctor Profile Details Form
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Información de Membrete Oficial & WhatsApp',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Esta información nutre los PDF de recetas, informes de Fonseca y el Bot de WhatsApp de la Clínica.',
                            style: TextStyle(fontSize: 12, color: AppColors.textLight),
                          ),
                          const SizedBox(height: 20),

                          TextFormField(
                            controller: _nombreController,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: _inputDecoration('Nombre Completo del Doctor', Icons.badge_outlined),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _especialidadController,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: _inputDecoration('Especialidad Odontológica', Icons.workspace_premium_outlined),
                          ),
                          const SizedBox(height: 14),

                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _colegiadoController,
                                  style: const TextStyle(color: AppColors.onSurface),
                                  decoration: _inputDecoration('No. Colegiado', Icons.card_membership),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _telefonoController,
                                  style: const TextStyle(color: AppColors.onSurface),
                                  decoration: _inputDecoration('Teléfono Personal', Icons.phone_outlined),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _whatsappClinicaController,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: _inputDecoration('Número de WhatsApp Bot de la Clínica (WhatsApp Business)', Icons.chat),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _emailController,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: _inputDecoration('Correo Electrónico Oficial', Icons.email_outlined),
                          ),
                          const SizedBox(height: 14),

                          TextFormField(
                            controller: _direccionController,
                            maxLines: 2,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: _inputDecoration('Dirección de Clínica Sanctuary', Icons.location_on_outlined),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Test WhatsApp Direct Action
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: const Color(0xFF25D366).withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: const BoxDecoration(color: Color(0xFF25D366), shape: BoxShape.circle),
                            child: const Icon(Icons.support_agent, color: Colors.white),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('Probar WhatsApp de la Clínica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface)),
                                Text('WhatsApp Bot: ${_whatsappClinicaController.text}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                              ],
                            ),
                          ),
                          TextButton(
                            onPressed: () async {
                              final tel = _whatsappClinicaController.text.replaceAll(RegExp(r'[^\d+]'), '');
                              final uri = Uri.parse('https://wa.me/$tel?text=Prueba%20de%20conexion%20Bot%20Rizo%20Dental');
                              if (await canLaunchUrl(uri)) {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              }
                            },
                            child: const Text('Probar Chat', style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Save Button (Linear Gradient & Scale Animation)
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
                              BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _guardarPerfilDoctor,
                            icon: const Icon(Icons.save_rounded, color: Colors.white, size: 22),
                            label: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                                  )
                                : const Text(
                                    'Guardar Perfil Profesional',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
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
}
