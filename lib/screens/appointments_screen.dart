import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = true;
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
      final supabase = Supabase.instance.client;
      final pacRes = await supabase.from('pacientes').select();
      final citasRes = await supabase.from('citas').select().order('fecha_hora', ascending: true);

      final pacList = (pacRes as List)
          .map((map) => Paciente.fromMap(Map<String, dynamic>.from(map), map['id'].toString()))
          .toList();

      setState(() {
        _pacientes = pacList;
        _citas = List<Map<String, dynamic>>.from(citasRes);
      });
    } catch (e) {
      debugPrint('Error al cargar citas de Supabase: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalNuevaCita() {
    Paciente? pacienteSeleccionado = _pacientes.isNotEmpty ? _pacientes.first : null;
    DateTime fechaCita = DateTime.now().add(const Duration(days: 1));
    TimeOfDay horaCita = const TimeOfDay(hour: 10, minute: 0);
    final motivoController = TextEditingController(text: 'Evaluación y Diagnóstico ATM / Fonseca');
    final notasController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) => AlertDialog(
          backgroundColor: AppColors.surfaceContainerLowest,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: const Text('Programar Cita Odontológica', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Seleccionar Paciente
                const Text('Seleccionar Paciente', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                const SizedBox(height: 6),
                DropdownButtonFormField<Paciente>(
                  value: pacienteSeleccionado,
                  decoration: _inputDecoration('Paciente'),
                  dropdownColor: AppColors.surfaceContainerLowest,
                  items: _pacientes.map((p) {
                    return DropdownMenuItem<Paciente>(
                      value: p,
                      child: Text('${p.nombre} ${p.apellido}'),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setStateDialog(() => pacienteSeleccionado = val);
                  },
                ),
                const SizedBox(height: 14),

                // Fecha y Hora
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 16),
                        label: Text('${fechaCita.day}/${fechaCita.month}/${fechaCita.year}'),
                        onPressed: () async {
                          final p = await showDatePicker(context: context, initialDate: fechaCita, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                          if (p != null) setStateDialog(() => fechaCita = p);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow, foregroundColor: AppColors.onSurface, elevation: 0),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.access_time, size: 16),
                        label: Text(horaCita.format(context)),
                        onPressed: () async {
                          final t = await showTimePicker(context: context, initialTime: horaCita);
                          if (t != null) setStateDialog(() => horaCita = t);
                        },
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.surfaceContainerLow, foregroundColor: AppColors.onSurface, elevation: 0),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                TextField(controller: motivoController, decoration: _inputDecoration('Tratamiento / Motivo de cita')),
                const SizedBox(height: 12),
                TextField(controller: notasController, decoration: _inputDecoration('Notas de preparación')),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight))),
            ElevatedButton(
              onPressed: () async {
                if (pacienteSeleccionado != null) {
                  final String citaId = 'cita_${DateTime.now().millisecondsSinceEpoch}';
                  final String fechaHoraStr = '${fechaCita.year}-${fechaCita.month.toString().padLeft(2, "0")}-${fechaCita.day.toString().padLeft(2, "0")} ${horaCita.format(context)}';

                  final citaData = {
                    'id': citaId,
                    'paciente_id': pacienteSeleccionado!.id,
                    'paciente_nombre': '${pacienteSeleccionado!.nombre} ${pacienteSeleccionado!.apellido}',
                    'paciente_telefono': pacienteSeleccionado!.telefono,
                    'fecha_hora': fechaHoraStr,
                    'motivo': motivoController.text.trim(),
                    'estado': 'Programada',
                    'notas': notasController.text.trim(),
                  };

                  try {
                    final supabase = Supabase.instance.client;
                    await supabase.from('citas').upsert(citaData);
                    Navigator.pop(ctx);
                    _cargarDatos();
                    _notificarWhatsAppPaciente(citaData);
                  } catch (e) {
                    debugPrint('Error al guardar cita: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Guardar y Notificar'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _notificarWhatsAppPaciente(Map<String, dynamic> cita) async {
    final String tel = (cita['paciente_telefono'] ?? '').replaceAll(RegExp(r'[^\d+]'), '');
    final String msg = Uri.encodeComponent(
      '📅 *RIZO DENTAL - CONFIRMACIÓN DE CITA*\n'
      'Estimado(a) *${cita["paciente_nombre"]}*,\n\n'
      'Le confirmamos su cita odontológica:\n'
      '📍 *Lugar:* Rizo Dental Sanctuary\n'
      '🕒 *Fecha y Hora:* ${cita["fecha_hora"]}\n'
      '🩺 *Motivo:* ${cita["motivo"]}\n\n'
      'Por favor confirme su asistencia respondiendo a este mensaje. ¡Le esperamos!',
    );

    final Uri waUri = Uri.parse('https://wa.me/$tel?text=$msg');
    if (await canLaunchUrl(waUri)) {
      await launchUrl(waUri, mode: LaunchMode.externalApplication);
    }
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
                  'Gestión de Citas & Recordatorios',
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
            icon: const Icon(Icons.add_task, color: AppColors.primary, size: 28),
            onPressed: _abrirModalNuevaCita,
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
                          child: const Icon(Icons.calendar_month_outlined, size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay citas programadas', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.add, color: Colors.white),
                          label: const Text('Programar Primera Cita'),
                          onPressed: _abrirModalNuevaCita,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    itemCount: _citas.length,
                    itemBuilder: (context, index) {
                      final cita = _citas[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 14),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                              child: const Icon(Icons.event, color: AppColors.primary, size: 26),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(cita['paciente_nombre'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface)),
                                  const SizedBox(height: 2),
                                  Text('${cita["fecha_hora"]} • ${cita["motivo"]}', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.send_to_mobile, color: Color(0xFF25D366)),
                              tooltip: 'Recordatorio WhatsApp',
                              onPressed: () => _notificarWhatsAppPaciente(cita),
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
