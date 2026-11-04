import 'dart:async'; // 导入异步包，用于处理传感器数据流
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ionicons_plus/ionicons_plus.dart'; // 导入服务包，用于震动
import 'package:sensors_plus/sensors_plus.dart'; // 导入传感器包，用于重力感应

import '../../theme/glass/glass_scaffold.dart';
import 'badge_effects.dart';
import 'trans_badge.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _swingController;
  late AnimationController _returnController; // 添加回正动画控制器
  late AnimationController _textAnimationController; // 添加文字动画控制器
  late AnimationController _fadeOutController; // 添加淡出动画控制器
  late AnimationController _glowController; // 彩蛋泛光：240ms 起，淡出时收回
  late AnimationController _burstController; // 彩蛋粒子：1.2s 一次性
  bool _isAnimating = false;
  bool _isDragging = false;
  double _dragRotationY = 0.0; // 存储拖动时的Y轴旋转角度
  double _dragRotationX = 0.0; // 存储拖动时的X轴旋转角度（上下凹凸效果）
  bool _showEasterEgg = false; // 是否显示彩蛋
  double _lastDragRotationY = 0.0; // 记录上一次拖动的Y轴旋转角度
  double _lastDragRotationX = 0.0; // 回正动画的起始X轴角度
  String _currentEasterEggText = ""; // 当前显示的彩蛋文本
  bool _isFadingOut = false; // 是否正在淡出

  /// 徽章姿态。手势与重力只更新这个 notifier，徽章子树自行重绘，
  /// 不再每帧 setState 重建整页（下面还挂着作者信息与长文本）。
  final ValueNotifier<BadgePose> _pose = ValueNotifier<BadgePose>(
    const BadgePose(),
  );

  /// 「转满四圈」的累计判定。
  final BadgeSpinAccumulator _spin = BadgeSpinAccumulator();

  // 重力感应相关变量
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  double _gravityRotationY = 0.0; // 重力感应Y轴旋转角度
  double _gravityRotationX = 0.0; // 重力感应X轴旋转角度
  bool _useGravity = true; // 是否使用重力感应

  // 彩蛋文本列表
  final List<String> _easterEggTexts = [
    "你无需追赶任何人的时钟——你的蜕变自有专属的时节。",
    "那些质疑你灵魂的声音，终将被你坚定的存在震碎。",
    "你不仅是跨过性别，更是跨越偏见、走向自由。",
    "身体或许是一段旅程的起点，但绝不是终点。",
    "你的身份不是一道选择题，而是你亲手写下的答案。",
    "被看见，被理解，被尊重——这是你与生俱来的权利。",
    "世界少一个标签不会崩塌，但多一个真实的你，会变得更美。",
    "你的人生不是拼错的拼图，只是他们还没看懂你的图案。",
    "脆弱时请回头看看——身后有整个宇宙在为你骄傲。",
    "性别不是牢笼，而你永远是破茧的诗人。",
    "你正在成为自己最伟大的作品。",
    "你的灵魂是一幅未完成的画，每一笔都由你定义色彩。",
    "即使黑夜漫长，你也始终是自己永恒的黎明。",
    "你的存在，本身就是一种胜利。",
    "真正的你，比任何定义都更闪耀。",
    "你不需要证明自己'够资格'——你早已经是完整的。",
    "蜕变或许漫长，但每一步都值得骄傲。",
    "名字、身体、灵魂…你永远拥有定义自己的权力。",
    "世界因独一无二的你而完整。",
    "被误解的从来不是你的身份，而是那些狭隘的眼光。",
    "你属于这里，现在，未来，永远。",
    "勇敢不是没有恐惧，而是你选择为自己而战。",
    "你值得被爱，无需任何条件。",
  ];

  @override
  void initState() {
    super.initState();
    // 翻转动画控制器
    _flipController = AnimationController(
      duration: const Duration(milliseconds: 1800),
      vsync: this,
    );

    // 摆动动画控制器 - 模拟徽章挂在绳子上的效果
    _swingController = AnimationController(
      duration: const Duration(milliseconds: 2500),
      vsync: this,
    );

    // 回正动画控制器
    _returnController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    // 彩蛋泛光：快速亮起，淡出时随文案一起收回。
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 240),
      vsync: this,
    );

    // 彩蛋粒子：一次性爆发，播完即停。
    _burstController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // 文字动画控制器
    _textAnimationController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );

    // 淡出动画控制器
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _flipController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _flipController.reset();
        // 翻转完成后，开始摆动动画
        _swingController.forward();
      }
    });

    _swingController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _swingController.reset();
        setState(() {
          _isAnimating = false;
        });
      }
    });

    // 添加回正动画监听：只更新徽章姿态，不重建整页。
    _returnController.addListener(() {
      final double remain = 1 - _returnController.value;
      _dragRotationY = _lastDragRotationY * remain;
      _dragRotationX = _lastDragRotationX * remain;
      _syncPose();
    });

    _returnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _returnController.reset();
        _dragRotationY = 0.0;
        _dragRotationX = 0.0;
        _useGravity = true; // 回正动画完成后，重新启用重力感应
        _syncPose();
      }
    });

    _fadeOutController.addStatusListener((status) {
      if (status == AnimationStatus.completed && _isFadingOut) {
        setState(() {
          _showEasterEgg = false;
          _isFadingOut = false;
        });
        _fadeOutController.reset();
      }
    });

    // 初始化重力感应
    _initAccelerometer();
  }

  // 初始化加速度计监听
  void _initAccelerometer() {
    // 使用加速度计数据来实现重力感应
    _accelerometerSubscription = accelerometerEventStream().listen((
      AccelerometerEvent event,
    ) {
      if (mounted && _useGravity && !_isAnimating && !_isDragging) {
        // 将加速度计数据转换为旋转角度
        // 设置中立区域阈值，只有超过这个值才会影响旗子旋转
        final double deadZoneX = 1; // X轴中立区域阈值
        final double deadZoneY = 6; // Y轴中立区域阈值

        // 应用中立区域，只有手机倾斜超过一定角度才会影响旗子
        double xInput = 0.0;
        double yInput = 0.0;

        // 只有当X轴倾斜超过阈值时才应用旋转
        if (event.x.abs() > deadZoneX) {
          // 保留超出中立区域的部分
          xInput = event.x > 0 ? event.x - deadZoneX : event.x + deadZoneX;
        }

        // 只有当Y轴倾斜超过阈值时才应用旋转
        if (event.y.abs() > deadZoneY) {
          // 保留超出中立区域的部分
          yInput = event.y > 0 ? event.y - deadZoneY : event.y + deadZoneY;
        }

        // 重力数据是相反的，所以需要取负值
        final double targetRotationY = -xInput * 0.2; // 左右倾斜
        final double targetRotationX = yInput * 0.1; // 前后倾斜

        // 应用阻尼效果，使运动更平滑
        _gravityRotationY = _gravityRotationY * 0.8 + targetRotationY * 0.2;
        _gravityRotationX = _gravityRotationX * 0.8 + targetRotationX * 0.2;

        // 限制旋转范围
        _gravityRotationY = _gravityRotationY.clamp(-0.5, 0.5);
        _gravityRotationX = _gravityRotationX.clamp(-0.2, 0.2);
        _syncPose();
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _swingController.dispose();
    _returnController.dispose();
    _textAnimationController.dispose();
    _fadeOutController.dispose();
    _glowController.dispose();
    _burstController.dispose();
    _pose.dispose();
    _accelerometerSubscription?.cancel(); // 取消传感器订阅
    super.dispose();
  }

  // 随机选择一个彩蛋文本
  void _selectRandomEasterEggText() {
    final random = math.Random();
    final index = random.nextInt(_easterEggTexts.length);
    _currentEasterEggText = _easterEggTexts[index];
    _textAnimationController.reset();
    _textAnimationController.forward();
  }

  void _startAnimation() {
    if (!_isAnimating && !_isDragging) {
      setState(() {
        _isAnimating = true;
        _dragRotationY = 0.0; // 重置拖动旋转角度
        _dragRotationX = 0.0; // 重置X轴旋转角度
        _useGravity = false; // 动画期间禁用重力感应
      });
      _syncPose();
      // 触发震动反馈
      HapticFeedback.selectionClick();
      _flipController.forward();
    }
  }

  // 处理手指拖动
  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return; // 如果正在播放动画，不处理拖动

    _isDragging = true;
    _useGravity = false; // 拖动期间禁用重力感应

    // 记录上一次的旋转角度，用于计算旋转了多少圈
    final double previousRotationY = _dragRotationY;

    // 水平移动距离转换为旋转角度（每10逻辑像素对应π/8弧度）
    // 注意这里用-=，让滑动方向与旋转方向匹配
    _dragRotationY -= details.delta.dx * math.pi / 80;

    // 计算旋转增量并累加到总旋转角度
    final double deltaRotation = _dragRotationY - previousRotationY;
    _spin.add(deltaRotation);

    // 当旋转角度变化超过一定阈值时触发震动
    if (deltaRotation.abs() > 0.1) {
      HapticFeedback.lightImpact(); // 轻微震动
    }

    // 垂直移动转换为X轴旋转（上下凹凸效果）
    // 限制X轴旋转范围在-0.3到0.3弧度之间（约-17度到17度）
    final double previousRotationX = _dragRotationX;
    _dragRotationX -= details.delta.dy * math.pi / 200;
    _dragRotationX = _dragRotationX.clamp(-0.3, 0.3);

    // 当垂直旋转角度变化超过一定阈值时也触发震动
    if ((previousRotationX - _dragRotationX).abs() > 0.05) {
      HapticFeedback.lightImpact(); // 轻微震动
    }

    _syncPose();

    // 累计转满四圈即触发彩蛋
    if (_spin.shouldReveal && !_showEasterEgg && !_isFadingOut) {
      _revealEasterEgg();
    }
  }

  /// 把拖动 / 重力 / 回正的结果换算成徽章姿态。
  ///
  /// 只在手势与重力路径上调用；动画期间姿态由 [AnimatedBuilder] 直接算。
  void _syncPose() {
    _pose.value = BadgePose(
      rotationX: _dragRotationX + (_isDragging ? 0 : _gravityRotationX),
      rotationY: _dragRotationY + (_isDragging ? 0 : _gravityRotationY),
    );
  }

  /// 转满四圈：泛光亮起、粒子爆发、随机文案出现，8 秒后回收。
  void _revealEasterEgg() {
    _spin.reset();
    _glowController.forward();
    _burstController.forward(from: 0);
    _selectRandomEasterEggText();
    HapticFeedback.mediumImpact();
    setState(() {
      _showEasterEgg = true;
    });

    Future<void>.delayed(const Duration(seconds: 8), () {
      if (!mounted || !_showEasterEgg || _isFadingOut) return;
      _isFadingOut = true;
      _fadeOutController.forward(from: 0);
      _glowController.reverse();
    });
  }

  // 处理拖动结束
  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;

    _isDragging = false;
    _lastDragRotationY = _dragRotationY; // 记录当前旋转角度
    _lastDragRotationX = _dragRotationX;

    // 启动回正动画
    _returnController.forward(from: 0.0);

    // 触发轻微震动，表示拖动结束，开始回弹
    HapticFeedback.lightImpact();
  }

  /// 徽章本体：手势 + 姿态计算，只有这一棵子树随旋转重绘。
  Widget _buildBadge() {
    return GestureDetector(
      onTap: _startAnimation,
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: AnimatedBuilder(
        animation: Listenable.merge(<Listenable>[
          _flipController,
          _swingController,
          _pose,
          _glowController,
        ]),
        builder: (BuildContext context, Widget? child) {
          final BadgePose pose;
          if (_isAnimating) {
            // 点击自动翻转：整圈旋转 + 原有摆动曲线。
            final double swing =
                _swingController.value < 0.5
                    ? math.sin(_swingController.value * 4 * math.pi) * 0.1
                    : math.sin(_swingController.value * 2 * math.pi) * 0.05;
            pose = BadgePose(
              rotationX: swing,
              rotationY: _flipController.value * 2 * math.pi,
            );
          } else {
            pose = _pose.value;
          }
          return TransBadge(pose: pose, glow: _glowController.value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: '关于',
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              16,
              16 + glassTopInset(context),
              16,
              16,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                // 跨性别旗立体徽章
                Center(
                  child: Column(
                    children: [
                      SizedBox(
                        width: 260,
                        height: 210,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // 触发后的蓝粉白径向光晕
                            Positioned.fill(
                              child: AnimatedBuilder(
                                animation: _glowController,
                                builder:
                                    (context, _) => Center(
                                      child: BadgeGlow(
                                        intensity: _glowController.value,
                                        size: 260,
                                      ),
                                    ),
                              ),
                            ),
                            _buildBadge(),
                            // 粒子压在徽章上层：像从徽章里迸出来
                            Positioned.fill(
                              child: BadgeParticles(
                                controller: _burstController,
                                size: 260,
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 10),
                      // 彩蛋文字显示区域 - 始终保持布局空间
                      Container(
                        margin: EdgeInsets.only(top: 20, bottom: 10),
                        //padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                        //height: 70, // 固定高度，避免布局跳动
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: AnimatedBuilder(
                          animation: Listenable.merge([
                            _textAnimationController,
                            _fadeOutController,
                          ]),
                          builder: (context, child) {
                            return Opacity(
                              alwaysIncludeSemantics: true,
                              opacity:
                                  _showEasterEgg || _isFadingOut ? 1.0 : 0.0,
                              child: Text(
                                _currentEasterEggText.isEmpty
                                    ? "占位文本"
                                    : _currentEasterEggText,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14, // 缩小字体大小
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                // 作者信息
                Card(
                  elevation: 0,
                  color: Colors.transparent,
                  //  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15.0),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ListTile(
                          leading: Icon(
                            Ionicons.person_outline,
                            color: Theme.of(context).primaryColor,
                          ),
                          title: Text(
                            "开发者",
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          subtitle: Text('CC米饭'),
                        ),
                        Divider(),
                        SizedBox(height: 10),
                        Text(
                          "超级包菜",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "这是一个实用工具应用，帮助学生更便捷地查看课表、成绩和校园信息。",
                          style: TextStyle(fontSize: 16),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
                // 版本信息
                Text(
                  textAlign: TextAlign.center,
                  "本项目的诞生离不开开源社区。\n感谢YiQiuYes提供的喝水以及洗澡代码\n感谢开源项目onexiaolaji/qzjw的密码加密方法",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  "版本: 1.6.0",
                  style: TextStyle(
                    fontSize: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
