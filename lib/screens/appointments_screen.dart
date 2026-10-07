import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../utils/pdf_generator.dart';
import '../services/supabase_service.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = false;
  List<Paciente> _pacientes = [];
  List<Map<String, dynamic>> _citas = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    try {
      final supabaseService = SupabaseService();
      final pacList = await supabaseService.obtenerPacientes();
      final citasRes = await supabaseService.obtenerCitas();

      setState(() {
        _pacientes = pacList;
        _citas = citasRes;
      });
    } catch (e) {
      debugPrint('Error al cargar citas: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalNuevaCita({Map<String, dynamic>? citaExistente}) {
    Paciente? pacienteSeleccionado = _pacientes.isNotEmpty ? _pacientes.first : null;
    if (citaExistente != null) {
      final pFound = _pacientes.firstWhere(
        (p) => p.id == citaExistente['paciente_id'],
        orElse: () => _pacientes.isNotEmpty ? _pacientes.first : Paciente(
          id: citaExistente['paciente_id'] ?? 'id',
          nombre: citaExistente['paciente_nombre'] ?? 'Paciente',
          apellido: '',
          email: '',
          telefono: citaExistente['paciente_telefono'] ?? '',
          fechaNacimiento: DateTime(1990, 1, 1),
          genero: 'M',
          direccion: '',
        ),
      );
      pacienteSeleccionado = pFound;
    }

    DateTime fechaCita = DateTime.now().add(const Duration(days: 1));
    TimeOfDay horaCita = const TimeOfDay(hour: 10, minute: 0);

    if (citaExistente != null && citaExistente['fecha_hora'] != null) {
      final dt = DateTime.tryParse(citaExistente['fecha_hora']) ?? DateTime.now();
      fechaCita = dt;
      horaCita = TimeOfDay(hour: dt.hour, minute: dt.minute);
    }

    final motivoController = TextEditingController(
      text: citaExistente != null ? citaExistente['motivo'] : 'Evaluación y Diagnóstico ATM / Fonseca',
    );
    final notasController = TextEditingController(
      text: citaExistente != null ? (citaExistente['notas'] ?? '') : '',
    );

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Text(
            citaExistente == null ? 'Programar Cita Odontológica' : '🔄 Reprogramar Cita Odontológica',
            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<Paciente>(
                  value: pacienteSeleccionado,
                  decoration: _inputDecoration('Seleccionar Paciente'),
                  dropdownColor: AppColors.surfaceContainerLowest,
                  items: _pacientes.map((p) {
                    return DropdownMenuItem(
                      value: p,
                      child: Text('${p.nombre} ${p.apellido} (${p.telefono})'),
                    );
                  }).toList(),
                  onChanged: (val) => setStateDialog(() => pacienteSeleccionado = val),
                ),
                const SizedBox(height: 12),
                ListTile(
                  tileColor: AppColors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: Text('Fecha: ${fechaCita.day}/${fechaCita.month}/${fechaCita.year}'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: fechaCita,
                      firstDate: DateTime.now(),
                      lastDate: DateTime.now().add(const Duration(days: 180)),
                    );
                    if (picked != null) setStateDialog(() => fechaCita = picked);
                  },
                ),
                const SizedBox(height: 10),
                ListTile(
                  tileColor: AppColors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.access_time, color: AppColors.primary),
                  title: Text('Hora: ${horaCita.format(context)}'),
                  trailing: const Icon(Icons.edit, size: 18),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: horaCita,
                    );
                    if (picked != null) setStateDialog(() => horaCita = picked);
                  },
                ),
                const SizedBox(height: 12),
                TextField(controller: motivoController, decoration: _inputDecoration('Motivo de consulta')),
                const SizedBox(height: 12),
                TextField(controller: notasController, decoration: _inputDecoration('Notas clínicas adicionales')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (pacienteSeleccionado == null) return;

                final dtCombined = DateTime(
                  fechaCita.year,
                  fechaCita.month,
                  fechaCita.day,
                  horaCita.hour,
                  horaCita.minute,
                );

                final String citaId = citaExistente != null
                    ? citaExistente['id']
                    : 'cita_${DateTime.now().millisecondsSinceEpoch}';

                final String targetIso = dtCombined.toIso8601String().substring(0, 16);
                final bool existeConflicto = _citas.any((c) {
                  if (c['id'] == citaId) return false;
                  final String existingIso = (c['fecha_hora'] ?? '').toString();
                  return existingIso.startsWith(targetIso);
                });

                if (existeConflicto && citaExistente == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('⚠️ Ya existe una cita o bloqueo de agenda registrado en esa hora.'),
                      backgroundColor: AppColors.warning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                  return;
                }

                final citaData = {
                  'id': citaId,
                  'paciente_id': pacienteSeleccionado!.id,
                  'paciente_nombre': '${pacienteSeleccionado!.nombre} ${pacienteSeleccionado!.apellido}',
                  'paciente_telefono': pacienteSeleccionado!.telefono,
                  'fecha_hora': dtCombined.toIso8601String(),
                  'fecha': '${dtCombined.day.toString().padLeft(2, '0')}/${dtCombined.month.toString().padLeft(2, '0')}/${dtCombined.year}',
                  'hora': '${dtCombined.hour.toString().padLeft(2, '0')}:${dtCombined.minute.toString().padLeft(2, '0')}',
                  'motivo': motivoController.text.trim().isEmpty ? 'Consulta Odontológica' : motivoController.text.trim(),
                  'notas': notasController.text.trim(),
                  'estado': 'Programada',
                  'requiere_reprogramacion': false,
                  'recordatorio_3dias': true,
                  'recordatorio_1dia': true,
                  'recordatorio_hoy': true,
                };

                try {
                  final supabaseService = SupabaseService();
                  await supabaseService.guardarCita(citaData);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _cargarDatos();
                  _notificarWhatsAppAuto(citaData, esReprogramacion: citaExistente != null);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(citaExistente == null ? '¡Cita programada y notificación enviada!' : '¡Cita reprogramada exitosamente!'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                } catch (e) {
                  debugPrint('Error al guardar cita: $e');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(citaExistente == null ? 'Guardar Cita' : 'Confirmar Reprogramación'),
            ),
          ],
        ),
      ),
    );
  }

  void _exportarPdfCita(Map<String, dynamic> cita) async {
    final supabase = Supabase.instance.client;
    final doctorRes = await supabase.from('users').select().eq('email', supabase.auth.currentUser?.email ?? '').maybeSingle();

    final paciente = _pacientes.firstWhere(
      (p) => p.id == cita['paciente_id'],
      orElse: () => Paciente(
        id: cita['paciente_id'] ?? 'id',
        nombre: cita['paciente_nombre'] ?? 'Paciente',
        apellido: '',
        email: 'paciente@clinic.com',
        telefono: cita['paciente_telefono'] ?? '+50255551234',
        fechaNacimiento: DateTime(1990, 1, 1),
        genero: 'No especificado',
        direccion: 'Guatemala',
      ),
    );

    final dt = DateTime.tryParse(cita['fecha_hora'] ?? '') ?? DateTime.now();
    final fechaHoraStr = '${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

    await PdfGenerator.generarPdfCita(
      paciente: paciente,
      fechaHora: fechaHoraStr,
      motivo: cita['motivo'] ?? 'Consulta Odontológica',
      notas: cita['notas'] ?? '',
      estado: cita['estado'] ?? 'Programada',
      doctorInfo: doctorRes,
    );
  }

  void _notificarWhatsAppAuto(Map<String, dynamic> cita, {bool esReprogramacion = false}) async {
    final tel = cita['paciente_telefono'] ?? '';
    final nombre = cita['paciente_nombre'] ?? 'Paciente';
    final motivo = cita['motivo'] ?? 'Cita Odontológica';
    final dt = DateTime.tryParse(cita['fecha_hora'] ?? '') ?? DateTime.now();
    final fechaStr = '${dt.day}/${dt.month}/${dt.year} a las ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

    final buffer = StringBuffer();
    if (esReprogramacion) {
      buffer.writeln('🔄 *CITA REPROGRAMADA - RIZO DENTAL SANCTUARY*');
      buffer.writeln('Hola $nombre, tu cita ha sido reprogramada exitosamente.');
    } else {
      buffer.writeln('📅 *CONFIRMACIÓN DE CITA - RIZO DENTAL SANCTUARY*');
      buffer.writeln('Hola $nombre, tu cita odontológica fue agendada exitosamente.');
    }
    buffer.writeln('\n• Motivo: $motivo');
    buffer.writeln('• Fecha y Hora: $fechaStr');
    buffer.writeln('\n🤖 *BOT DE CLÍNICA RIZO DENTAL (+502 5981-6632):*');
    buffer.writeln('¿Deseas gestionar tu cita? Responde directamente a este chat:');
    buffer.writeln('1️⃣ Responde *1* o *"Sí"* para CONFIRMAR tu asistencia.');
    buffer.writeln('2️⃣ Responde *2* o *"No puedo"* para SOLICITAR REPROGRAMACIÓN (Alertará al doctor).');
    buffer.writeln('3️⃣ Responde *3* o *"Cancelar"* para CANCELAR la cita.');

    final cleanPhone = tel.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString())}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
    }
  }

  void _simularRespuestaPacienteNoPuede(Map<String, dynamic> cita) async {
    final citaModificada = Map<String, dynamic>.from(cita);
    citaModificada['estado'] = 'Pendiente Reprogramación';
    citaModificada['requiere_reprogramacion'] = true;
    citaModificada['alerta_paciente'] = 'El paciente respondió por WhatsApp indicando que no podrá asistir.';

    final supabaseService = SupabaseService();
    await supabaseService.guardarCita(citaModificada);
    _cargarDatos();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🚨 Alerta Bot: El paciente indicó que no podrá asistir. Cita marcada para reprogramar.'),
        backgroundColor: AppColors.warning,
        duration: Duration(seconds: 4),
      ),
    );
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
                Icons.calendar_month_outlined,
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
                  'Gestión de Citas Odontológicas & Bot WhatsApp',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.textLight,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: AppColors.primary, size: 28),
            onPressed: () => _abrirModalNuevaCita(),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : _citas.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                          child: const Icon(Icons.event_available_outlined, size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay citas agendadas aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Programar Primera Cita'),
                          onPressed: () => _abrirModalNuevaCita(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _citas.length,
                    itemBuilder: (context, index) {
                      final cita = _citas[index];
                      final dt = DateTime.tryParse(cita['fecha_hora'] ?? '') ?? DateTime.now();
                      final fechaHoraStr = '${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';
                      final bool requiereReprogramacion = cita['requiere_reprogramacion'] == true || cita['estado'] == 'Pendiente Reprogramación';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: requiereReprogramacion
                              ? AppColors.warning.withOpacity(0.08)
                              : AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: requiereReprogramacion ? AppColors.warning : AppColors.ghostOutline,
                            width: requiereReprogramacion ? 2.0 : 1.0,
                          ),
                          boxShadow: const [
                            BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (requiereReprogramacion) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                margin: const EdgeInsets.only(bottom: 12),
                                decoration: BoxDecoration(
                                  color: AppColors.warning.withOpacity(0.18),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 22),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        cita['alerta_paciente'] ?? '🚨 El paciente indicó por WhatsApp que no podrá asistir. Presione Reprogramar.',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.onSurface),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: requiereReprogramacion ? AppColors.warning.withOpacity(0.18) : AppColors.primary.withOpacity(0.12),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    requiereReprogramacion ? Icons.event_busy : Icons.person,
                                    color: requiereReprogramacion ? AppColors.warning : AppColors.primary,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        cita['paciente_nombre'] ?? 'Paciente',
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Motivo: ${cita['motivo'] ?? "Consulta"}',
                                        style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(height: 2),
                                      Text('Horario: $fechaHoraStr', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 12),

                            // Scheduled Automated Reminders Status Line
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text('Rec. 3 Días (Bot)', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text('Rec. 1 Día (Bot)', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                                    ],
                                  ),
                                  Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, size: 14, color: AppColors.success),
                                      SizedBox(width: 4),
                                      Text('Rec. Hoy (Bot)', style: TextStyle(fontSize: 10, color: AppColors.textLight)),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            Row(
                              children: [
                                if (requiereReprogramacion) ...[
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.edit_calendar, size: 18, color: Colors.white),
                                      label: const Text('REPROGRAMAR CITA', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      onPressed: () => _abrirModalNuevaCita(citaExistente: cita),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.primary,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      icon: const Icon(Icons.picture_as_pdf, size: 18, color: AppColors.primary),
                                      label: const Text('Exportar PDF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                      onPressed: () => _exportarPdfCita(cita),
                                      style: OutlinedButton.styleFrom(
                                        side: const BorderSide(color: AppColors.ghostOutline, width: 1),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      icon: const Icon(Icons.send_to_mobile, size: 18, color: Colors.white),
                                      label: const Text('WhatsApp', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white)),
                                      onPressed: () => _notificarWhatsAppAuto(cita),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppColors.success,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                    ),
                                  ),
                                  PopupMenuButton<String>(
                                    icon: const Icon(Icons.more_vert, color: AppColors.textLight),
                                    onSelected: (val) {
                                      if (val == 'simular_no_puede') {
                                        _simularRespuestaPacienteNoPuede(cita);
                                      } else if (val == 'reprogramar') {
                                        _abrirModalNuevaCita(citaExistente: cita);
                                      }
                                    },
                                    itemBuilder: (ctx) => [
                                      const PopupMenuItem(
                                        value: 'reprogramar',
                                        child: Text('Reprogramar Fecha/Hora'),
                                      ),
                                      const PopupMenuItem(
                                        value: 'simular_no_puede',
                                        child: Text('Simular Paciente Indica "No Puedo"'),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
