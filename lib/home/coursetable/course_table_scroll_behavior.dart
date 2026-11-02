import 'package:flutter/material.dart';

/// 课表页专用的滚动行为：不挂任何 overscroll 指示器。
///
/// 起因是一个安卓端的视觉缺陷：滑到顶/底触发拉伸回弹时，毛玻璃与液态玻璃
/// 课程块会「重新刷一遍」并闪一下。原因是 Android 12+ 的
/// `StretchingOverscrollIndicator` 会对滚动内容做逐帧缩放变换，而课程卡的
/// 模糊（`BackdropFilter` / `LiquidGlassLens`）依赖所在层的后景快照——祖先层
/// 被持续变换时这份快照反复失效重建，模糊就闪断。
///
/// 因此课表页这两个承载玻璃课程卡的滚动容器干脆不挂指示器（拉伸、光晕都不
/// 画），滚到边缘内容直接停住。物理曲线、滚动条、拖拽设备集合仍继承
/// [MaterialScrollBehavior] 的默认值，iOS 的弹性回弹与桌面行为不受影响。
///
/// 只作用于课表页的周视图与日视图；其它页面维持 Material 默认的拉伸/光晕，
/// 不要扩大到全 App（那是超出需求的手感变更）。
class CourseTableScrollBehavior extends MaterialScrollBehavior {
  const CourseTableScrollBehavior();

  /// 直接返回 child：不包裹任何 overscroll 指示器。
  ///
  /// 注意：只把 physics 设成 [ClampingScrollPhysics] 并不能去掉拉伸，
  /// 指示器由这里决定（`ThemeData.androidOverscrollIndicator` 已废弃）。
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
