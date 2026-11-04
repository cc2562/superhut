import 'package:flutter/material.dart';
import 'package:superhut/pages/health/health_score_models.dart';

/// 等级配色：背景是弱化色，文字是强调色。
class HealthLevelColors {
  const HealthLevelColors({required this.foreground, required this.background});

  final Color foreground;
  final Color background;
}

/// 按等级色调取色；深色模式下把强调色向白色提亮，避免压在深底上看不清。
HealthLevelColors healthLevelColors(ColorScheme scheme, HealthLevelTone tone) {
  Color base;
  switch (tone) {
    case HealthLevelTone.excellent:
      base = const Color(0xFF0E8C86);
    case HealthLevelTone.good:
      base = const Color(0xFF2E7D32);
    case HealthLevelTone.pass:
      base = const Color(0xFFB26A00);
    case HealthLevelTone.fail:
      base = scheme.error;
    case HealthLevelTone.unknown:
      base = scheme.onSurfaceVariant;
  }
  if (scheme.brightness == Brightness.dark) {
    base = Color.lerp(base, Colors.white, 0.35) ?? base;
  }
  return HealthLevelColors(
    foreground: base,
    background: base.withValues(alpha: 0.14),
  );
}

/// 等级胶囊标签。
class HealthLevelBadge extends StatelessWidget {
  const HealthLevelBadge({super.key, required this.level, this.score});

  final String level;
  final double? score;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final String text = level.trim().isEmpty ? '未评级' : level.trim();
    final HealthLevelColors colors = healthLevelColors(
      scheme,
      healthLevelTone(score: score, level: level),
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: colors.foreground,
        ),
      ),
    );
  }
}

/// 内容层卡片：统一 20 圆角与 surfaceContainer 底色，不使用玻璃。
class HealthCard extends StatelessWidget {
  const HealthCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card.filled(
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainer,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// 卡片内的小标题行。
class HealthSectionHeader extends StatelessWidget {
  const HealthSectionHeader({super.key, required this.title, this.trailing});

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: scheme.onSurface,
          ),
        ),
        const Spacer(),
        if (trailing != null)
          Text(
            trailing!,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
      ],
    );
  }
}
