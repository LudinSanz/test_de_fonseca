import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';
import '../utils/pdf_generator.dart';
import '../widgets/signature_pad.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  bool _isLoading = true;
  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;

  final List<Map<String, dynamic>> _medicamentos = [
    {
      'nombre': 'Ibuprofeno 600mg',
      'dosis': '1 tableta',
      'frecuencia_horas': 8,
      'dias': 5,
      'indicaciones': 'Tomar después de las comidas principal para inflamación ATM',
    }
  ];

  final TextEditingController _indicacionesGeneralesController = TextEditingController(
    text: 'Mantener reposo mandibular, dieta blanda por 7 días y evitar masticar hielo o chicle.',
  );

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final res = await supabase.from('pacientes').select();
      final list = (res as List)
          .map((m) => Paciente.fromMap(Map<String, dynamic>.from(m), m['id'].toString()))
          .toList();

      setState(() {
        _pacientes = list;
        if (list.isNotEmpty) {
          _pacienteSeleccionado = list.first;
        }
      });
    } catch (e) {
      debugPrint('Error al cargar pacientes en Receta: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _abrirModalAgregarMedicamento() {
    final nombreCtrl = TextEditingController();
    final dosisCtrl = TextEditingController(text: '1 tableta');
    final horasCtrl = TextEditingController(text: '8');
    final diasCtrl = TextEditingController(text: '5');
    final obsCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Agregar Medicamento a Receta', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: nombreCtrl, decoration: _inputDecoration('Nombre de medicamento (ej: Amoxicilina 500mg)')),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: dosisCtrl, decoration: _inputDecoration('Dosis (ej: 1 cápsula)'))),
                  const SizedBox(width: 8),
                  Expanded(child: TextField(controller: horasCtrl, keyboardType: TextInputType.number, decoration: _inputDecoration('Cada (horas)'))),
                ],
              ),
              const SizedBox(height: 12),
              TextField(controller: diasCtrl, keyboardType: TextInputType.number, decoration: _inputDecoration('Por cuantos días')),
              const SizedBox(height: 12),
              TextField(controller: obsCtrl, decoration: _inputDecoration('Indicación específica')),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nombreCtrl.text.trim().isNotEmpty) {
                setState(() {
                  _medicamentos.add({
                    'nombre': nombreCtrl.text.trim(),
                    'dosis': dosisCtrl.text.trim(),
                    'frecuencia_horas': int.tryParse(horasCtrl.text.trim()) ?? 8,
                    'dias': int.tryParse(diasCtrl.text.trim()) ?? 5,
                    'indicaciones': obsCtrl.text.trim(),
                  });
                });
                Navigator.pop(ctx);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
  }

  Future<void> _pedirFirmaYProcesarReceta({required bool viaWhatsApp}) async {
    if (_pacienteSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor selecciona un paciente primero'), backgroundColor: AppColors.error),
      );
      return;
    }

    final supabase = Supabase.instance.client;
    final doctorRes = await supabase.from('users').select().eq('email', supabase.auth.currentUser?.email ?? '').maybeSingle();
    
    final doctorName = doctorRes?['name'] ?? 'Dr. Rizo Dental';
    final doctorColegiado = doctorRes?['colegiado'] ?? '0000';

    if (!mounted) return;

    final firmaObtenida = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SignaturePadDialog(
        doctorName: doctorName,
        doctorColegiado: doctorColegiado,
      ),
    );

    if (firmaObtenida != null && firmaObtenida.isNotEmpty) {
      await _guardarYEnviarReceta(
        viaWhatsApp: viaWhatsApp,
        firmaDigitalConfirmada: firmaObtenida,
      );
    }
  }

  Future<void> _guardarYEnviarReceta({required bool viaWhatsApp, required String firmaDigitalConfirmada}) async {
    final supabase = Supabase.instance.client;
    final doctorRes = await supabase.from('users').select().eq('email', supabase.auth.currentUser?.email ?? '').maybeSingle();

    final String medTexto = _medicamentos.map((m) => '• ${m['nombre']} (${m['dosis']}) - C/${m['frecuencia_horas']}h por ${m['dias']} días').join('\n');

    final recetaData = {
      'id': 'receta_${DateTime.now().millisecondsSinceEpoch}',
      'paciente_id': _pacienteSeleccionado!.id,
      'paciente_nombre': '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
      'fecha': DateTime.now().toIso8601String(),
      'medicamentos': medTexto,
      'indicaciones': _indicacionesGeneralesController.text.trim(),
      'indicaciones_generales': _indicacionesGeneralesController.text.trim(),
      'doctor_nombre': doctorRes?['name'] ?? 'Dr. Rizo Dental',
      'firma_digital': firmaDigitalConfirmada.isNotEmpty ? firmaDigitalConfirmada : (doctorRes?['firma_digital'] ?? 'Rizo Dental Sanctuary Digital Seal'),
    };

    try {
      await supabase.from('recetas').upsert(recetaData);
    } catch (e) {
      debugPrint('Error al guardar receta en Supabase: $e');
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('¡Receta firmada y guardada exitosamente en el historial del paciente!'),
        backgroundColor: AppColors.success,
        behavior: SnackBarBehavior.floating,
      ),
    );

    if (viaWhatsApp) {
      final tel = _pacienteSeleccionado!.telefono;
      final nombre = '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}';
      final buffer = StringBuffer();
      buffer.writeln('📋 *RECETA MÉDICA - RIZO DENTAL SANCTUARY*');
      buffer.writeln('Paciente: $nombre');
      buffer.writeln('Fecha: ${DateTime.now().toString().split(' ')[0]}');
      buffer.writeln('\n*Medicamentos Prescritos:*');
      for (var m in _medicamentos) {
        buffer.writeln('• ${m['nombre']} - ${m['dosis']} cada ${m['frecuencia_horas']} hrs por ${m['dias']} días.');
      }
      if (_indicacionesGeneralesController.text.isNotEmpty) {
        buffer.writeln('\n*Indicaciones:* ${_indicacionesGeneralesController.text.trim()}');
      }
      buffer.writeln('\n_Firma: ${firmaDigitalConfirmada}_');

      String cleanPhone = tel.replaceAll(RegExp(r'[^\d]'), '');
      if (!cleanPhone.startsWith('502') && cleanPhone.length == 8) {
        cleanPhone = '502$cleanPhone';
      }
      final url = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(buffer.toString())}');

      try {
        if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
          await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
        }
      } catch (e) {
        await launchUrl(url, mode: LaunchMode.externalNonBrowserApplication);
      }
    } else {
      Map<String, dynamic> doctorInfoFinal = Map<String, dynamic>.from(doctorRes ?? {});
      doctorInfoFinal['firma_digital'] = firmaDigitalConfirmada;

      await PdfGenerator.generarPdfReceta(
        paciente: _pacienteSeleccionado!,
        medicamentos: _medicamentos,
        indicaciones: _indicacionesGeneralesController.text.trim(),
        doctorInfo: doctorInfoFinal,
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
                Icons.medical_services_outlined,
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
                  'Emisión de Recetas Médicas',
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
                    // Patient Selector Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('1. Paciente Destinatario:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          const SizedBox(height: 8),
                          DropdownButtonFormField<Paciente>(
                            value: _pacienteSeleccionado,
                            decoration: _inputDecoration('Seleccionar Paciente de la Clínica'),
                            dropdownColor: AppColors.surfaceContainerLowest,
                            items: _pacientes.map((p) {
                              return DropdownMenuItem(
                                value: p,
                                child: Text('${p.nombre} ${p.apellido} (${p.telefono})'),
                              );
                            }).toList(),
                            onChanged: (val) => setState(() => _pacienteSeleccionado = val),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Medications List Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('2. Prescripción de Medicamentos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
                                onPressed: _abrirModalAgregarMedicamento,
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          for (var i = 0; i < _medicamentos.length; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.medication_liquid_outlined, color: AppColors.primary),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${_medicamentos[i]['nombre']} (${_medicamentos[i]['dosis']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                        Text('Cada ${_medicamentos[i]['frecuencia_horas']} hrs por ${_medicamentos[i]['dias']} días', style: const TextStyle(fontSize: 12, color: AppColors.textLight)),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    onPressed: () {
                                      setState(() {
                                        _medicamentos.removeAt(i);
                                      });
                                    },
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    // General Indications Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 20, offset: Offset(0, 6)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('3. Indicaciones y Cuidados Especiales:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.primary)),
                          const SizedBox(height: 8),
                          TextField(
                            controller: _indicacionesGeneralesController,
                            maxLines: 3,
                            decoration: _inputDecoration('Indicaciones generales para el paciente'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: OutlinedButton.icon(
                              icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
                              label: const Text('Exportar PDF Rizo', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary)),
                              onPressed: () => _pedirFirmaYProcesarReceta(viaWhatsApp: false),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(color: AppColors.ghostOutline, width: 1.2),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: SizedBox(
                            height: 52,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.send_to_mobile, color: Colors.white),
                              label: const Text('Enviar WhatsApp', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                              onPressed: () => _pedirFirmaYProcesarReceta(viaWhatsApp: true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.success,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
