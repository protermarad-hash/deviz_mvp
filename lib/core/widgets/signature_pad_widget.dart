import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Widget semnătură electronică — canvas cu degetul / mouse-ul
// Returnează Uint8List (PNG) prin onConfirm
// ─────────────────────────────────────────────────────────────────────────────

class SignaturePadWidget extends StatefulWidget {
  const SignaturePadWidget({
    super.key,
    this.width = 400,
    this.height = 180,
    this.strokeColor = Colors.black,
    this.strokeWidth = 2.5,
    this.backgroundColor = Colors.white,
    this.label = 'Semnați în spațiul de mai jos',
    required this.onConfirm,
    this.onCancel,
  });

  final double width;
  final double height;
  final Color strokeColor;
  final double strokeWidth;
  final Color backgroundColor;
  final String label;
  final void Function(Uint8List pngBytes) onConfirm;
  final VoidCallback? onCancel;

  @override
  State<SignaturePadWidget> createState() => _SignaturePadWidgetState();
}

class _SignaturePadWidgetState extends State<SignaturePadWidget> {
  final List<List<Offset>> _strokes = [];
  List<Offset> _currentStroke = [];
  bool _hasSignature = false;
  final GlobalKey _repaintKey = GlobalKey();

  void _onPanStart(DragStartDetails d) {
    final pos = d.localPosition;
    setState(() {
      _currentStroke = [pos];
      _hasSignature = true;
    });
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final pos = d.localPosition;
    setState(() => _currentStroke.add(pos));
  }

  void _onPanEnd(DragEndDetails _) {
    setState(() {
      _strokes.add(List<Offset>.from(_currentStroke));
      _currentStroke = [];
    });
  }

  void _clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = [];
      _hasSignature = false;
    });
  }

  Future<void> _confirm() async {
    if (!_hasSignature) return;

    final boundary = _repaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return;

    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return;
    final pngBytes = byteData.buffer.asUint8List();
    widget.onConfirm(pngBytes);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: 13, color: Colors.black54),
            ),
          ),
        RepaintBoundary(
          key: _repaintKey,
          child: Container(
            width: widget.width,
            height: widget.height,
            decoration: BoxDecoration(
              color: widget.backgroundColor,
              border: Border.all(color: Colors.black26),
              borderRadius: BorderRadius.circular(6),
            ),
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(5),
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                    strokeColor: widget.strokeColor,
                    strokeWidth: widget.strokeWidth,
                    background: widget.backgroundColor,
                  ),
                  size: Size(widget.width, widget.height),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (widget.onCancel != null)
              TextButton(
                onPressed: widget.onCancel,
                child: const Text('Anulează'),
              ),
            TextButton.icon(
              onPressed: _hasSignature ? _clear : null,
              icon: const Icon(Icons.delete_outline, size: 16),
              label: const Text('Șterge'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _hasSignature ? _confirm : null,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Confirmă semnătura'),
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CustomPainter pentru desenarea traseelor
// ─────────────────────────────────────────────────────────────────────────────

class _SignaturePainter extends CustomPainter {
  _SignaturePainter({
    required this.strokes,
    required this.currentStroke,
    required this.strokeColor,
    required this.strokeWidth,
    required this.background,
  });

  final List<List<Offset>> strokes;
  final List<Offset> currentStroke;
  final Color strokeColor;
  final double strokeWidth;
  final Color background;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()..color = background,
    );

    final paint = Paint()
      ..color = strokeColor
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void drawStroke(List<Offset> pts) {
      if (pts.isEmpty) return;
      if (pts.length == 1) {
        canvas.drawCircle(pts.first, strokeWidth / 2, paint..style = PaintingStyle.fill);
        paint.style = PaintingStyle.stroke;
        return;
      }
      final path = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (var i = 1; i < pts.length; i++) {
        path.lineTo(pts[i].dx, pts[i].dy);
      }
      canvas.drawPath(path, paint);
    }

    for (final s in strokes) { drawStroke(s); }
    drawStroke(currentStroke);
  }

  @override
  bool shouldRepaint(_SignaturePainter old) =>
      old.strokes != strokes || old.currentStroke != currentStroke;
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper: afișează dialog cu pad-ul de semnătură
// ─────────────────────────────────────────────────────────────────────────────

Future<Uint8List?> showSignatureDialog(
  BuildContext context, {
  String title = 'Semnătură client',
  String label = 'Semnați în spațiul de mai jos',
}) async {
  return showDialog<Uint8List>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      return AlertDialog(
        title: Text(title),
        contentPadding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: SignaturePadWidget(
            width: 440,
            height: 200,
            label: label,
            onConfirm: (bytes) => Navigator.of(ctx).pop(bytes),
            onCancel: () => Navigator.of(ctx).pop(null),
          ),
        ),
        actions: const [],
      );
    },
  );
}
