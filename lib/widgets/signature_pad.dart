import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/colors.dart';
import '../utils/pdf_generator.dart';

class DoctorSignatureData {
  final String textFirma;
  final Uint8List? pngBytes;

  DoctorSignatureData({
    required this.textFirma,
    this.pngBytes,
  });
}

class SignatureCanvasWidget extends StatefulWidget {
  final List<Offset?> points;
  final VoidCallback onClear;
  final Function(Offset localPos)? onPanUpdate;
  final VoidCallback? onPanEnd;
  final String? placeholder;

  const SignatureCanvasWidget({
    super.key,
    required this.points,
    required this.onClear,
    this.onPanUpdate,
    this.onPanEnd,
    this.placeholder,
  });

  @override
  State<SignatureCanvasWidget> createState() => _SignatureCanvasWidgetState();
}

class _SignatureCanvasWidgetState extends State<SignatureCanvasWidget> {
  final GlobalKey _canvasKey = GlobalKey();

  bool get _hasSignature => widget.points.where((p) => p != null).isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _canvasKey,
      height: 180,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.ghostOutline, width: 1.2),
      ),
      child: Stack(
        children: [
          GestureDetector(
            onPanStart: (details) {
              final RenderBox? renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                final Offset localPos = renderBox.globalToLocal(details.globalPosition);
                widget.onPanUpdate?.call(localPos);
              }
            },
            onPanUpdate: (details) {
              final RenderBox? renderBox = _canvasKey.currentContext?.findRenderObject() as RenderBox?;
              if (renderBox != null) {
                final Offset localPos = renderBox.globalToLocal(details.globalPosition);
                widget.onPanUpdate?.call(localPos);
              }
            },
            onPanEnd: (details) {
              widget.onPanEnd?.call();
            },
            child: CustomPaint(
              painter: SignaturePainter(widget.points),
              size: Size.infinite,
            ),
          ),
          if (!_hasSignature)
            Center(
              child: Text(
                widget.placeholder ?? 'Trace su firma aquí con el dedo o lápiz táctil ✍️',
                style: const TextStyle(color: AppColors.textLight, fontSize: 13, fontStyle: FontStyle.italic),
              ),
            ),
          if (_hasSignature)
            Positioned(
              right: 8,
              top: 8,
              child: TextButton.icon(
                onPressed: widget.onClear,
                icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: AppColors.error),
                label: const Text('Limpiar', style: TextStyle(fontSize: 12, color: AppColors.error)),
              ),
            ),
        ],
      ),
    );
  }
}

class SignaturePadDialog extends StatefulWidget {
  final String doctorName;
  final String doctorColegiado;
  final String tituloDocumento;

  const SignaturePadDialog({
    super.key,
    required this.doctorName,
    required this.doctorColegiado,
    this.tituloDocumento = 'Documento Clínico Oficial',
  });

  static Future<DoctorSignatureData?> pedirFirma(
    BuildContext context, {
    String doctorName = 'Dr. Ludin Solís',
    String doctorColegiado = '98421',
    String tituloDocumento = 'Documento Clínico Oficial',
  }) async {
    return await showDialog<DoctorSignatureData>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => SignaturePadDialog(
        doctorName: doctorName,
        doctorColegiado: doctorColegiado,
        tituloDocumento: tituloDocumento,
      ),
    );
  }

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<Offset?> _points = [];
  bool _procesandoFirma = false;

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
  }

  bool get _hasSignature => _points.where((p) => p != null).isNotEmpty;

  Future<void> _confirmarFirma() async {
    setState(() => _procesandoFirma = true);
    try {
      Uint8List? pngBytes;
      if (_hasSignature) {
        pngBytes = await PdfGenerator.signaturePointsToPngBytes(_points);
      }
      final textFirma = 'Firma y Sello Oficial del Dr. ${widget.doctorName} (Colegiado #${widget.doctorColegiado})';
      
      if (!mounted) return;
      Navigator.pop(
        context,
        DoctorSignatureData(
          textFirma: textFirma,
          pngBytes: pngBytes,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _procesandoFirma = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.draw_outlined, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Firma Requerida del Especialista',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.onSurface),
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.description_outlined, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Documento: ${widget.tituloDocumento}',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Para que este documento tenga validez legal y clínica oficial, debes firmar en el recuadro antes de exportar o guardar el PDF:',
              style: TextStyle(fontSize: 12, color: AppColors.textLight, height: 1.3),
            ),
            const SizedBox(height: 12),
            SignatureCanvasWidget(
              points: _points,
              onClear: _clearSignature,
              onPanUpdate: (pos) {
                setState(() => _points.add(pos));
              },
              onPanEnd: () {
                setState(() => _points.add(null));
              },
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${widget.doctorName} • Colegiado #${widget.doctorColegiado}',
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: AppColors.primary),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _procesandoFirma ? null : () => Navigator.pop(context, null),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
        ),
        ElevatedButton.icon(
          onPressed: (_hasSignature && !_procesandoFirma) ? _confirmarFirma : null,
          icon: _procesandoFirma
              ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
              : const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          label: Text(
            _procesandoFirma ? 'Procesando...' : 'Autorizar y Generar PDF',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 13),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ],
    );
  }
}

class SignaturePainter extends CustomPainter {
  final List<Offset?> points;

  SignaturePainter(this.points);

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = AppColors.primary
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.5;

    for (int i = 0; i < points.length - 1; i++) {
      if (points[i] != null && points[i + 1] != null) {
        canvas.drawLine(points[i]!, points[i + 1]!, paint);
      } else if (points[i] != null && points[i + 1] == null) {
        canvas.drawPoints(ui.PointMode.points, [points[i]!], paint);
      }
    }
  }

  @override
  bool shouldRepaint(SignaturePainter oldDelegate) => oldDelegate.points != points;
}
