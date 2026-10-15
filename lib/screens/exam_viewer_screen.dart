import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/colors.dart';
import '../models/examen_clinico.dart';
import '../models/paciente.dart';

class ExamViewerScreen extends StatefulWidget {
  final ExamenClinico examen;
  final Paciente? paciente;

  const ExamViewerScreen({
    super.key,
    required this.examen,
    this.paciente,
  });

  @override
  State<ExamViewerScreen> createState() => _ExamViewerScreenState();
}

class _ExamViewerScreenState extends State<ExamViewerScreen> {
  final TransformationController _transformationController = TransformationController();
  bool _isInverted = false;
  bool _showDetailsSheet = false;
  Uint8List? _imageBytes;

  @override
  void initState() {
    super.initState();
    _loadImageBytes();
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  void _loadImageBytes() {
    if (widget.examen.fileBase64 != null && widget.examen.fileBase64!.isNotEmpty) {
      try {
        setState(() {
          _imageBytes = base64Decode(widget.examen.fileBase64!);
        });
      } catch (e) {
        debugPrint('Error decodificando base64 de imagen: $e');
      }
    }
  }

  void _resetZoom() {
    setState(() {
      _transformationController.value = Matrix4.identity();
    });
  }

  void _zoomIn() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale < 4.0) {
      _transformationController.value = _transformationController.value.scaled(1.3, 1.3, 1.0);
      setState(() {});
    }
  }

  void _zoomOut() {
    final currentScale = _transformationController.value.getMaxScaleOnAxis();
    if (currentScale > 0.8) {
      _transformationController.value = _transformationController.value.scaled(0.75, 0.75, 1.0);
      setState(() {});
    }
  }

  void _compartirWhatsApp() async {
    final tel = widget.paciente?.telefono ?? '';
    final cleanPhone = tel.replaceAll(RegExp(r'[^\d+]'), '');
    final nombre = widget.paciente != null
        ? '${widget.paciente!.nombre} ${widget.paciente!.apellido}'
        : widget.examen.pacienteNombre;

    final mensaje = '🦷 *RIZO DENTAL • EXPEDIENTE CLÍNICO 360°*\n\n'
        'Estimado(a) *$nombre*,\n'
        'Le compartimos la información de su estudio radiográfico / clínico realizado en nuestra clínica:\n\n'
        '📋 *Estudio:* ${widget.examen.titulo}\n'
        '🩻 *Categoría:* ${widget.examen.tipoLabel} (${widget.examen.subtipo})\n'
        '📅 *Fecha:* ${widget.examen.fecha.day}/${widget.examen.fecha.month}/${widget.examen.fecha.year}\n'
        '🎯 *Zona:* ${widget.examen.zona}\n\n'
        '📝 *Observaciones Clínicas del Especialista:*\n'
        '${widget.examen.observaciones.isNotEmpty ? widget.examen.observaciones : "Estudio archivado en su expediente digital sin novedades patológicas inmediatas."}\n\n'
        '📍 *Rizo Dental Sanctuary*\n'
        'Dra. María Rizo • Especialista ATM & Odontología Integral';

    final uri = Uri.parse('https://wa.me/$cleanPhone?text=${Uri.encodeComponent(mensaje)}');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir WhatsApp.')),
          );
        }
      }
    } catch (e) {
      debugPrint('Error abriendo WhatsApp: $e');
    }
  }

  Future<void> _imprimirOCompartirDocumento() async {
    if (_imageBytes != null) {
      await Printing.sharePdf(
        bytes: _imageBytes!,
        filename: widget.examen.fileName,
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Este es un estudio de demostración registrado en el expediente.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPdf = widget.examen.isPdf;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Slate 900 - Dark Medical Viewer
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.examen.titulo,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            Text(
              '${widget.examen.tipoLabel} • ${widget.examen.fecha.day}/${widget.examen.fecha.month}/${widget.examen.fecha.year}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.7),
                fontSize: 11,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline, color: Color(0xFF25D366)),
            tooltip: 'Compartir por WhatsApp',
            onPressed: _compartirWhatsApp,
          ),
          IconButton(
            icon: Icon(
              _showDetailsSheet ? Icons.info : Icons.info_outline,
              color: AppColors.primary,
            ),
            tooltip: 'Detalles Clínicos',
            onPressed: () {
              setState(() => _showDetailsSheet = !_showDetailsSheet);
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // Main Viewer Canvas
          Positioned.fill(
            child: isPdf ? _buildPdfViewer() : _buildImageViewer(),
          ),

          // Floating Toolbars for Medical Imaging (Zoom, Invert, Reset)
          if (!isPdf)
            Positioned(
              left: 16,
              bottom: 30,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.12)),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 16, offset: Offset(0, 4)),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                      tooltip: 'Alejar',
                      onPressed: _zoomOut,
                    ),
                    IconButton(
                      icon: const Icon(Icons.restart_alt, color: Colors.white70, size: 20),
                      tooltip: 'Reiniciar escala',
                      onPressed: _resetZoom,
                    ),
                    IconButton(
                      icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                      tooltip: 'Acercar',
                      onPressed: _zoomIn,
                    ),
                    Container(height: 20, width: 1, color: Colors.white24, margin: const EdgeInsets.symmetric(horizontal: 4)),
                    IconButton(
                      icon: Icon(
                        _isInverted ? Icons.invert_colors : Icons.invert_colors_off,
                        color: _isInverted ? AppColors.primary : Colors.white70,
                        size: 20,
                      ),
                      tooltip: 'Modo Negativo / Rayos X',
                      onPressed: () {
                        setState(() => _isInverted = !_isInverted);
                      },
                    ),
                  ],
                ),
              ),
            ),

          // Bottom Clinical Sheet Overlay
          if (_showDetailsSheet)
            Positioned(
              left: 16,
              right: 16,
              bottom: 24,
              child: _buildDetailsCard(),
            ),
        ],
      ),
    );
  }

  Widget _buildImageViewer() {
    Widget imageContent;

    if (_imageBytes != null) {
      imageContent = Image.memory(
        _imageBytes!,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) => _buildPlaceholderRadiography(),
      );
    } else {
      imageContent = _buildPlaceholderRadiography();
    }

    if (_isInverted) {
      imageContent = ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          -1, 0, 0, 0, 255,
          0, -1, 0, 0, 255,
          0, 0, -1, 0, 255,
          0, 0, 0, 1, 0,
        ]),
        child: imageContent,
      );
    }

    return InteractiveViewer(
      transformationController: _transformationController,
      minScale: 0.7,
      maxScale: 6.0,
      boundaryMargin: const EdgeInsets.all(80),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageContent,
          ),
        ),
      ),
    );
  }

  Widget _buildPdfViewer() {
    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.12)),
          boxShadow: const [
            BoxShadow(color: Colors.black45, blurRadius: 20, offset: Offset(0, 8)),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.picture_as_pdf, color: Colors.redAccent, size: 54),
            ),
            const SizedBox(height: 18),
            Text(
              widget.examen.titulo,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              'Archivo: ${widget.examen.fileName} • ${widget.examen.formattedSize}',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                widget.examen.observaciones.isNotEmpty
                    ? widget.examen.observaciones
                    : 'Documento clínico digitalizado.',
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: _imprimirOCompartirDocumento,
                  icon: const Icon(Icons.print_outlined, size: 18, color: Colors.white),
                  label: const Text('Imprimir / Ver', style: TextStyle(color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: _compartirWhatsApp,
                  icon: const Icon(Icons.chat_bubble_outline, size: 18, color: Color(0xFF25D366)),
                  label: const Text('WhatsApp', style: TextStyle(color: Color(0xFF25D366))),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF25D366), width: 1.2),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderRadiography() {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxHeight: 460),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.biotech_outlined, color: AppColors.primary, size: 50),
          ),
          const SizedBox(height: 16),
          Text(
            widget.examen.titulo,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            '${widget.examen.subtipo} • ${widget.examen.zona}',
            style: TextStyle(color: AppColors.primary.withOpacity(0.9), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notes, color: Colors.white54, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Hallazgos Radiográficos Registrados:',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  widget.examen.observaciones.isNotEmpty
                      ? widget.examen.observaciones
                      : 'Estudio de control archivado en el expediente clínico digital.',
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withOpacity(0.96),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 24, offset: Offset(0, 8)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Ficha del Estudio Clínico',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white70, size: 20),
                onPressed: () => setState(() => _showDetailsSheet = false),
              ),
            ],
          ),
          const Divider(color: Colors.white12, height: 16),
          _buildInfoRow('Paciente:', widget.paciente != null ? '${widget.paciente!.nombre} ${widget.paciente!.apellido}' : widget.examen.pacienteNombre),
          _buildInfoRow('Tipo de Estudio:', '${widget.examen.tipoLabel} (${widget.examen.subtipo})'),
          _buildInfoRow('Zona Anatómica:', widget.examen.zona),
          _buildInfoRow('Fecha de Realización:', '${widget.examen.fecha.day}/${widget.examen.fecha.month}/${widget.examen.fecha.year}'),
          _buildInfoRow('Archivo:', '${widget.examen.fileName} (${widget.examen.formattedSize})'),
          const SizedBox(height: 8),
          const Text(
            'Diagnóstico / Observaciones:',
            style: TextStyle(color: Colors.white54, fontSize: 12, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF0F172A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.examen.observaciones.isNotEmpty ? widget.examen.observaciones : 'Sin observaciones adicionales.',
              style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
