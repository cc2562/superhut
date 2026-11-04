import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 彩蛋奖励：徽章背后的蓝粉白径向光晕。
///
/// 只负责画，强度由页面传入（0 = 完全不可见），不常驻动画。
class BadgeGlow extends StatelessWidget {
  const BadgeGlow({super.key, required this.intensity, this.size = 300});

  /// 0..1。
  final double intensity;

  final double size;

  @override
  Widget build(BuildContext context) {
    if (intensity <= 0.001) return const SizedBox.shrink();
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(size),
          painter: _GlowPainter(intensity: intensity.clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter({required this.intensity});

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Offset.zero & size;
    final Paint paint =
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              const Color(0xFF5BCEFA).withValues(alpha: 0.52 * intensity),
              const Color(0xFFF5A9B8).withValues(alpha: 0.32 * intensity),
              Colors.white.withValues(alpha: 0.16 * intensity),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.42, 0.66, 1.0],
          ).createShader(rect);
    canvas.drawCircle(rect.center, size.shortestSide / 2, paint);
  }

  @override
  bool shouldRepaint(covariant _GlowPainter oldDelegate) =>
      oldDelegate.intensity != intensity;
}

/// 一个粒子：确定种子生成，只在触发后存活 1.2 秒。
@immutable
class _Particle {
  const _Particle({
    required this.origin,
    required this.velocity,
    required this.size,
    required this.color,
    required this.delay,
  });

  final Offset origin;
  final Offset velocity;
  final double size;
  final Color color;

  /// 起飞延迟（秒），让爆发有层次。
  final double delay;
}

/// 彩蛋奖励：少量粒子向上爆发后受重力回落淡出。
class BadgeParticles extends StatefulWidget {
  const BadgeParticles({
    super.key,
    required this.controller,
    this.size = 280,
    this.count = 40,
  });

  /// 0→1 表示整段爆发的进度（约 1.2 秒）。
  final AnimationController controller;

  final double size;
  final int count;

  @override
  State<BadgeParticles> createState() => _BadgeParticlesState();
}

class _BadgeParticlesState extends State<BadgeParticles> {
  static const List<Color> _palette = <Color>[
    Color(0xFF5BCEFA),
    Color(0xFFF5A9B8),
    Colors.white,
  ];

  late final List<_Particle> _particles = _buildParticles();

  List<_Particle> _buildParticles() {
    // 固定种子：同一设备每次爆发的形状一致，便于复现与截图对比。
    final math.Random random = math.Random(20261104);
    return List<_Particle>.generate(widget.count, (int index) {
      final double angle = -math.pi / 2 + (random.nextDouble() - 0.5) * 2.3;
      final double speed = 150 + random.nextDouble() * 170;
      final double radius = random.nextDouble() * 88;
      final double startAngle = random.nextDouble() * math.pi * 2;
      return _Particle(
        origin: Offset(
          math.cos(startAngle) * radius,
          math.sin(startAngle) * radius * 0.55,
        ),
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        size: 4 + random.nextDouble() * 4,
        color: _palette[index % _palette.length],
        delay: random.nextDouble() * 0.14,
      );
    }, growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: widget.controller,
          builder: (BuildContext context, Widget? child) {
            final double progress = widget.controller.value;
            if (progress <= 0 || progress >= 1) {
              return SizedBox.square(dimension: widget.size);
            }
            return CustomPaint(
              size: Size.square(widget.size),
              painter: _ParticlePainter(
                particles: _particles,
                progress: progress,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  const _ParticlePainter({required this.particles, required this.progress});

  final List<_Particle> particles;
  final double progress;

  /// 整段爆发的时长（秒），与页面里的动画控制器保持一致。
  static const double duration = 1.2;

  /// 重力加速度（设计像素 / 秒²）。
  static const double gravity = 300;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final Paint paint = Paint();

    for (final _Particle particle in particles) {
      final double local = progress * duration - particle.delay;
      if (local <= 0) continue;
      final double elapsed = local.clamp(0.0, duration);
      final Offset position =
          center +
          particle.origin +
          particle.velocity * elapsed +
          Offset(0, 0.5 * gravity * elapsed * elapsed);

      // 前 15% 淡入，最后 45% 淡出。
      final double fadeIn = (elapsed / (duration * 0.15)).clamp(0.0, 1.0);
      final double fadeOut = ((duration - elapsed) / (duration * 0.45)).clamp(
        0.0,
        1.0,
      );
      final double alpha = fadeIn * fadeOut;
      if (alpha <= 0.01) continue;

      // 外圈淡白描边让粒子在浅色背景与玻璃面上都能被看到。
      paint.color = Colors.white.withValues(alpha: 0.5 * alpha);
      canvas.drawCircle(position, particle.size * 1.45, paint);

      paint.color = particle.color.withValues(alpha: 0.9 * alpha);
      canvas.drawCircle(position, particle.size * (0.55 + 0.45 * alpha), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.particles != particles;
}
