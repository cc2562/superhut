import 'dart:math' as math;

import 'package:flutter/material.dart';

/// 徽章姿态：由页面决定，[TransBadge] 只负责消费。
@immutable
class BadgePose {
  const BadgePose({this.rotationX = 0, this.rotationY = 0});

  /// 俯仰（绕 X 轴），页面侧限制在约 ±0.3 弧度。
  final double rotationX;

  /// 主翻转（绕 Y 轴），可累积多圈。
  final double rotationY;

  @override
  bool operator ==(Object other) =>
      other is BadgePose &&
      other.rotationX == rotationX &&
      other.rotationY == rotationY;

  @override
  int get hashCode => Object.hash(rotationX, rotationY);
}

/// 转动累计器：把「转满四圈」从 UI 代码里抽成可以单测的单元。
class BadgeSpinAccumulator {
  /// 触发彩蛋所需累计的角度：四圈。
  static const double revealThreshold = 8 * math.pi;

  double _total = 0;

  /// 已经累计转过的角度（取绝对值）。
  double get total => _total;

  bool get shouldReveal => _total >= revealThreshold;

  void add(double deltaRadians) {
    _total += deltaRadians.abs();
  }

  void reset() {
    _total = 0;
  }
}

/// 立体跨性别旗徽章：金属外环 + 玻璃旗面 + 连续侧壁。
///
/// 几何是一枚圆角矩形棱柱（[BadgePose] 决定旋转），用解析透视投影逐帧
/// 重算轮廓与侧壁，因此翻转过程中不会出现「贴纸侧面」的断层。
class TransBadge extends StatelessWidget {
  const TransBadge({
    super.key,
    required this.pose,
    this.glow = 0,
    this.width = 224,
    this.height = 168,
  });

  final BadgePose pose;

  /// 0..1，触发彩蛋时驱动玻璃面上的一道扫光。
  final double glow;

  final double width;

  final double height;

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(width, height),
        painter: _BadgePainter(
          pose: pose,
          glow: glow.clamp(0.0, 1.0),
          brightness: Theme.of(context).brightness,
        ),
      ),
    );
  }
}

// ── 几何常量 ────────────────────────────────────────────────────────────

const double _kDesignWidth = 200;
const double _kDesignHeight = 128;
const double _kCornerRadius = 20;

/// 棱柱厚度：翻转时能看到的侧壁高度。
///
/// 保持得很薄（8）：厚一点侧壁就会在外环外面撑出一圈白边，
/// 旗面和边框看起来像两张不同平面的东西。
const double _kDepth = 8;

/// 金属外环宽度：旗面玻璃窗相对外轮廓的内缩量。
const double _kWindowInset = 8;

/// 每个圆角的分段数：圆角间由直线连接，总点数 = 4 ×（分段 + 1）。
const int _kCornerSteps = 9;

/// 透视焦平面距离（设计坐标系）。
///
/// 越小透视越强。2600 已经接近正交投影：外框、旗面、厚度在投影里
/// 尺寸几乎一致，拖动时看起来就是同一块板在整体转动。
const double _kFocal = 2600;

/// 跨性别旗五条横色。
const List<Color> _kFlagColors = <Color>[
  Color(0xFF5BCEFA),
  Color(0xFFF5A9B8),
  Color(0xFFFFFFFF),
  Color(0xFFF5A9B8),
  Color(0xFF5BCEFA),
];

/// 背面压印的字样。
const String _kPrideWord = 'PRIDE';

/// 背面字样的彩虹渐变（水平方向六色）。
const List<Color> _kPrideColors = <Color>[
  Color(0xFFE40303),
  Color(0xFFFF8C00),
  Color(0xFFFFED00),
  Color(0xFF008026),
  Color(0xFF004DFF),
  Color(0xFF750787),
];

@immutable
class _OutlinePoint {
  const _OutlinePoint({required this.position, required this.normal});

  /// 设计坐标系里的点（以徽章中心为原点）。
  final Offset position;

  /// 该点处朝外的单位法线。
  final Offset normal;
}

/// 圆角矩形轮廓采样：位置 + 外法线，静态缓存。
///
/// 只在四段圆角上取点，圆角之间由直线相连——按周长均匀取点会让半径 12 的
/// 圆角只剩一两个采样点，转角被连成斜线，看起来像「方框套方框」。
List<_OutlinePoint> _sampleOutline(
  double width,
  double height,
  double radius,
  int cornerSteps,
) {
  final double halfWidth = width / 2;
  final double halfHeight = height / 2;
  final List<Offset> cornerCenters = <Offset>[
    Offset(halfWidth - radius, -halfHeight + radius), // 右上
    Offset(halfWidth - radius, halfHeight - radius), // 右下
    Offset(-halfWidth + radius, halfHeight - radius), // 左下
    Offset(-halfWidth + radius, -halfHeight + radius), // 左上
  ];

  final List<_OutlinePoint> points = <_OutlinePoint>[];
  for (int corner = 0; corner < cornerCenters.length; corner++) {
    final Offset center = cornerCenters[corner];
    final double startAngle = -math.pi / 2 + corner * math.pi / 2;
    for (int i = 0; i <= cornerSteps; i++) {
      final double angle = startAngle + (math.pi / 2) * i / cornerSteps;
      final Offset normal = Offset(math.cos(angle), math.sin(angle));
      points.add(
        _OutlinePoint(position: center + normal * radius, normal: normal),
      );
    }
  }
  return points;
}

final List<_OutlinePoint> _kOuterOutline = _sampleOutline(
  _kDesignWidth,
  _kDesignHeight,
  _kCornerRadius,
  _kCornerSteps,
);

final List<_OutlinePoint> _kInnerOutline = _sampleOutline(
  _kDesignWidth - 2 * _kWindowInset,
  _kDesignHeight - 2 * _kWindowInset,
  _kCornerRadius - _kWindowInset,
  _kCornerSteps,
);

/// 旋转 + 透视投影后的棱柱：正/背两面的外轮廓、玻璃窗轮廓与逐边侧壁。
class _ProjectedPrism {
  _ProjectedPrism(BadgePose pose) {
    final double cosY = math.cos(pose.rotationY);
    final double sinY = math.sin(pose.rotationY);
    final double cosX = math.cos(pose.rotationX);
    final double sinX = math.sin(pose.rotationX);

    // 面外法线为 (0, 0, ∓1)：cosY·cosX > 0 时正面朝向观察者。
    facing = cosY * cosX;
    frontVisible = facing > 0;
    backVisible = facing < 0;
    tilt = math.sin(pose.rotationY);

    Offset project(Offset p, double z) {
      final double x1 = p.dx * cosY + z * sinY;
      final double z1 = -p.dx * sinY + z * cosY;
      final double y2 = p.dy * cosX - z1 * sinX;
      final double z2 = p.dy * sinX + z1 * cosX;
      final double scale = _kFocal / (_kFocal + z2);
      return Offset(x1 * scale, y2 * scale);
    }

    frontOuter =
        _kOuterOutline.map((point) => project(point.position, 0)).toList();
    backOuter =
        _kOuterOutline
            .map((point) => project(point.position, _kDepth))
            .toList();
    frontInner =
        _kInnerOutline.map((point) => project(point.position, 0)).toList();
    backInner =
        _kInnerOutline
            .map((point) => project(point.position, _kDepth))
            .toList();

    // 逐边侧壁：用相邻两点的平均法线判断可见性与受光方向。
    wallVisible = <bool>[];
    wallShade = <double>[];
    for (int i = 0; i < _kOuterOutline.length; i++) {
      final _OutlinePoint current = _kOuterOutline[i];
      final _OutlinePoint next =
          _kOuterOutline[(i + 1) % _kOuterOutline.length];
      final Offset normal = (current.normal + next.normal) / 2;

      final double nz1 = -normal.dx * sinY;
      final double nz2 = normal.dy * sinX + nz1 * cosX;
      final double nx1 = normal.dx * cosY;
      final double ny2 = normal.dy * cosX - nz1 * sinX;

      wallVisible.add(nz2 < 0);
      // 光从左上前方打过来，越正对越亮。
      final double lambert = nx1 * -0.34 + ny2 * -0.58 + nz2 * -0.74;
      wallShade.add((0.42 + 0.58 * lambert.clamp(0.0, 1.0)).clamp(0.0, 1.0));
    }
  }

  late final List<Offset> frontOuter;
  late final List<Offset> backOuter;
  late final List<Offset> frontInner;
  late final List<Offset> backInner;
  late final List<bool> wallVisible;
  late final List<double> wallShade;

  /// 正面法线朝向观察者的程度（-1 背面正对，1 正面正对）。
  late final double facing;
  late final bool frontVisible;
  late final bool backVisible;

  /// sin(rotationY)：用于让高光带与旗面反射跟随旋转。
  late final double tilt;
}

class _BadgePainter extends CustomPainter {
  const _BadgePainter({
    required this.pose,
    required this.glow,
    required this.brightness,
  });

  final BadgePose pose;
  final double glow;
  final Brightness brightness;

  bool get _dark => brightness == Brightness.dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    // 画布比徽章本身大一圈：留出底部投影的空间。
    final double scale = math.min(
      size.width / (_kDesignWidth + 24),
      size.height / (_kDesignHeight + 40),
    );
    final Offset center = Offset(
      size.width / 2,
      size.height / 2 - size.height * 0.04,
    );

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(scale);

    final _ProjectedPrism prism = _ProjectedPrism(pose);
    _paintContactShadow(canvas, prism);
    _paintSideWalls(canvas, prism);
    if (prism.backVisible) _paintBackFace(canvas, prism);
    if (prism.frontVisible) _paintFrontFace(canvas, prism);

    canvas.restore();
  }

  // ── 投影 ─────────────────────────────────────────────────────────────

  void _paintContactShadow(Canvas canvas, _ProjectedPrism prism) {
    // 接触阴影直接复用徽章轮廓：整体下移几像素再模糊，
    // 形状跟着徽章转，比一个椭圆更像「这块板压在背景上」。
    final Path silhouette = _polygon(prism.frontOuter);
    canvas.save();
    canvas.translate(8 * prism.tilt, 9 + 5 * pose.rotationX.abs());
    canvas.drawPath(
      silhouette,
      Paint()
        ..color = Colors.black.withValues(alpha: _dark ? 0.38 : 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 11),
    );
    canvas.restore();
  }

  // ── 侧壁 ─────────────────────────────────────────────────────────────

  void _paintSideWalls(Canvas canvas, _ProjectedPrism prism) {
    final Color base =
        _dark ? const Color(0xFF2A2E35) : const Color(0xFFC2C8D2);
    final Color lit = _dark ? const Color(0xFF4B525C) : const Color(0xFFEDF0F5);
    final Color rim =
        _dark
            ? Colors.white.withValues(alpha: 0.12)
            : Colors.white.withValues(alpha: 0.26);

    for (int i = 0; i < prism.wallVisible.length; i++) {
      if (!prism.wallVisible[i]) continue;
      final int next = (i + 1) % prism.wallVisible.length;
      final List<Offset> quad = <Offset>[
        prism.frontOuter[i],
        prism.frontOuter[next],
        prism.backOuter[next],
        prism.backOuter[i],
      ];
      final Path path = _polygon(quad);
      final double shade = prism.wallShade[i];
      // 逐面填充、靠明暗区分棱面；不给每个面描边，否则细长侧壁上
      // 会出现一格一格的栅纹。
      canvas.drawPath(
        path,
        Paint()..color = Color.lerp(base, lit, shade) ?? base,
      );
    }

    // 金属反光只提在前轮廓的连续可见段上：分段绘制，
    // 否则可见侧壁分成两段时会在徽章中间拉一条直线。
    final Path rimPath = Path();
    bool started = false;
    for (int i = 0; i < prism.wallVisible.length; i++) {
      if (!prism.wallVisible[i]) {
        started = false;
        continue;
      }
      final Offset point = prism.frontOuter[i];
      if (started) {
        rimPath.lineTo(point.dx, point.dy);
      } else {
        rimPath.moveTo(point.dx, point.dy);
        started = true;
      }
    }
    canvas.drawPath(
      rimPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = rim,
    );
  }

  // ── 正面：金属外环 + 玻璃旗面 ─────────────────────────────────────────

  void _paintFrontFace(Canvas canvas, _ProjectedPrism prism) {
    final Path face = _polygon(prism.frontOuter);
    final Rect bounds = face.getBounds();
    final Path window = _polygon(prism.frontInner);

    // 1. 金属外环底
    canvas.drawPath(
      face,
      Paint()..shader = _metalShader(bounds, prism.tilt, _dark),
    );

    // 2. 跟随旋转移动的高光带（固定线性渐变会显得死板）
    canvas.drawPath(
      face,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = _highlightBandShader(bounds, prism.tilt, _dark),
    );

    // 3. 玻璃旗面
    canvas.save();
    canvas.clipPath(window);
    _paintFlagSurface(canvas, prism);
    canvas.restore();

    // 4. 玻璃窗内描边 + 面外描边
    canvas.drawPath(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1
        ..color =
            _dark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.white.withValues(alpha: 0.46),
    );
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color =
            _dark
                ? Colors.white.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.16),
    );

    // 转向侧面的一侧压暗：外环是浅金属，不压暗就看不出它在转。
    final double turn = prism.tilt.abs();
    if (turn > 0.04) {
      canvas.drawPath(
        face,
        Paint()
          ..shader = LinearGradient(
            begin:
                prism.tilt > 0 ? Alignment.centerRight : Alignment.centerLeft,
            end: prism.tilt > 0 ? Alignment.centerLeft : Alignment.centerRight,
            colors: <Color>[
              Colors.black.withValues(alpha: 0.12 * turn),
              Colors.transparent,
            ],
            stops: const <double>[0.0, 0.55],
          ).createShader(bounds),
      );
    }
  }

  void _paintFlagSurface(Canvas canvas, _ProjectedPrism prism) {
    final double windowHeight = _kDesignHeight - 2 * _kWindowInset;
    final double bandHeight = windowHeight / _kFlagColors.length;
    final Rect cover = Rect.fromCenter(
      center: Offset.zero,
      width: _kDesignWidth * 3,
      height: _kDesignHeight * 3,
    );

    for (int i = 0; i < _kFlagColors.length; i++) {
      final Rect band = Rect.fromLTWH(
        -_kDesignWidth * 1.5,
        -windowHeight / 2 + bandHeight * i,
        _kDesignWidth * 3,
        bandHeight + 0.6,
      );
      canvas.drawRect(band, Paint()..color = _kFlagColors[i]);
    }

    // 玻璃感：一层很薄的中性色压在旗面上，不能把旗色洗淡。
    canvas.drawRect(
      cover,
      Paint()
        ..color = (_dark ? Colors.black : Colors.white).withValues(
          alpha: _dark ? 0.08 : 0.04,
        ),
    );

    // 环境反射：斜向白 band，位置随 rotationY 移动。
    canvas.drawRect(
      cover,
      Paint()
        ..blendMode = BlendMode.plus
        ..shader = _sheenShader(prism.tilt, _dark),
    );

    // 彩蛋扫光：一道更亮的窄带快速划过玻璃面。
    if (glow > 0.01) {
      final double sweep = (glow * 2.4 - 1.0).clamp(-1.4, 1.4);
      canvas.drawRect(
        cover,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = _sweepShader(sweep),
      );
    }

    // 底部暗角，压住旗面下缘，看起来像有厚度。
    canvas.drawRect(
      cover,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            Colors.transparent,
            Colors.black.withValues(alpha: _dark ? 0.16 : 0.10),
          ],
          stops: const <double>[0.55, 1.0],
        ).createShader(
          Rect.fromCenter(
            center: Offset.zero,
            width: _kDesignWidth,
            height: _kDesignHeight,
          ),
        ),
    );
  }

  // ── 背面：蚀刻金属 ────────────────────────────────────────────────────

  void _paintBackFace(Canvas canvas, _ProjectedPrism prism) {
    final Path face = _polygon(prism.backOuter);
    final Rect bounds = face.getBounds();
    final Path window = _polygon(prism.backInner);

    canvas.drawPath(
      face,
      Paint()..shader = _metalShader(bounds, -prism.tilt, _dark, etched: true),
    );

    canvas.save();
    canvas.clipPath(window);
    _paintPrideWordmark(canvas);
    canvas.restore();

    // 环形刻线：金属徽章背面常见的一圈压印。
    canvas.drawPath(
      window,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: _dark ? 0.14 : 0.35),
    );
    canvas.drawPath(
      face,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Colors.white.withValues(alpha: _dark ? 0.16 : 0.42),
    );
  }

  /// 背面图案：金属上的 PRIDE 字样，字面是横向彩虹渐变。
  ///
  /// 不带投影与描边，常规字重，干净地平铺在蚀刻金属上。
  void _paintPrideWordmark(Canvas canvas) {
    final TextStyle base = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w300,
      letterSpacing: 4,
      height: 1,
    );

    // 先量一次字宽：彩虹渐变要正好铺满字形，而不是铺满整个玻璃窗。
    final TextPainter measure = TextPainter(
      text: TextSpan(text: _kPrideWord, style: base),
      textDirection: TextDirection.ltr,
    )..layout();
    final double wordWidth = measure.width;
    measure.dispose();

    final TextPainter wordmark = TextPainter(
      text: TextSpan(
        text: _kPrideWord,
        style: base.copyWith(
          foreground:
              Paint()
                ..shader = LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: _kPrideColors,
                ).createShader(
                  Rect.fromLTWH(-wordWidth / 2, -20, wordWidth, 40),
                ),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    // 不同系统字体的字宽差异很大，超宽时整体缩一点，避免被玻璃窗裁掉。
    final double available = _kDesignWidth - 2 * _kWindowInset - 14;
    final double scale =
        wordmark.width > available ? available / wordmark.width : 1.0;

    canvas.save();
    canvas.scale(scale);
    final Offset center = Offset(-wordmark.width / 2, -wordmark.height / 2);
    wordmark.paint(canvas, center);
    canvas.restore();

    wordmark.dispose();
  }

  // ── 着色器 ───────────────────────────────────────────────────────────

  Shader _metalShader(
    Rect bounds,
    double tilt,
    bool dark, {
    bool etched = false,
  }) {
    final double shift = tilt * 0.55;
    final List<Color> colors;
    if (etched) {
      colors =
          dark
              ? const <Color>[
                Color(0xFF3A3F47),
                Color(0xFF23262B),
                Color(0xFF33373E),
              ]
              : const <Color>[
                Color(0xFFAAB2BD),
                Color(0xFF8B939E),
                Color(0xFF9FA7B2),
              ];
    } else {
      colors =
          dark
              ? const <Color>[
                Color(0xFF59606B),
                Color(0xFF2B2F35),
                Color(0xFF4A505A),
                Color(0xFF1C1F24),
              ]
              : const <Color>[
                Color(0xFFF2F5F9),
                Color(0xFFBFC6D0),
                Color(0xFFE6EAF0),
                Color(0xFF98A0AC),
              ];
    }
    return LinearGradient(
      begin: Alignment(-1 + shift, -1),
      end: Alignment(1 + shift, 1),
      colors: colors,
      stops: _stopsFor(colors.length),
    ).createShader(bounds);
  }

  Shader _highlightBandShader(Rect bounds, double tilt, bool dark) {
    final double center = (0.5 + tilt * 0.45).clamp(0.12, 0.88);
    final double spread = 0.16;
    return LinearGradient(
      begin: Alignment(-1 + tilt * 0.5, -1),
      end: Alignment(1 + tilt * 0.5, 1),
      colors: <Color>[
        Colors.transparent,
        Colors.white.withValues(alpha: dark ? 0.12 : 0.22),
        Colors.transparent,
      ],
      stops: <double>[
        (center - spread).clamp(0.0, 1.0),
        center,
        (center + spread).clamp(0.0, 1.0),
      ],
    ).createShader(bounds);
  }

  Shader _sheenShader(double tilt, bool dark) {
    final double shift = tilt * 0.7;
    return LinearGradient(
      begin: Alignment(-1.1 + shift, -1.2),
      end: Alignment(0.6 + shift, 1.2),
      colors: <Color>[
        Colors.white.withValues(alpha: dark ? 0.12 : 0.20),
        Colors.white.withValues(alpha: 0),
      ],
      stops: const <double>[0.0, 0.62],
    ).createShader(
      Rect.fromCenter(
        center: Offset.zero,
        width: _kDesignWidth,
        height: _kDesignHeight,
      ),
    );
  }

  Shader _sweepShader(double position) {
    final double center = (0.5 + position * 0.5).clamp(0.05, 0.95);
    return LinearGradient(
      begin: const Alignment(-1.2, -1),
      end: const Alignment(1.2, 1),
      colors: <Color>[
        Colors.white.withValues(alpha: 0),
        Colors.white.withValues(alpha: 0.40),
        Colors.white.withValues(alpha: 0),
      ],
      stops: <double>[
        (center - 0.10).clamp(0.0, 1.0),
        center,
        (center + 0.10).clamp(0.0, 1.0),
      ],
    ).createShader(
      Rect.fromCenter(
        center: Offset.zero,
        width: _kDesignWidth,
        height: _kDesignHeight,
      ),
    );
  }

  List<double> _stopsFor(int count) {
    if (count <= 2) return const <double>[0.0, 1.0];
    return List<double>.generate(
      count,
      (int i) => i / (count - 1),
      growable: false,
    );
  }

  @override
  bool shouldRepaint(covariant _BadgePainter oldDelegate) =>
      oldDelegate.pose != pose ||
      oldDelegate.glow != glow ||
      oldDelegate.brightness != brightness;

  Path _polygon(List<Offset> points) {
    if (points.isEmpty) return Path();
    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }
    return path..close();
  }
}
