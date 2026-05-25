import 'package:flutter/gestures.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

class SignatureCapturePage extends StatefulWidget {
  const SignatureCapturePage({
    super.key,
    required this.title,
  });

  final String title;

  @override
  State<SignatureCapturePage> createState() => _SignatureCapturePageState();
}

class _SignatureCapturePageState extends State<SignatureCapturePage> {
  final List<Offset?> _points = <Offset?>[];
  final Set<int> _activePointers = <int>{};

  bool get _hasSignature => _points.any((point) => point != null);

  bool _supportsSignaturePointer(PointerEvent event) {
    switch (event.kind) {
      case ui.PointerDeviceKind.touch:
      case ui.PointerDeviceKind.stylus:
      case ui.PointerDeviceKind.invertedStylus:
      case ui.PointerDeviceKind.unknown:
        return true;
      case ui.PointerDeviceKind.mouse:
        return event.buttons == kPrimaryMouseButton;
      default:
        return false;
    }
  }

  Offset _clampOffset(Offset value, Size size) {
    return Offset(
      value.dx.clamp(0.0, size.width),
      value.dy.clamp(0.0, size.height),
    );
  }

  void _startStroke(PointerDownEvent event, Size size) {
    if (!_supportsSignaturePointer(event)) {
      return;
    }
    final local = _clampOffset(event.localPosition, size);
    setState(() {
      if (_points.isNotEmpty && _points.last != null) {
        _points.add(null);
      }
      _activePointers.add(event.pointer);
      _points.add(local);
    });
  }

  void _extendStroke(PointerMoveEvent event, Size size) {
    if (!_activePointers.contains(event.pointer)) {
      return;
    }
    final local = _clampOffset(event.localPosition, size);
    setState(() => _points.add(local));
  }

  void _endStroke(PointerEvent event) {
    if (!_activePointers.contains(event.pointer)) {
      return;
    }
    setState(() {
      _activePointers.remove(event.pointer);
      if (_points.isNotEmpty && _points.last != null) {
        _points.add(null);
      }
    });
  }

  Future<Uint8List?> _exportPng() async {
    if (!_hasSignature) {
      return null;
    }
    const width = 900.0;
    const height = 320.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final rect = Rect.fromLTWH(0, 0, width, height);
    final background = Paint()..color = Colors.white;
    canvas.drawRect(rect, background);

    final border = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect.deflate(1), border);

    final stroke = Paint()
      ..color = Colors.black
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < _points.length - 1; i++) {
      final current = _points[i];
      final next = _points[i + 1];
      if (current == null || next == null) {
        continue;
      }
      canvas.drawLine(current, next, stroke);
    }

    final picture = recorder.endRecording();
    final image = await picture.toImage(width.toInt(), height.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          TextButton(
            onPressed:
                _hasSignature ? () => setState(() => _points.clear()) : null,
            child: const Text('Reseteaza'),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Semneaza in zona de mai jos.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final size = Size(
                          constraints.maxWidth,
                          constraints.maxHeight,
                        );
                        return Listener(
                          behavior: HitTestBehavior.opaque,
                          onPointerDown: (event) => _startStroke(event, size),
                          onPointerMove: (event) => _extendStroke(event, size),
                          onPointerUp: _endStroke,
                          onPointerCancel: _endStroke,
                          child: CustomPaint(
                            painter: _SignaturePainter(_points),
                            child: const SizedBox.expand(),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: !_hasSignature
                ? null
                : () async {
                    final navigator = Navigator.of(context);
                    final bytes = await _exportPng();
                    if (!mounted) {
                      return;
                    }
                    navigator.pop(bytes);
                  },
            icon: const Icon(Icons.check),
            label: const Text('Salveaza semnatura'),
          ),
        ),
      ),
    );
  }
}

class _SignaturePainter extends CustomPainter {
  const _SignaturePainter(this.points);

  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    for (var i = 0; i < points.length - 1; i++) {
      final current = points[i];
      final next = points[i + 1];
      if (current == null || next == null) {
        continue;
      }
      canvas.drawLine(current, next, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
