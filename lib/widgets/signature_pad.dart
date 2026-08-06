import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/colors.dart';

class SignaturePadDialog extends StatefulWidget {
  final String doctorName;
  final String doctorColegiado;

  const SignaturePadDialog({
    super.key,
    required this.doctorName,
    required this.doctorColegiado,
  });

  @override
  State<SignaturePadDialog> createState() => _SignaturePadDialogState();
}

class _SignaturePadDialogState extends State<SignaturePadDialog> {
  final List<Offset?> _points = [];

  void _clearSignature() {
    setState(() {
      _points.clear();
    });
  }

  bool get _hasSignature => _points.where((p) => p != null).isNotEmpty;

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
              'Firma Digital del Especialista',
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
            Text(
              'Por favor dibuja tu firma digital en el recuadro para autorizar la prescripción clínica:',
              style: const TextStyle(fontSize: 12, color: AppColors.textLight),
            ),
            const SizedBox(height: 12),

            // Canvas de Firma con Trazo
            Container(
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
                    onPanUpdate: (DragUpdateDetails details) {
                      RenderBox renderBox = context.findRenderObject() as RenderBox;
                      Offset localPosition = renderBox.globalToLocal(details.globalPosition);
                      // Ajustar offset local al canvas
                      setState(() {
                        _points.add(localPosition);
                      });
                    },
                    onPanEnd: (DragEndDetails details) {
                      setState(() {
                        _points.add(null);
                      });
                    },
                    child: CustomPaint(
                      painter: SignaturePainter(_points),
                      size: Size.infinite,
                    ),
                  ),
                  if (!_hasSignature)
                    const Center(
                      child: Text(
                        'Firme aquí con el dedo o lápiz ✍️',
                        style: TextStyle(color: AppColors.textLight, fontSize: 13, fontStyle: FontStyle.italic),
                      ),
                    ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: TextButton.icon(
                      onPressed: _clearSignature,
                      icon: const Icon(Icons.cleaning_services_outlined, size: 16, color: AppColors.error),
                      label: const Text('Borrar', style: TextStyle(fontSize: 12, color: AppColors.error)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                const Icon(Icons.verified_outlined, size: 16, color: AppColors.success),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Dr(a). ${widget.doctorName} • Col. #${widget.doctorColegiado}',
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
          onPressed: () => Navigator.pop(context, null),
          child: const Text('Cancelar', style: TextStyle(color: AppColors.textLight)),
        ),
        ElevatedButton.icon(
          onPressed: _hasSignature
              ? () {
                  final textFirma = 'Firma Digital Dibujada por Dr. ${widget.doctorName} (Colegiado #${widget.doctorColegiado})';
                  Navigator.pop(context, textFirma);
                }
              : null,
          icon: const Icon(Icons.check_circle_outline, color: Colors.white, size: 18),
          label: const Text('Confirmar Firma', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
    Paint paint = Paint()
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
