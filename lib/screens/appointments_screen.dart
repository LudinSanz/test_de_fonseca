import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../utils/pdf_generator.dart';
import '../services/supabase_service.dart';
import '../widgets/signature_pad.dart';
import '../widgets/patient_search_selector.dart';

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  bool _isLoading = false;
  List<Paciente> _pacientes = [];
  List<Map<String, dynamic>> _citas = [];

  // Filtros de navegación
  String _filtroEstado = 'Todas'; // 'Todas', 'Hoy', 'Próximas', 'Por Reprogramar', 'Atendidas'
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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

  List<Map<String, dynamic>> get _citasFiltradas {
    final now = DateTime.now();
    final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

    return _citas.where((c) {
      // 1. Filtro de búsqueda por texto (lupa)
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nombre = (c['paciente_nombre'] ?? '').toString().toLowerCase();
        final tel = (c['paciente_telefono'] ?? '').toString().toLowerCase();
        final motivo = (c['motivo'] ?? '').toString().toLowerCase();
        if (!nombre.contains(q) && !tel.contains(q) && !motivo.contains(q)) {
          return false;
        }
      }

      // 2. Filtro de Estado / Temporalidad
      final estado = (c['estado'] ?? 'Programada').toString();
      final fechaHoraStr = (c['fecha_hora'] ?? '').toString();
      final bool requiereReprogramacion = c['requiere_reprogramacion'] == true || estado == 'Pendiente Reprogramación';

      if (_filtroEstado == 'Hoy') {
        return fechaHoraStr.startsWith(todayStr);
      } else if (_filtroEstado == 'Próximas') {
        final dt = DateTime.tryParse(fechaHoraStr);
        if (dt == null) return false;
        return dt.isAfter(now) && estado != 'Atendida' && estado != 'Cancelada';
      } else if (_filtroEstado == 'Por Reprogramar') {
        return requiereReprogramacion;
      } else if (_filtroEstado == 'Atendidas') {
        return estado == 'Atendida';
      } else if (_filtroEstado == 'Canceladas') {
        return estado == 'Cancelada';
      }
      return true; // 'Todas'
    }).toList();
  }

  Future<void> _cambiarEstadoCita(Map<String, dynamic> cita, String nuevoEstado) async {
    final citaModificada = Map<String, dynamic>.from(cita);
    citaModificada['estado'] = nuevoEstado;
    if (nuevoEstado != 'Pendiente Reprogramación') {
      citaModificada['requiere_reprogramacion'] = false;
    }

    try {
      final supabaseService = SupabaseService();
      await supabaseService.guardarCita(citaModificada);
      _cargarDatos();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cita actualizada a: $nuevoEstado'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      debugPrint('Error al cambiar estado de cita: $e');
    }
  }

  Future<void> _eliminarCita(Map<String, dynamic> cita) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar Cita', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.error)),
        content: Text('¿Está seguro de eliminar la cita de ${cita['paciente_nombre']}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight))),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final supabase = Supabase.instance.client;
        await supabase.from('citas').delete().eq('id', cita['id']);
        _cargarDatos();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Cita eliminada de la agenda.'), backgroundColor: AppColors.error),
        );
      } catch (e) {
        debugPrint('Error al eliminar cita: $e');
      }
    }
  }

  void _abrirModalNuevaCita({Map<String, dynamic>? citaExistente}) {
    Paciente? pacienteSeleccionado = _pacientes.isNotEmpty ? _pacientes.first : null;
    if (citaExistente != null) {
      final pFound = _pacientes.firstWhere(
        (p) => p.id == citaExistente['paciente_id'],
        orElse: () => _pacientes.isNotEmpty
            ? _pacientes.first
            : Paciente(
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
      text: citaExistente != null ? citaExistente['motivo'] : 'Evaluación y Diagnóstico Odontológico',
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
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(
                  citaExistente == null ? Icons.add_alarm_outlined : Icons.edit_calendar_outlined,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  citaExistente == null ? 'Nueva Cita Odontológica' : 'Reprogramar Cita',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.onSurface),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Selector con LUPA para buscar paciente
                PatientSearchSelector(
                  selectedPatient: pacienteSeleccionado,
                  patients: _pacientes,
                  label: 'Paciente a Agendar:',
                  onPatientSelected: (p) {
                    setStateDialog(() => pacienteSeleccionado = p);
                  },
                ),
                const SizedBox(height: 14),

                // Selector de Fecha
                ListTile(
                  tileColor: AppColors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.calendar_today, color: AppColors.primary),
                  title: Text(
                    'Fecha: ${fechaCita.day}/${fechaCita.month}/${fechaCita.year}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.edit, size: 18, color: AppColors.primary),
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

                // Selector de Hora
                ListTile(
                  tileColor: AppColors.surfaceContainerLow,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  leading: const Icon(Icons.access_time, color: AppColors.primary),
                  title: Text(
                    'Hora: ${horaCita.format(context)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  trailing: const Icon(Icons.edit, size: 18, color: AppColors.primary),
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: horaCita,
                    );
                    if (picked != null) setStateDialog(() => horaCita = picked);
                  },
                ),
                const SizedBox(height: 14),
                TextField(controller: motivoController, decoration: _inputDecoration('Motivo de consulta / Tratamiento')),
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
                  'estado': citaExistente != null ? (citaExistente['estado'] ?? 'Programada') : 'Programada',
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
                      content: Text(citaExistente == null ? '¡Cita programada y recordatorio listo!' : '¡Cita reprogramada exitosamente!'),
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
              child: Text(citaExistente == null ? 'Guardar y Agendar' : 'Confirmar Cambio'),
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
    final fechaHoraStr = '${dt.day}/${dt.month}/${dt.year} a las ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}';

    final firmaData = await SignaturePadDialog.pedirFirma(
      context,
      tituloDocumento: 'Comprobante Oficial de Cita Odontológica',
    );

    if (firmaData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Se requiere la firma del odontólogo para validar y emitir el comprobante de cita.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
      return;
    }

    await PdfGenerator.generarPdfCita(
      paciente: paciente,
      fechaHora: fechaHoraStr,
      motivo: cita['motivo'] ?? 'Consulta Odontológica',
      notas: cita['notas'] ?? '',
      estado: cita['estado'] ?? 'Programada',
      doctorInfo: doctorRes,
      signaturePngBytes: firmaData.pngBytes,
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
      buffer.writeln('🔄 *CITA REPROGRAMADA - Rizo Dental*');
      buffer.writeln('Hola $nombre, le confirmamos el cambio de horario para su cita odontológica:');
    } else {
      buffer.writeln('📅 *CONFIRMACIÓN DE CITA - Rizo Dental*');
      buffer.writeln('Estimado/a $nombre, su cita ha sido agendada con éxito:');
    }
    buffer.writeln('
📋 *Motivo / Procedimiento:* $motivo');
    buffer.writeln('⏰ *Horario:* $fechaStr');
    buffer.writeln('📍 *Ubicación:* Clínica Rizo Dental, Ciudad de Guatemala (+502 5981-6632)');
    buffer.writeln('
_Por favor responder a este mensaje con un *"Confirmado"* para asegurar su espacio._');

    final cleanPhone = tel.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString())}');

    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
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

  Color _getStatusColor(String estado, bool requiereReprogramacion) {
    if (requiereReprogramacion) return AppColors.warning;
    switch (estado.toLowerCase()) {
      case 'confirmada':
        return AppColors.success;
      case 'atendida':
        return const Color(0xFF6750A4);
      case 'cancelada':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final citasMostrar = _citasFiltradas;
    final int countReprog = _citas.where((c) => c['requiere_reprogramacion'] == true || c['estado'] == 'Pendiente Reprogramación').length;

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
                  'Gestión y Agenda de Citas',
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
            icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
            tooltip: 'Agendar Nueva Cita',
            onPressed: () => _abrirModalNuevaCita(),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : Column(
                children: [
                  // 1. Buscador con Lupa (Buscar por paciente o motivo)
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    child: TextField(
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Buscar citas por paciente, teléfono o motivo 🔍',
                        hintStyle: const TextStyle(fontSize: 13, color: AppColors.textLight),
                        prefixIcon: const Icon(Icons.search, color: AppColors.primary),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textLight),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: AppColors.surfaceContainerLowest,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                      ),
                    ),
                  ),

                  // 2. Filtros de Estado en Chips Horizontales
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: Row(
                      children: [
                        _buildFilterChip('Todas', _citas.length),
                        _buildFilterChip('Hoy', _citas.where((c) {
                          final now = DateTime.now();
                          final todayStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
                          return (c['fecha_hora'] ?? '').toString().startsWith(todayStr);
                        }).length),
                        _buildFilterChip('Próximas', null),
                        _buildFilterChip('Por Reprogramar', countReprog > 0 ? countReprog : null, isAlert: countReprog > 0),
                        _buildFilterChip('Atendidas', null),
                        _buildFilterChip('Canceladas', null),
                      ],
                    ),
                  ),

                  const SizedBox(height: 8),

                  // 3. Lista de Citas
                  Expanded(
                    child: citasMostrar.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.08), shape: BoxShape.circle),
                                  child: const Icon(Icons.event_available_outlined, size: 54, color: AppColors.primary),
                                ),
                                const SizedBox(height: 14),
                                Text(
                                  _searchQuery.isNotEmpty
                                      ? 'No se encontraron citas con "$_searchQuery"'
                                      : 'No hay citas en la categoría "$_filtroEstado"',
                                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                                ),
                                const SizedBox(height: 12),
                                ElevatedButton.icon(
                                  icon: const Icon(Icons.add, color: Colors.white, size: 18),
                                  label: const Text('Programar Cita'),
                                  onPressed: () => _abrirModalNuevaCita(),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            itemCount: citasMostrar.length,
                            itemBuilder: (context, index) {
                              final cita = citasMostrar[index];
                              return _buildAppointmentCard(cita);
                            },
                          ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildFilterChip(String label, int? count, {bool isAlert = false}) {
    final isSelected = _filtroEstado == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            if (count != null && count > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: isAlert
                      ? AppColors.warning
                      : (isSelected ? Colors.white : AppColors.primary),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isAlert || isSelected ? AppColors.primary : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          color: isSelected ? Colors.white : AppColors.onSurface,
        ),
        backgroundColor: AppColors.surfaceContainerLowest,
        selectedColor: isAlert ? AppColors.warning : AppColors.primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: isAlert ? AppColors.warning : AppColors.ghostOutline),
        ),
        onSelected: (_) => setState(() => _filtroEstado = label),
      ),
    );
  }

  Widget _buildAppointmentCard(Map<String, dynamic> cita) {
    final dt = DateTime.tryParse(cita['fecha_hora'] ?? '') ?? DateTime.now();
    final fechaHoraStr = '${dt.day}/${dt.month}/${dt.year} - ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    final estado = cita['estado'] ?? 'Programada';
    final bool requiereReprogramacion = cita['requiere_reprogramacion'] == true || estado == 'Pendiente Reprogramación';
    final statusColor = _getStatusColor(estado, requiereReprogramacion);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: requiereReprogramacion
            ? AppColors.warning.withOpacity(0.08)
            : AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: requiereReprogramacion ? AppColors.warning : AppColors.ghostOutline,
          width: requiereReprogramacion ? 1.8 : 1.0,
        ),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner Alerta Reprogramación
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
                  const Icon(Icons.warning_amber_rounded, color: AppColors.warning, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      cita['alerta_paciente'] ?? '⚠️ El paciente solicitó reprogramar su cita. Toque Reprogramar.',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.onSurface),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Fila Superior: Paciente y Estado Badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: statusColor.withOpacity(0.15),
                child: Icon(
                  requiereReprogramacion ? Icons.event_busy : Icons.person,
                  color: statusColor,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      cita['paciente_nombre'] ?? 'Paciente',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.onSurface),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      cita['motivo'] ?? 'Consulta Odontológica',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.access_time, size: 13, color: AppColors.textLight),
                        const SizedBox(width: 4),
                        Text(fechaHoraStr, style: const TextStyle(fontSize: 11, color: AppColors.textLight)),
                      ],
                    ),
                  ],
                ),
              ),

              // Status Selector Pill
              PopupMenuButton<String>(
                onSelected: (nuevoEstado) => _cambiarEstadoCita(cita, nuevoEstado),
                itemBuilder: (ctx) => [
                  const PopupMenuItem(value: 'Confirmada', child: Text('🟢 Marcar Confirmada')),
                  const PopupMenuItem(value: 'Programada', child: Text('🔵 Marcar Programada')),
                  const PopupMenuItem(value: 'Atendida', child: Text('🟣 Marcar Atendida')),
                  const PopupMenuItem(value: 'Cancelada', child: Text('🔴 Marcar Cancelada')),
                ],
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        estado,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 16, color: statusColor),
                    ],
                  ),
                ),
              ),
            ],
          ),

          if (cita['notas'] != null && (cita['notas'] as String).isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Nota: ${cita['notas']}',
                style: const TextStyle(fontSize: 11, color: AppColors.textLight),
              ),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: AppColors.ghostOutline),
          const SizedBox(height: 8),

          // Botones de Acción Rápida
          Row(
            children: [
              // PDF con Firma
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 16, color: AppColors.primary),
                  label: const Text('PDF Cita', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary)),
                  onPressed: () => _exportarPdfCita(cita),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.ghostOutline),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // WhatsApp
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.send_to_mobile, size: 16, color: Colors.white),
                  label: const Text('WhatsApp', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white)),
                  onPressed: () => _notificarWhatsAppAuto(cita),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.success,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Menú Más Opciones (Reprogramar / Eliminar)
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textLight),
                onSelected: (val) {
                  if (val == 'reprogramar') {
                    _abrirModalNuevaCita(citaExistente: cita);
                  } else if (val == 'eliminar') {
                    _eliminarCita(cita);
                  }
                },
                itemBuilder: (ctx) => [
                  const PopupMenuItem(
                    value: 'reprogramar',
                    child: Row(
                      children: [
                        Icon(Icons.edit_calendar, size: 18, color: AppColors.primary),
                        SizedBox(width: 8),
                        Text('Reprogramar'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'eliminar',
                    child: Row(
                      children: [
                        Icon(Icons.delete_outline, size: 18, color: AppColors.error),
                        SizedBox(width: 8),
                        Text('Eliminar Cita', style: TextStyle(color: AppColors.error)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
