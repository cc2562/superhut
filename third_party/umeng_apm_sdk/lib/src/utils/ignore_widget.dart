import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// 用于排除掉不想计入页面覆盖率计算的 Widget
class PerformanceIgnoreWidget extends SingleChildRenderObjectWidget {
  const PerformanceIgnoreWidget({
    Key? key,
    this.ignore = false,
    Widget? child,
  }) : super(
          key: key,
          child: child,
        );

  final bool ignore;

  @override
  PerformanceIgnoreRenderObject createRenderObject(BuildContext context) {
    return PerformanceIgnoreRenderObject(ignore: ignore);
  }

  @override
  void updateRenderObject(
      BuildContext context, PerformanceIgnoreRenderObject renderObject) {
    renderObject.ignore = ignore;
  }
}

class PerformanceIgnoreRenderObject extends RenderProxyBox {
  bool ignore;

  PerformanceIgnoreRenderObject({
    this.ignore = false,
    RenderBox? child,
  }) : super(child);
}
