import 'package:flutter/material.dart';

/// Date pentru un avatar din [AppTeamAvatarStack] — inițiale + culoare.
class AppAvatarData {
  const AppAvatarData({required this.label, required this.color});

  /// Text scurt afișat în cerc (de regulă inițiale, max 2 caractere).
  final String label;
  final Color color;
}

/// Avatare mici suprapuse (inițiale + culoare per persoană/echipă), cu
/// indicator "+N" pentru overflow. Folosit pe cardurile de programare pentru
/// alocarea vizuală rapidă a echipei/angajaților.
class AppTeamAvatarStack extends StatelessWidget {
  const AppTeamAvatarStack({
    super.key,
    required this.avatars,
    this.maxVisible = 3,
    this.size = 24,
  });

  final List<AppAvatarData> avatars;
  final int maxVisible;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (avatars.isEmpty) {
      return const SizedBox.shrink();
    }
    final visible = avatars.take(maxVisible).toList(growable: false);
    final overflow = avatars.length - visible.length;
    final overlap = size * 0.62;
    final totalCount = visible.length + (overflow > 0 ? 1 : 0);
    final width = overlap * (totalCount - 1) + size;

    return SizedBox(
      width: width,
      height: size,
      child: Stack(
        children: [
          for (var i = 0; i < visible.length; i++)
            Positioned(
              left: overlap * i,
              child: _AvatarCircle(
                size: size,
                color: visible[i].color,
                child: Text(
                  visible[i].label,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          if (overflow > 0)
            Positioned(
              left: overlap * visible.length,
              child: _AvatarCircle(
                size: size,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                child: Text(
                  '+$overflow',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: size * 0.34,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AvatarCircle extends StatelessWidget {
  const _AvatarCircle({
    required this.size,
    required this.color,
    required this.child,
  });

  final double size;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
      child: child,
    );
  }
}
