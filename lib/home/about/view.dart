import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:math' as math;
import 'package:confetti/confetti.dart'; // 添加彩带库
import 'package:flutter/services.dart';
import 'package:ionicons/ionicons.dart'; // 导入服务包，用于震动
import 'package:sensors_plus/sensors_plus.dart'; // 导入传感器包，用于重力感应
import 'dart:async'; // 导入异步包，用于处理传感器数据流

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> with TickerProviderStateMixin {
  late AnimationController _flipController;
  late AnimationController _swingController;
  late AnimationController _returnController; // 添加回正动画控制器
  late ConfettiController _confettiController; // 添加彩带控制器
  late AnimationController _textAnimationController; // 添加文字动画控制器
  late AnimationController _fadeOutController; // 添加淡出动画控制器
  bool _isAnimating = false;
  bool _isDragging = false;
  double _dragRotationY = 0.0; // 存储拖动时的Y轴旋转角度
  double _dragRotationX = 0.0; // 存储拖动时的X轴旋转角度（上下凹凸效果）
  double _totalRotation = 0.0; // 记录总旋转角度
  bool _showEasterEgg = false; // 是否显示彩蛋
  double _lastDragRotationY = 0.0; // 记录上一次拖动的Y轴旋转角度
  String _currentEasterEggText = ""; // 当前显示的彩蛋文本
  double _textOpacity = 0.0; // 文字整体的不透明度
  bool _isFadingOut = false; // 是否正在淡出
  String _displayedText = ""; // 当前逐字显示的文本
  int _currentCharIndex = 0; // 当前显示到第几个字符
  List<double> _charOpacities = []; // 存储每个字符的不透明度
  
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
    
    // 彩带控制器
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
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
    
    // 添加回正动画监听
    _returnController.addListener(() {
      if (mounted) {
        setState(() {
          // 线性插值计算当前旋转角度
          _dragRotationY = _lastDragRotationY * (1 - _returnController.value);
          _dragRotationX = _dragRotationX * (1 - _returnController.value);
        });
      }
    });
    
    _returnController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _returnController.reset();
        setState(() {
          _dragRotationY = 0.0;
          _dragRotationX = 0.0;
          _useGravity = true; // 回正动画完成后，重新启用重力感应
        });
      }
    });
    
    // 添加文字动画监听
    _textAnimationController.addListener(() {
      if (mounted) {
        setState(() {
          // 更新文字不透明度
          _textOpacity = _textAnimationController.value;
        });
      }
    });
    
    // 添加淡出动画监听
    _fadeOutController.addListener(() {
      if (mounted) {
        setState(() {
          _textOpacity = 1.0 - _fadeOutController.value;
        });
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
    _accelerometerSubscription = accelerometerEvents.listen((AccelerometerEvent event) {
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
          xInput = event.x > 0 
              ? event.x - deadZoneX
              : event.x + deadZoneX;
        }
        
        // 只有当Y轴倾斜超过阈值时才应用旋转
        if (event.y.abs() > deadZoneY) {
          // 保留超出中立区域的部分
          yInput = event.y > 0 
              ? event.y - deadZoneY
              : event.y + deadZoneY;
        }
        
        // 重力数据是相反的，所以需要取负值
        final double targetRotationY = -xInput * 0.2; // 左右倾斜
        final double targetRotationX = yInput * 0.1; // 前后倾斜
        
        // 应用阻尼效果，使运动更平滑
        setState(() {
          _gravityRotationY = _gravityRotationY * 0.8 + targetRotationY * 0.2;
          _gravityRotationX = _gravityRotationX * 0.8 + targetRotationX * 0.2;
          
          // 限制旋转范围
          _gravityRotationY = _gravityRotationY.clamp(-0.5, 0.5);
          _gravityRotationX = _gravityRotationX.clamp(-0.2, 0.2);
        });
      }
    });
  }

  @override
  void dispose() {
    _flipController.dispose();
    _swingController.dispose();
    _returnController.dispose();
    _confettiController.dispose();
    _textAnimationController.dispose();
    _fadeOutController.dispose();
    _accelerometerSubscription?.cancel(); // 取消传感器订阅
    super.dispose();
  }
  
  // 更新字符不透明度
  void _updateCharOpacities() {
    // 重置不透明度数组
    _charOpacities = List.filled(_currentCharIndex, 0.0);
    
    // 计算每个字符的不透明度
    for (int i = 0; i < _currentCharIndex; i++) {
      // 计算该字符应显示多久
      double timeDisplayed = (_textAnimationController.value * _currentEasterEggText.length - i) / 3;
      // 限制在0-1之间
      _charOpacities[i] = timeDisplayed.clamp(0.0, 1.0);
    }
  }
  
  // 随机选择一个彩蛋文本
  void _selectRandomEasterEggText() {
    final random = math.Random();
    final index = random.nextInt(_easterEggTexts.length);
    _currentEasterEggText = _easterEggTexts[index];
    _displayedText = "";
    _currentCharIndex = 0;
    _charOpacities = [];
    _textOpacity = 0.0;
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
      // 触发震动反馈
      HapticFeedback.selectionClick();
      _flipController.forward();
    }
  }
  
  // 处理手指拖动
  void _onPanUpdate(DragUpdateDetails details) {
    if (_isAnimating) return; // 如果正在播放动画，不处理拖动
    
    setState(() {
      _isDragging = true;
      _useGravity = false; // 拖动期间禁用重力感应
      
      // 记录上一次的旋转角度，用于计算旋转了多少圈
      double previousRotationY = _dragRotationY;
      
      // 水平移动距离转换为旋转角度（每10逻辑像素对应π/8弧度）
      // 注意这里用-=，让滑动方向与旋转方向匹配
      _dragRotationY -= details.delta.dx * math.pi / 80;
      
      // 计算旋转增量并累加到总旋转角度
      double deltaRotation = _dragRotationY - previousRotationY;
      _totalRotation += deltaRotation.abs();
      
      // 当旋转角度变化超过一定阈值时触发震动
      if (deltaRotation.abs() > 0.1) {
        HapticFeedback.lightImpact(); // 轻微震动
      }
      
      // 检查是否旋转超过4圈（8π）
      if (_totalRotation >= 8 * math.pi && !_showEasterEgg && !_isFadingOut) {
        _showEasterEgg = true;
        _confettiController.play();
        // 选择随机彩蛋文本并开始动画
        _selectRandomEasterEggText();
        // 触发较强的震动提示用户发现了彩蛋
        HapticFeedback.mediumImpact();
        // 重置总旋转角度计数
        _totalRotation = 0.0;
        // 8秒后开始淡出彩蛋文字
        Future.delayed(Duration(seconds: 8), () {
          if (mounted && _showEasterEgg && !_isFadingOut) {
            _isFadingOut = true;
            _fadeOutController.forward(from: 0.0);
          }
        });
      }
      
      // 垂直移动转换为X轴旋转（上下凹凸效果）
      // 限制X轴旋转范围在-0.3到0.3弧度之间（约-17度到17度）
      double previousRotationX = _dragRotationX;
      _dragRotationX -= details.delta.dy * math.pi / 200;
      _dragRotationX = _dragRotationX.clamp(-0.3, 0.3);
      
      // 当垂直旋转角度变化超过一定阈值时也触发震动
      if ((previousRotationX - _dragRotationX).abs() > 0.05) {
        HapticFeedback.lightImpact(); // 轻微震动
      }
    });
  }
  
  // 处理拖动结束
  void _onPanEnd(DragEndDetails details) {
    if (_isAnimating) return;
    
    setState(() {
      _isDragging = false;
      _lastDragRotationY = _dragRotationY; // 记录当前旋转角度
      
      // 启动回正动画
      _returnController.forward(from: 0.0);
      
      // 触发轻微震动，表示拖动结束，开始回弹
      HapticFeedback.lightImpact();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      appBar: AppBar(
        title: Text("关于"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            physics: NeverScrollableScrollPhysics(),
            padding: EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                // 跨性别旗帜3D徽章动画
                Center(
                  child: Column(
                    children: [
                      // 彩带效果
                      Align(
                        alignment: Alignment.center,
                        child: ConfettiWidget(
                          confettiController: _confettiController,
                          blastDirectionality: BlastDirectionality.explosive,
                          particleDrag: 0.05,
                          emissionFrequency: 0.05,
                          numberOfParticles: 20,
                          gravity: 0.1,
                          colors: const [
                            Color(0xff5BCEFA),
                            Color(0xffF5A9B8),
                            Colors.white,
                            Color(0xff5BCEFA),
                          ],
                        ),
                      ),
                      // 徽章顶部的挂绳

                      AnimatedBuilder(
                        animation: Listenable.merge([_flipController, _swingController, _returnController]),
                        builder: (context, child) {
                          // 翻转动画值 (绕Y轴)
                          final double flipValue = _flipController.value;
                          
                          // 摆动动画 (绕X轴微微摆动)
                          final double swingAngle = (_swingController.value < 0.5 
                              ? math.sin(_swingController.value * 4 * math.pi) * 0.1
                              : math.sin(_swingController.value * 2 * math.pi) * 0.05);
                          
                          // 计算Y轴旋转角度 - 来自动画、拖动或重力感应
                          double rotationY = _isAnimating 
                              ? flipValue * 2 * math.pi  // 动画控制的旋转
                              : _isDragging ? _dragRotationY : _dragRotationY + _gravityRotationY; // 拖动控制的旋转或重力感应
                          
                          // 计算X轴旋转角度 - 用于实现上下凹凸效果
                          double rotationX = _isAnimating 
                              ? swingAngle  // 动画控制的旋转
                              : _isDragging ? _dragRotationX : _dragRotationX + _gravityRotationX; // 拖动控制的旋转或重力感应
                          
                          // 使用Matrix4进行3D转换
                          final Matrix4 transform = Matrix4.identity()
                            ..setEntry(3, 2, 0.002) // 透视效果
                            ..rotateX(rotationX) // X轴旋转（上下凹凸效果）
                            ..rotateY(rotationY); // Y轴翻转
                          
                          // 计算当前是否显示背面
                          bool showBack = false;
                          double normalizedRotation = (rotationY % (2 * math.pi)) / (2 * math.pi);
                          if ((normalizedRotation >= 0.25 && normalizedRotation < 0.75) || 
                              (normalizedRotation >= 1.25 && normalizedRotation < 1.75)) {
                            showBack = true;
                          }
                          
                          // 计算旗子厚度的显示 - 当旗子从侧面看时显示厚度
                          bool showLeftEdge = normalizedRotation >= 0.125 && normalizedRotation < 0.375;
                          bool showRightEdge = normalizedRotation >= 0.625 && normalizedRotation < 0.875;
                          
                          // 根据旋转角度计算厚度部分的宽度
                          double leftEdgeWidth = 0.0;
                          double rightEdgeWidth = 0.0;
                          
                          if (showLeftEdge) {
                            // 左侧边缘厚度 - 根据旋转角度动态计算
                            double position = (normalizedRotation - 0.125) / 0.25; // 0到1之间的值
                            leftEdgeWidth = 6.0 * math.sin(position * math.pi); // 最大厚度为6逻辑像素
                          }
                          
                          if (showRightEdge) {
                            // 右侧边缘厚度 - 根据旋转角度动态计算
                            double position = (normalizedRotation - 0.625) / 0.25; // 0到1之间的值
                            rightEdgeWidth = 6.0 * math.sin(position * math.pi); // 最大厚度为6逻辑像素
                          }
                          
                          return GestureDetector(
                            onTap: _startAnimation,
                            onPanUpdate: _onPanUpdate,
                            onPanEnd: _onPanEnd,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: transform,
                              child: Container(
                                width: 200,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  color: Colors.grey.shade200,

                                  boxShadow: [
                                    BoxShadow(
                                      color: Theme.of(context).colorScheme.shadow.withAlpha(80),
                                      blurRadius: 8,
                                      offset: Offset(2, 3),
                                    ),
                                  ],
                                ),
                                child: Padding(
                                  padding: EdgeInsets.all(3.0), // 为金属边框留出空间
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(7),
                                    ),
                                    child: Stack(
                                      children: [
                                        // 主要旗帜内容
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(6),
                                          child: Transform(
                                            alignment: Alignment.center,
                                            transform: showBack ? Matrix4.rotationY(math.pi) : Matrix4.identity(),
                                            child: Stack(
                                              children: [
                                                SvgPicture.asset(
                                                  'assets/illustration/transgender_flag.svg',
                                                  fit: BoxFit.cover,
                                                  width: 200,
                                                  height: 120,
                                                ),
                                                // 添加高光效果
                                                Positioned.fill(
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        begin: Alignment.topLeft,
                                                        end: Alignment.bottomRight,
                                                        colors: [
                                                          Colors.white.withOpacity(0.3),
                                                          Colors.transparent,
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        
                                        // 左侧厚度边缘
                                        if (showLeftEdge) 
                                          Positioned(
                                            left: 0,
                                            top: 0,
                                            bottom: 0,
                                            width: leftEdgeWidth,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius: BorderRadius.only(
                                                  topLeft: Radius.circular(6),
                                                  bottomLeft: Radius.circular(6),
                                                ),
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerLeft,
                                                  end: Alignment.centerRight,
                                                  colors: [
                                                    Colors.grey[400]!,
                                                    Colors.grey[300]!,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        // 右侧厚度边缘
                                        if (showRightEdge) 
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            bottom: 0,
                                            width: rightEdgeWidth,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.grey[300],
                                                borderRadius: BorderRadius.only(
                                                  topRight: Radius.circular(6),
                                                  bottomRight: Radius.circular(6),
                                                ),
                                                gradient: LinearGradient(
                                                  begin: Alignment.centerRight,
                                                  end: Alignment.centerLeft,
                                                  colors: [
                                                    Colors.grey[400]!,
                                                    Colors.grey[300]!,
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        
                                        // 在旗子最上层添加金属质感的高光效果
                                        Positioned.fill(
                                          child: IgnorePointer(
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(6),
                                                gradient: LinearGradient(
                                                  begin: Alignment.topCenter,
                                                  end: Alignment.bottomCenter,
                                                  colors: [
                                                    Colors.white.withOpacity(0.15),
                                                    Colors.transparent,
                                                    Colors.black.withOpacity(0.05),
                                                  ],
                                                  stops: [0.0, 0.5, 1.0],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
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
                          animation: Listenable.merge([_textAnimationController, _fadeOutController]),
                          builder: (context, child) {
                            return Opacity(
                              alwaysIncludeSemantics: true,
                              opacity: _showEasterEgg || _isFadingOut ? 1.0 : 0.0,
                              child: Text(
                                _currentEasterEggText.isEmpty ? "占位文本" : _currentEasterEggText,
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
                  margin: EdgeInsets.symmetric(horizontal: 10, vertical: 0),
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
                          "工大超级APP",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "这是一个实用工具应用，帮助学生更便捷地查看课表、成绩和校园信息。",
                          style: TextStyle(
                            fontSize: 16,
                          ),
                        ),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 30),
                // 版本信息
                Text(
                  "本项目的诞生离不开开源社区。感谢YiQiuYes提供的喝水以及洗澡代码",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                ),
                Text(
                  "版本: 0.0.5",
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
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