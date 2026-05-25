import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Widget pentru afișare imagini de la URL — cross-platform safe.
///
/// Pe Windows, `NetworkImage` poate rămâne blocat indefinit (request HTTP
/// nu se finalizează). Acest widget folosește `http.get()` + `Image.memory()`
/// care funcționează corect pe toate platformele.
///
/// Pe alte platforme ar putea folosi `NetworkImage` nativ, dar folosim
/// același mecanism peste tot pentru consistență și simplitate.
class AppNetworkImage extends StatefulWidget {
  const AppNetworkImage({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.borderRadius,
    this.errorWidget,
    this.loadingWidget,
  });

  final String url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final BorderRadius? borderRadius;

  /// Widget afișat la eroare. Dacă null → icon broken_image.
  final Widget? errorWidget;

  /// Widget afișat la încărcare. Dacă null → CircularProgressIndicator.
  final Widget? loadingWidget;

  @override
  State<AppNetworkImage> createState() => _AppNetworkImageState();
}

class _AppNetworkImageState extends State<AppNetworkImage> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(AppNetworkImage old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url) {
      setState(() {
        _bytes = null;
        _loading = true;
        _error = false;
      });
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final url = widget.url.trim();
    if (url.isEmpty) {
      if (mounted) setState(() { _loading = false; _error = true; });
      return;
    }
    try {
      final response = await http.get(Uri.parse(url));
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _bytes = response.bodyBytes;
          _loading = false;
        });
      } else {
        setState(() { _loading = false; _error = true; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = true; });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;

    if (_loading) {
      content = widget.loadingWidget ??
          const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
    } else if (_error || _bytes == null) {
      content = widget.errorWidget ??
          const Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 28, color: Colors.grey),
                SizedBox(height: 4),
                Text(
                  'Eroare imagine',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
    } else {
      content = Image.memory(
        _bytes!,
        fit: widget.fit,
        width: widget.width,
        height: widget.height,
      );
    }

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    if (widget.width != null || widget.height != null) {
      content = SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }

    return content;
  }
}
