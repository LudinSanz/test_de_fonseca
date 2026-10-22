import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../constants/colors.dart';
import '../models/examen_clinico.dart';
import '../models/paciente.dart';
import '../services/supabase_service.dart';

class UploadExamScreen extends StatefulWidget {
  final Paciente paciente;

  const UploadExamScreen({
    super.key,
    required this.paciente,
  });

  @override
  State<UploadExamScreen> createState() => _UploadExamScreenState();
}

class _UploadExamScreenState extends State<UploadExamScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _tituloController = TextEditingController();
  final TextEditingController _observacionesController = TextEditingController();
  final TextEditingController _zonaController = TextEditingController(text: 'ATM y Maxilares');

  String _tipoSeleccionado = 'radiografia'; // radiografia, pdf, imagen, otro
  String _subtipoSeleccionado = 'Panorámica';
  DateTime _fechaSeleccionada = DateTime.now();

  Uint8List? _fileBytes;
  String? _fileName;
  String? _fileExtension;
  int _fileSizeBytes = 0;
  bool _isSaving = false;

  final Map<String, List<String>> _subtiposPorCategoria = {
    'radiografia': ['Panorámica', 'Periapical', 'Cefalométrica', 'Tomografía CBCT', 'Aleta de Mordida (Bitewing)', 'Oclusal'],
    'pdf': ['Estudio PDF', 'Tomografía Computarizada', 'Informe de Laboratorio', 'Interconsulta Médica', 'Consentimiento Informado'],
    'imagen': ['Foto Intraoral', 'Foto Extraoral / Perfil', 'Oclusión y Mordida', 'Sonrisa Frontal', 'Control Fotográfico'],
    'otro': ['Resonancia Magnética (RMN)', 'Electromiografía', 'Audiometría', 'Otro Estudio Especializado'],
  };

  final List<String> _sugerenciasTitulos = [
    'Radiografía Panorámica Inicial',
    'Control ATM Post-Férula',
    'Radiografía Periapical',
    'Tomografía CBCT Mandibular',
    'Fotografía Clínica Intraoral',
    'Informe Cefalométrico Digital',
  ];

  @override
  void dispose() {
    _tituloController.dispose();
    _observacionesController.dispose();
    _zonaController.dispose();
    super.dispose();
  }

  // Pick file from device storage (PDFs, Images, Radiographs)
  Future<void> _seleccionarDesdeAlmacenamiento() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'webp', 'bmp'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.single;
        Uint8List? bytes = file.bytes;

        // If bytes are null on some mobile platforms, read from path
        if (bytes == null && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          final ext = file.extension?.toLowerCase() ?? '';
          setState(() {
            _fileBytes = bytes;
            _fileName = file.name;
            _fileExtension = ext;
            _fileSizeBytes = file.size;

            // Auto-detect type
            if (ext == 'pdf') {
              _tipoSeleccionado = 'pdf';
              _subtipoSeleccionado = 'Estudio PDF';
            } else {
              if (_tipoSeleccionado == 'pdf') {
                _tipoSeleccionado = 'radiografia';
                _subtipoSeleccionado = 'Panorámica';
              }
            }

            if (_tituloController.text.trim().isEmpty) {
              final cleanName = file.name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '').replaceAll('_', ' ');
              _tituloController.text = cleanName.isNotEmpty ? cleanName : 'Estudio Digital';
            }
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Archivo cargado desde el almacenamiento: ${file.name}'),
                backgroundColor: AppColors.success,
              ),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error al seleccionar archivo del celular: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo acceder al archivo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Capture photo with camera (physical X-ray or patient mouth)
  Future<void> _tomarFotoCamara() async {
    try {
      final picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 90,
      );

      if (photo != null) {
        final bytes = await photo.readAsBytes();
        final name = photo.name.isNotEmpty ? photo.name : 'captura_${DateTime.now().millisecondsSinceEpoch}.jpg';

        setState(() {
          _fileBytes = bytes;
          _fileName = name;
          _fileExtension = 'jpg';
          _fileSizeBytes = bytes.length;
          if (_tipoSeleccionado == 'pdf') {
            _tipoSeleccionado = 'radiografia';
            _subtipoSeleccionado = 'Panorámica';
          }
          if (_tituloController.text.trim().isEmpty) {
            _tituloController.text = 'Fotografía Clínica Directa';
          }
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Foto capturada correctamente con la cámara.'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error al capturar foto con la cámara: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Permiso o acceso a cámara denegado: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // Pick from Photo Gallery
  Future<void> _seleccionarDeGaleria() async {
    try {
      final picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );

      if (image != null) {
        final bytes = await image.readAsBytes();
        final name = image.name.isNotEmpty ? image.name : 'galeria_${DateTime.now().millisecondsSinceEpoch}.jpg';

        setState(() {
          _fileBytes = bytes;
          _fileName = name;
          _fileExtension = 'jpg';
          _fileSizeBytes = bytes.length;
          if (_tipoSeleccionado == 'pdf') {
            _tipoSeleccionado = 'radiografia';
            _subtipoSeleccionado = 'Panorámica';
          }
          if (_tituloController.text.trim().isEmpty) {
            _tituloController.text = 'Radiografía / Imagen de Galería';
          }
        });
      }
    } catch (e) {
      debugPrint('Error al seleccionar de galería: $e');
    }
  }

  void _mostrarOpcionesDeOrigen() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Seleccionar Origen del Documento o Examen',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Elige de dónde deseas jalar el examen del paciente:',
                  style: TextStyle(fontSize: 12, color: AppColors.textLight),
                ),
                const SizedBox(height: 20),

                // Option 1: Storage / Files (PDFs and images)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.folder_open_outlined, color: AppColors.primary),
                  ),
                  title: const Text('Almacenamiento del Celular (PDF / Archivos)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Archivos PDF, Tomografías, Documentos o Radiografías descargadas', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarDesdeAlmacenamiento();
                  },
                ),
                const SizedBox(height: 8),

                // Option 2: Camera
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.teal.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_outlined, color: Colors.teal),
                  ),
                  title: const Text('Tomar Foto con Cámara Clínica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Fotografiar negatoscopio físico, radiografía o cavidad bucal', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    Navigator.pop(context);
                    _tomarFotoCamara();
                  },
                ),
                const SizedBox(height: 8),

                // Option 3: Gallery
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_library_outlined, color: Colors.amber),
                  ),
                  title: const Text('Galería de Imágenes', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: const Text('Fotos o capturas guardadas en el álbum del teléfono', style: TextStyle(fontSize: 11, color: AppColors.textLight)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  onTap: () {
                    Navigator.pop(context);
                    _seleccionarDeGaleria();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _guardarExamen() async {
    if (!_formKey.currentState!.validate()) return;

    if (_fileBytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor selecciona un archivo o fotografía del examen.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    // Control de seguridad: Límite máximo de 15 MB para evitar saturación de memoria (OOM) y sobrecarga en almacenamiento
    const int maxFileSizeBytes = 15 * 1024 * 1024;
    if (_fileSizeBytes > maxFileSizeBytes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El archivo seleccionado supera el límite de 15 MB. Por favor optimiza el documento o imagen antes de subirlo.'),
          backgroundColor: AppColors.error,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final base64String = base64Encode(_fileBytes!);
      final String id = 'exam_${DateTime.now().millisecondsSinceEpoch}';

      final examen = ExamenClinico(
        id: id,
        pacienteId: widget.paciente.id,
        pacienteNombre: '${widget.paciente.nombre} ${widget.paciente.apellido}',
        titulo: _tituloController.text.trim(),
        tipo: _tipoSeleccionado,
        subtipo: _subtipoSeleccionado,
        zona: _zonaController.text.trim().isNotEmpty ? _zonaController.text.trim() : 'General',
        fecha: _fechaSeleccionada,
        observaciones: _observacionesController.text.trim(),
        fileName: _fileName ?? 'examen_$id.${_fileExtension ?? "jpg"}',
        fileType: _fileExtension == 'pdf' ? 'pdf' : 'image',
        fileSizeBytes: _fileSizeBytes,
        fileBase64: base64String,
        createdAt: DateTime.now(),
      );

      final supabaseService = SupabaseService();
      await supabaseService.guardarExamen(examen);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Examen guardado exitosamente en el Expediente 360°!'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, examen);
      }
    } catch (e) {
      debugPrint('Error al guardar examen: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar el examen: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final subtiposDisponibles = _subtiposPorCategoria[_tipoSeleccionado] ?? ['General'];

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
              'EXPEDIENTE 360°',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
                color: AppColors.primary,
              ),
            ),
            Text(
              'Digitalizar Radiografía o Examen Clínico',
              style: TextStyle(fontSize: 11, color: AppColors.textLight),
            ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Patient Banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryContainer],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [
                    BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white.withOpacity(0.2),
                      child: Text(
                        widget.paciente.nombre.isNotEmpty ? widget.paciente.nombre[0].toUpperCase() : 'P',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${widget.paciente.nombre} ${widget.paciente.apellido}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          Text(
                            'Tel: ${widget.paciente.telefono} • Expediente Activo',
                            style: TextStyle(color: Colors.white.withOpacity(0.85), fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Category Selector
              const Text(
                'Categoría de Estudio',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildCategoryChip('🩻 Radiografía', 'radiografia'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('📄 PDF', 'pdf'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('📷 Foto', 'imagen'),
                  const SizedBox(width: 8),
                  _buildCategoryChip('🔬 Otro', 'otro'),
                ],
              ),

              const SizedBox(height: 18),

              // File Selection Box
              const Text(
                'Archivo o Imagen del Estudio',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),

              _fileBytes == null
                  ? GestureDetector(
                      onTap: _mostrarOpcionesDeOrigen,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerLowest,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.4),
                            style: BorderStyle.solid,
                            width: 1.5,
                          ),
                          boxShadow: const [
                            BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.cloud_upload_outlined, color: AppColors.primary, size: 36),
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Toca para jalar examen del celular',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.onSurface),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Admite PDFs, Radiografías, Fotos con Cámara o Galería',
                              style: TextStyle(fontSize: 11, color: AppColors.textLight),
                            ),
                          ],
                        ),
                      ),
                    )
                  : _buildSelectedFilePreview(),

              const SizedBox(height: 20),

              // Subtype Dropdown
              const Text(
                'Subtipo de Examen',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.ghostOutline, width: 1.0),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: subtiposDisponibles.contains(_subtipoSeleccionado)
                        ? _subtipoSeleccionado
                        : subtiposDisponibles.first,
                    isExpanded: true,
                    icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.primary),
                    items: subtiposDisponibles.map((sub) {
                      return DropdownMenuItem<String>(
                        value: sub,
                        child: Text(sub, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) setState(() => _subtipoSeleccionado = val);
                    },
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Title input
              const Text(
                'Título / Nombre del Estudio *',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _tituloController,
                decoration: InputDecoration(
                  hintText: 'Ej: Radiografía Panorámica de Control',
                  hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Ingresa un título para el examen';
                  return null;
                },
              ),

              // Suggestions chips
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _sugerenciasTitulos.map((sug) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ActionChip(
                        label: Text(sug, style: const TextStyle(fontSize: 10, color: AppColors.primary)),
                        backgroundColor: AppColors.primary.withOpacity(0.08),
                        side: BorderSide.none,
                        onPressed: () {
                          setState(() => _tituloController.text = sug);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 18),

              // Row: Anatomical Zone & Date
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Zona / Pieza Dental',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _zonaController,
                          decoration: InputDecoration(
                            hintText: 'Ej: ATM y Cóndilos',
                            hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 12),
                            filled: true,
                            fillColor: AppColors.surfaceContainerLowest,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Fecha del Estudio',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
                        ),
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _fechaSeleccionada,
                              firstDate: DateTime(2000),
                              lastDate: DateTime.now().add(const Duration(days: 30)),
                            );
                            if (picked != null) setState(() => _fechaSeleccionada = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerLowest,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.ghostOutline),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '${_fechaSeleccionada.day}/${_fechaSeleccionada.month}/${_fechaSeleccionada.year}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.onSurface),
                                ),
                                const Icon(Icons.calendar_today, size: 16, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Radiographic findings / Notes
              const Text(
                'Hallazgos Radiográficos / Observaciones del Especialista',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.onSurface),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _observacionesController,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Anota detalles clínicos, presencia de terceros molares, nivel óseo alveolar, cóndilos mandibulares o diagnóstico...',
                  hintStyle: const TextStyle(color: AppColors.textLight, fontSize: 12),
                  filled: true,
                  fillColor: AppColors.surfaceContainerLowest,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.ghostOutline)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AppColors.primary, width: 1.8)),
                ),
              ),

              const SizedBox(height: 28),

              // Save Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSaving ? null : _guardarExamen,
                  icon: _isSaving
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Icon(Icons.save_outlined, color: Colors.white),
                  label: Text(
                    _isSaving ? 'Guardando en Expediente...' : 'Guardar en Expediente 360°',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    elevation: 3,
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(String label, String value) {
    final isSelected = _tipoSeleccionado == value;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tipoSeleccionado = value;
            final subs = _subtiposPorCategoria[value] ?? [];
            if (subs.isNotEmpty) _subtipoSeleccionado = subs.first;
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.ghostOutline,
            ),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isSelected ? Colors.white : AppColors.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectedFilePreview() {
    final bool isPdf = _fileExtension == 'pdf';
    final String sizeText = (_fileSizeBytes / 1024).toStringAsFixed(1) + ' KB';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowSoft, blurRadius: 16, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          // Thumbnail / PDF badge
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: isPdf
                ? Container(
                    width: 60,
                    height: 60,
                    color: Colors.red.withOpacity(0.12),
                    child: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                  )
                : Image.memory(
                    _fileBytes!,
                    width: 60,
                    height: 60,
                    fit: BoxFit.cover,
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fileName ?? 'Archivo seleccionado',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.onSurface),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$sizeText • ${_fileExtension?.toUpperCase() ?? "ARCHIVO"}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLight),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.check_circle, size: 14, color: AppColors.success),
                    const SizedBox(width: 4),
                    const Text('Listo para subir', style: TextStyle(fontSize: 11, color: AppColors.success, fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.change_circle_outlined, color: AppColors.primary),
            tooltip: 'Cambiar archivo',
            onPressed: _mostrarOpcionesDeOrigen,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, color: AppColors.error),
            tooltip: 'Remover',
            onPressed: () {
              setState(() {
                _fileBytes = null;
                _fileName = null;
                _fileSizeBytes = 0;
              });
            },
          ),
        ],
      ),
    );
  }
}
