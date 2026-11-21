import 'package:flutter/material.dart';

class GlassOrb extends StatefulWidget {
  const GlassOrb({super.key, this.size = 160});
  final double size;

  @override
  State<GlassOrb> createState() => _GlassOrbState();
}

class _GlassOrbState extends State<GlassOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.94, end: 1.06).animate(
        CurvedAnimation(parent: _c, curve: Curves.easeInOut),
      ),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: const RadialGradient(
            colors: [
              Color(0xFF000000),
              Color(0xFF0A1647),
              Color(0xFF1B9FC4),
              Color(0xFFC8FBFF),
            ],
            stops: [0.0, 0.55, 0.85, 1.0],
          ),
          border: Border.all(color: const Color(0xFF52F2EA), width: 2),
          boxShadow: const [
            BoxShadow(color: Color(0x8819D3E0), blurRadius: 40, spreadRadius: 4),
          ],
        ),
      ),
    );
  }
}
