import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../utils/pdf_generator.dart';

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

                final citaData = {
                  'id': 'cita_${DateTime.now().millisecondsSinceEpoch}',
                  'paciente_id': pacienteSeleccionado!.id,
                  'paciente_nombre': '${pacienteSeleccionado!.nombre} ${pacienteSeleccionado!.apellido}',
                  'paciente_telefono': pacienteSeleccionado!.telefono,
                  'fecha_hora': dtCombined.toIso8601String(),
                  'fecha': '${dtCombined.day.toString().padLeft(2, '0')}/${dtCombined.month.toString().padLeft(2, '0')}/${dtCombined.year}',
                  'hora': '${dtCombined.hour.toString().padLeft(2, '0')}:${dtCombined.minute.toString().padLeft(2, '0')}',
                  'motivo': motivoController.text.trim(),
                  'notas': notasController.text.trim(),
                  'estado': 'Programada',
                };

                try {
                  final supabase = Supabase.instance.client;
                  await supabase.from('citas').upsert(citaData);
                  if (!mounted) return;
                  Navigator.pop(ctx);
                  _cargarDatos();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('¡Cita programada y guardada en Supabase!'), backgroundColor: AppColors.success),
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
              child: const Text('Guardar Cita'),
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

  void _notificarWhatsApp(Map<String, dynamic> cita) async {
    final tel = cita['paciente_telefono'] ?? '';
    final nombre = cita['paciente_nombre'] ?? 'Paciente';
    final motivo = cita['motivo'] ?? 'Cita Odontológica';
    final dt = DateTime.tryParse(cita['fecha_hora'] ?? '') ?? DateTime.now();
    final fechaStr = '${dt.day}/${dt.month}/${dt.year} a las ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

    final mensaje = 'Hola $nombre, te recordamos tu cita odontológica en Rizo Dental para $motivo el día $fechaStr. ¡Te esperamos!';
    final cleanPhone = tel.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No se pudo abrir WhatsApp para $cleanPhone'), backgroundColor: AppColors.error),
      );
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
                  'Gestión de Citas Odontológicas',
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
                          child: const Icon(Icons.event_available_outlined, size: 64, color: AppColors.primary),
                        ),
                        const SizedBox(height: 16),
                        const Text('No hay citas agendadas aún', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
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
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _citas.length,
                    itemBuilder: (context, index) {
                      final cita = _citas[index];
                      final dt = DateTime.tryParse(cita['fecha_hora'] ?? '') ?? DateTime.now();
                      final fechaHoraStr = '${dt.day}/${dt.month}/${dt.year} - ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: const [
                            BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                                  child: const Icon(Icons.person, color: AppColors.primary),
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
                            Row(
                              children: [
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
                                    onPressed: () => _notificarWhatsApp(cita),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.success,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    ),
                                  ),
                                ),
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
