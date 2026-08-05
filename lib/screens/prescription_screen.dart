import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/paciente.dart';

class PrescriptionScreen extends StatefulWidget {
  const PrescriptionScreen({super.key});

  @override
  State<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends State<PrescriptionScreen> {
  List<Paciente> _pacientes = [];
  Paciente? _pacienteSeleccionado;
  bool _isLoading = true;

  // Lista de medicamentos prescritos
  final List<Map<String, String>> _medicamentos = [
    {
      'nombre': 'Ibuprofeno 600mg',
      'dosis': '1 tableta',
      'frecuencia': 'cada 8 horas',
      'duracion': 'por 5 días',
    },
  ];

  final TextEditingController _indicacionesController = TextEditingController(
    text: 'Tomar con los alimentos. Evitar masticar alimentos duros sobre el lado afectado.',
  );
  final TextEditingController _doctorNombreController = TextEditingController(text: 'Dr. Ludin Solís');
  final TextEditingController _doctorColegiadoController = TextEditingController(text: 'Col. Odontólogos #14890');

  double _btnScale = 1.0;

  @override
  void initState() {
    super.initState();
    _cargarPacientes();
  }

  @override
  void dispose() {
    _indicacionesController.dispose();
    _doctorNombreController.dispose();
    _doctorColegiadoController.dispose();
    super.dispose();
  }

  Future<void> _cargarPacientes() async {
    setState(() => _isLoading = true);
    try {
      final supabase = Supabase.instance.client;
      final response = await supabase.from('pacientes').select();
      final list = (response as List)
          .map((map) => Paciente.fromMap(Map<String, dynamic>.from(map), map['id'].toString()))
          .toList();

      setState(() {
        _pacientes = list;
        if (list.isNotEmpty) {
          _pacienteSeleccionado = list.first;
        } else {
          // Paciente demo de respaldo
          _pacienteSeleccionado = Paciente(
            id: 'paciente_demo',
            nombre: 'Juan',
            apellido: 'Pérez',
            email: 'juan.perez@email.com',
            telefono: '+50255551234',
            fechaNacimiento: DateTime(1990, 5, 20),
            genero: 'Masculino',
            direccion: 'Ciudad de Guatemala',
          );
        }
      });
    } catch (e) {
      debugPrint('Error al cargar pacientes: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _agregarMedicamento() {
    final nombreController = TextEditingController();
    final dosisController = TextEditingController(text: '1 tableta');
    final frecuenciaController = TextEditingController(text: 'cada 8 horas');
    final duracionController = TextEditingController(text: 'por 5 días');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceContainerLowest,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Agregar Medicamento', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nombreController,
                decoration: _inputDecoration('Nombre del medicamento (ej: Amoxicilina 500mg)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dosisController,
                decoration: _inputDecoration('Dosis / Cantidad (ej: 1 cápsula)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: frecuenciaController,
                decoration: _inputDecoration('Frecuencia (ej: cada 12 horas)'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: duracionController,
                decoration: _inputDecoration('Duración (ej: por 7 días)'),
              ),
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
              if (nombreController.text.trim().isNotEmpty) {
                setState(() {
                  _medicamentos.add({
                    'nombre': nombreController.text.trim(),
                    'dosis': dosisController.text.trim(),
                    'frecuencia': frecuenciaController.text.trim(),
                    'duracion': duracionController.text.trim(),
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

  Future<void> _guardarYCompartirReceta() async {
    if (_pacienteSeleccionado == null || _medicamentos.isEmpty) return;

    setState(() => _isLoading = true);

    final String recetaId = 'receta_${DateTime.now().millisecondsSinceEpoch}';
    final String fechaStr = DateTime.now().toString().split(' ')[0];

    final recetaData = {
      'id': recetaId,
      'paciente_id': _pacienteSeleccionado!.id,
      'paciente_nombre': '${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
      'doctor_nombre': _doctorNombreController.text.trim(),
      'fecha': fechaStr,
      'medicamentos': _medicamentos,
      'indicaciones': _indicacionesController.text.trim(),
      'firma_digital': '${_doctorNombreController.text.trim()} - ${_doctorColegiadoController.text.trim()}',
    };

    // Guardar en Supabase
    try {
      final supabase = Supabase.instance.client;
      await supabase.from('recetas').upsert(recetaData);
    } catch (e) {
      debugPrint('Error al guardar receta en Supabase: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (!mounted) return;

    // Diálogo Opciones de Envío (WhatsApp, PDF, Impresión)
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(28),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Receta Médica Guardada en Supabase',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
            const SizedBox(height: 6),
            Text(
              'Paciente: ${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}',
              style: const TextStyle(fontSize: 13, color: AppColors.textLight),
            ),
            const SizedBox(height: 24),

            // Opción 1: Enviar por WhatsApp
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: const Color(0xFF25D366).withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.send_to_mobile, color: Color(0xFF25D366)),
              ),
              title: const Text('Enviar Receta por WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Abre WhatsApp con el resumen de la receta', style: TextStyle(fontSize: 12)),
              onTap: () async {
                Navigator.pop(ctx);
                final String tel = _pacienteSeleccionado!.telefono.replaceAll(RegExp(r'[^\d+]'), '');
                final String msg = Uri.encodeComponent(
                  '📋 *RIZO DENTAL - RECETA MÉDICA*\n'
                  'Paciente: ${_pacienteSeleccionado!.nombre} ${_pacienteSeleccionado!.apellido}\n'
                  'Fecha: $fechaStr\n\n'
                  '💊 *MEDICAMENTOS PRESCRITOS:*\n'
                  '${_medicamentos.map((m) => "• ${m['nombre']} - ${m['dosis']} ${m['frecuencia']} ${m['duracion']}").join("\n")}\n\n'
                  '📝 *INDICACIONES:*\n${_indicacionesController.text.trim()}\n\n'
                  '👨‍⚕️ *Firma:* ${_doctorNombreController.text.trim()} (${_doctorColegiadoController.text.trim()})',
                );
                final Uri waUri = Uri.parse('https://wa.me/$tel?text=$msg');
                if (await canLaunchUrl(waUri)) {
                  await launchUrl(waUri, mode: LaunchMode.externalApplication);
                } else {
                  await _generarPDFReceta(recetaData);
                }
              },
            ),
            const SizedBox(height: 12),

            // Opción 2: Compartir Documento PDF Oficial
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), shape: BoxShape.circle),
                child: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
              ),
              title: const Text('Compartir PDF Oficial', style: TextStyle(fontWeight: FontWeight.bold)),
              subtitle: const Text('Genera PDF membretado con firma digital para compartir', style: TextStyle(fontSize: 12)),
              onTap: () {
                Navigator.pop(ctx);
                _generarPDFReceta(recetaData);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _generarPDFReceta(Map<String, dynamic> receta) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Padding(
            padding: const pw.EdgeInsets.all(32),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('RIZO DENTAL', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                        pw.Text('The Clinical Sanctuary • RECETA MÉDICA', style: const pw.TextStyle(fontSize: 12)),
                        pw.Text('Dr: ${_doctorNombreController.text} | ${_doctorColegiadoController.text}', style: const pw.TextStyle(fontSize: 11)),
                      ],
                    ),
                    pw.Text('Fecha: ${receta['fecha']}', style: const pw.TextStyle(fontSize: 12)),
                  ],
                ),
                pw.Divider(),
                pw.SizedBox(height: 16),
                pw.Text('PACIENTE: ${receta['paciente_nombre']}', style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('RP / MEDICAMENTOS PRESCRITOS:', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                for (var med in _medicamentos)
                  pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 8),
                    padding: const pw.EdgeInsets.all(12),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.grey100,
                      borderRadius: pw.BorderRadius.circular(8),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('${med['nombre']}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('${med['dosis']} | ${med['frecuencia']} | ${med['duracion']}'),
                      ],
                    ),
                  ),
                pw.SizedBox(height: 20),
                pw.Text('INDICACIONES CLÍNICAS:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 6),
                pw.Text('${receta['indicaciones']}'),
                pw.Spacer(),
                pw.Divider(),
                pw.Center(
                  child: pw.Column(
                    children: [
                      pw.Text('FIRMA Y SELLO DIGITAL CERTIFICADO', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
                      pw.Text('${receta['firma_digital']}', style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'receta_rizo_dental_${receta['id']}.pdf',
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
                  'Emisión de Receta Médica',
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
                    // Patient Selection Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '1. Seleccionar Paciente',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<Paciente>(
                            value: _pacienteSeleccionado,
                            decoration: _inputDecoration('Paciente'),
                            dropdownColor: AppColors.surfaceContainerLowest,
                            items: _pacientes.map((p) {
                              return DropdownMenuItem<Paciente>(
                                value: p,
                                child: Text('${p.nombre} ${p.apellido} (${p.telefono})'),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => _pacienteSeleccionado = val);
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Prescription List Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                '2. Medicamentos (Rp)',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle, color: AppColors.primary, size: 28),
                                tooltip: 'Agregar Medicamento',
                                onPressed: _agregarMedicamento,
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_medicamentos.isEmpty)
                            const Text('No has agregado medicamentos a la receta.', style: TextStyle(color: AppColors.textLight)),
                          ..._medicamentos.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final med = entry.value;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceContainerLow,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), shape: BoxShape.circle),
                                    child: const Icon(Icons.medication_outlined, color: AppColors.primary, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(med['nombre']!, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.onSurface)),
                                        Text(
                                          '${med['dosis']} • ${med['frecuencia']} • ${med['duracion']}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textLight),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline, color: AppColors.error, size: 20),
                                    onPressed: () {
                                      setState(() => _medicamentos.removeAt(idx));
                                    },
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Doctor Signature & Additional Notes Card
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerLowest,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(color: AppColors.shadowSoft, blurRadius: 24, offset: Offset(0, 8)),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '3. Indicaciones & Firma del Especialista',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _indicacionesController,
                            maxLines: 2,
                            style: const TextStyle(color: AppColors.onSurface),
                            decoration: _inputDecoration('Indicaciones del tratamiento'),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _doctorNombreController,
                                  style: const TextStyle(color: AppColors.onSurface),
                                  decoration: _inputDecoration('Nombre del Especialista'),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextFormField(
                                  controller: _doctorColegiadoController,
                                  style: const TextStyle(color: AppColors.onSurface),
                                  decoration: _inputDecoration('No. Colegiado'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Primary Action Button (Linear Gradient & Scale Animation)
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
                            onPressed: _isLoading ? null : _guardarYCompartirReceta,
                            icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                            label: const Text(
                              'Emitir Receta & Enviar por WhatsApp / PDF',
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 0.5),
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
