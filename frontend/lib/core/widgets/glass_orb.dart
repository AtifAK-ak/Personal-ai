import 'dart:math' as math;

import 'package:flutter/material.dart';

class _Particle {
  const _Particle(this.angle, this.radius, this.speed, this.size);
  final double angle;
  final double radius;
  final double speed;
  final double size;
}

/// Premium glass orb: glowing rim, two rotating glass bands, drifting particles
/// and a specular highlight. [listening] makes it pulse and the particles faster.
class GlassOrb extends StatefulWidget {
  const GlassOrb({super.key, this.size = 160, this.listening = false});
  final double size;
  final bool listening;

  @override
  State<GlassOrb> createState() => _GlassOrbState();
}

class _GlassOrbState extends State<GlassOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 9),
  )..repeat();

  late final List<_Particle> _particles = () {
    final r = math.Random(7);
    return List.generate(
      55,
      (_) => _Particle(
        r.nextDouble() * 2 * math.pi,
        math.sqrt(r.nextDouble()) * 0.72,
        (r.nextDouble() - 0.5) * 2,
        0.6 + r.nextDouble() * 1.6,
      ),
    );
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final pulse = widget.listening
            ? 1 + 0.06 * math.sin(_c.value * 2 * math.pi * 9)
            : 1 + 0.02 * math.sin(_c.value * 2 * math.pi * 3);
        return Transform.scale(
          scale: pulse,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _OrbPainter(_c.value, widget.listening, _particles),
          ),
        );
      },
    );
  }
}

class _OrbPainter extends CustomPainter {
  _OrbPainter(this.t, this.listening, this.particles);
  final double t;
  final bool listening;
  final List<_Particle> particles;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.width / 2;
    final rect = Rect.fromCircle(center: c, radius: r);

    canvas.drawCircle(
      c,
      r * 1.02,
      Paint()
        ..color = Color(listening ? 0xAA2FE4FF : 0x6619D3E0)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, r * 0.35),
    );

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          colors: [
            Color(0xFF000000),
            Color(0xFF0A1647),
            Color(0xFF1B9FC4),
            Color(0xFFC8FBFF),
          ],
          stops: [0.0, 0.55, 0.86, 1.0],
        ).createShader(rect),
    );

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));

    for (var i = 0; i < 2; i++) {
      final dir = i == 0 ? 1.0 : -0.7;
      canvas.save();
      canvas.translate(c.dx, c.dy);
      canvas.rotate(i == 0 ? 0.6 : -0.7);
      final squeeze = math.cos(t * 2 * math.pi * dir).abs() * 0.85 + 0.15;
      canvas.scale(squeeze, 1);
      final oval = Rect.fromCircle(center: Offset.zero, radius: r * 0.84);
      canvas.drawOval(
        oval,
        Paint()..color = Color(i == 0 ? 0x228A5BFF : 0x2230D0FF),
      );
      canvas.drawOval(
        oval,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.045
          ..shader = const SweepGradient(
            colors: [Color(0xFF7FF3FF), Color(0xFFB07BFF), Color(0xFF7FF3FF)],
          ).createShader(oval),
      );
      canvas.restore();
    }

    final speed = listening ? 5.0 : 1.0;
    final dot = Paint()..color = const Color(0xDDFF96FF);
    for (final p in particles) {
      final a = p.angle + t * 2 * math.pi * p.speed * speed * 0.3;
      canvas.drawCircle(
        Offset(c.dx + math.cos(a) * p.radius * r, c.dy + math.sin(a) * p.radius * r * 0.85),
        p.size * (r / 80),
        dot,
      );
    }

    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.42);
    final hl = Rect.fromCenter(
      center: Offset(-r * 0.12, -r * 0.62),
      width: r * 1.0,
      height: r * 0.5,
    );
    canvas.drawOval(
      hl,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xD9FFFFFF), Color(0x00FFFFFF)],
        ).createShader(hl),
    );
    canvas.restore();
    canvas.restore();

    canvas.drawCircle(
      c,
      r - 1,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xFF52F2EA),
    );
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => true;
}
