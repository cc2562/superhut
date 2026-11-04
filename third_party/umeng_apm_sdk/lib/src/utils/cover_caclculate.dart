import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import 'package:umeng_apm_sdk/src/utils/ignore_widget.dart';

class CoverCalculate {
  Percent calculateCoverage(
      RenderObject? curRenderObject, List<RenderInfo> validChildren) {
    Size renderSize = Size.zero;
    if (curRenderObject is RenderBox && curRenderObject.hasSize) {
      renderSize = curRenderObject.size;
    }
    if (curRenderObject is RenderView) {
      renderSize = curRenderObject.size;
    }

    if (!(curRenderObject is PerformanceIgnoreRenderObject &&
        curRenderObject.ignore)) {
      if (curRenderObject.runtimeType.toString() == '_RenderTheatre') {
        curRenderObject!.visitChildrenForSemantics((RenderObject child) {
          findValidChild(child, validChildren);
        });
      } else {
        curRenderObject!.visitChildren((RenderObject? child) {
          if (child != null) {
            findValidChild(child, validChildren);
          }
        });
      }
    }

    if (validChildren.isNotEmpty) {
      return calculateChildrenCoverage(validChildren, renderSize);
    }

    if (curRenderObject is TextureBox) {
      return curRenderObject.textureId != null
          ? Percent(1.0, 1.0)
          : Percent(0.0, 0.0);
    }
    if (curRenderObject is RenderImage) {
      return curRenderObject.image != null
          ? Percent(1.0, 1.0)
          : Percent(0.0, 0.0);
    }
    if (curRenderObject is RenderParagraph) {
      final InlineSpan span = curRenderObject.text;
      if (span is TextSpan) {
        return (span.text != null && span.text!.isNotEmpty) ||
                (span.children != null && span.children!.isNotEmpty)
            ? Percent(1.0, 1.0)
            : Percent(0.0, 0.0);
      }
      if (span is WidgetSpan) {
        return Percent(1.0, 1.0);
      }
    }

    if (curRenderObject is! ContainerRenderObjectMixin &&
        curRenderObject is! RenderObjectWithChildMixin &&
        renderSize != null &&
        !renderSize.isEmpty) {
      return Percent(1.0, 1.0);
    }

    ///匹配不上姑且认为是一个无效的RenderObject
    return Percent(0.0, 0.0);
  }

  ///找到所有有效的子RenderObject
  void findValidChild(RenderObject child, List<RenderInfo> validChildren) {
    final List<RenderInfo> childValidChildren = [];
    final Percent childPercent = calculateCoverage(child, childValidChildren);

    Offset childOffset = Offset.zero;
    if (child.parentData is BoxParentData) {
      final BoxParentData parentData = child.parentData as BoxParentData;
      childOffset = parentData.offset;
    } else if (child.parentData is SliverLogicalParentData) {
      ///Scroll下特殊处理
      SliverConstraints? constraints;
      final RenderObject? parent = child.parent as RenderObject?;
      if (parent is RenderSliver) {
        constraints = parent.constraints;
      }
      AxisDirection axisDirection = AxisDirection.down;
      if (constraints != null) {
        axisDirection = constraints.axisDirection;
      }
      final SliverLogicalParentData? parentData =
          child.parentData as SliverLogicalParentData?;
      if (AxisDirection.down == axisDirection ||
          AxisDirection.up == axisDirection) {
        childOffset = Offset(0.0, parentData?.layoutOffset ?? 0.0);
      } else if (AxisDirection.left == axisDirection ||
          AxisDirection.right == axisDirection) {
        childOffset = Offset(parentData?.layoutOffset ?? 0.0, 0.0);
      }
    } else if (child.parentData is SliverPhysicalParentData) {
      final SliverPhysicalParentData parentData =
          child.parentData as SliverPhysicalParentData;
      childOffset =
          Offset(parentData.paintOffset.dx, parentData.paintOffset.dy);
    }

    Size childSize = Size.zero;
    if (child is RenderBox && child.hasSize) {
      childSize = child.size;
    }

    if (childPercent.isValid()) {
      validChildren.add(RenderInfo(childOffset, childSize));
    } else {
      if (childValidChildren.isNotEmpty) {
        for (RenderInfo childValidChild in childValidChildren) {
          childValidChild.offset = childValidChild.offset + childOffset;
          validChildren.add(childValidChild);
        }
      }
    }
  }

  ///仅计算有效子RenderObject
  Percent calculateChildrenCoverage(
      List<RenderInfo> validChildren, Size? renderSize) {
    final List<Line> widthLineList = [];
    final List<Line> heightLineList = [];

    ///找出所有有效区间
    for (RenderInfo validChild in validChildren) {
      final Offset offset = validChild.offset;
      final Line widthLine = Line(offset.dx, offset.dx + validChild.size.width);
      final Line heightLine =
          Line(offset.dy, offset.dy + validChild.size.height);

      if (widthLineList.isEmpty && heightLineList.isEmpty) {
        widthLineList.add(widthLine);
        heightLineList.add(heightLine);
      } else {
        insertIntoList(widthLine, widthLineList);
        insertIntoList(heightLine, heightLineList);
      }
    }

    ///总长度等于有效区间之和
    double widthLength = 0.0;
    for (Line line in widthLineList) {
      widthLength = widthLength + line.max - line.min;
    }
    double heightLength = 0.0;
    for (Line line in heightLineList) {
      heightLength = heightLength + line.max - line.min;
    }

    if (renderSize != null &&
        !renderSize.isEmpty &&
        renderSize.width > 0 &&
        renderSize.height > 0) {
      return Percent(
          widthLength / renderSize.width, heightLength / renderSize.height);
    } else {
      return Percent(0.0, 0.0);
    }
  }

  void insertIntoList(Line targetLine, List<Line> lineList) {
    int jointIndex = -1;
    for (int i = 0; i < lineList.length;) {
      final line = lineList[i];
      if (line.overlap(targetLine)) {
        /// 首个可合并区间，直接将 target 合并
        if (jointIndex == -1) {
          jointIndex = i;
          lineList[i].combine(targetLine);
        } else {
          /// 重合则合并到第一个区间
          lineList[jointIndex].combine(line);
          lineList.removeAt(i);
          continue;
        }
      }

      i++;
    }

    if (jointIndex == -1) {
      lineList.add(targetLine);
    }
  }

  void debugGetRenderTree(RenderObject renderObject, int deep) {
    assert(() {
      print('$deep - ${renderObject.runtimeType} ${renderObject.hashCode}');
      deep++;
      renderObject.visitChildren((RenderObject? child) {
        if (child != null) {
          debugGetRenderTree(child, deep);
        }
      });
      return true;
    }());
  }
}

class Percent {
  static const double TARGET_PERCENT_HEIGHT = 0.8;
  static const double TARGET_PERCENT_WIDTH = 0.6;

  double x;
  double y;

  Percent(this.x, this.y);

  bool isValid() {
    return y > Percent.TARGET_PERCENT_HEIGHT &&
        x > Percent.TARGET_PERCENT_WIDTH;
  }

  @override
  String toString() {
    return 'Percent: width = $x,height = $y';
  }
}

class Line {
  late double _min;
  late double _max;

  double get min => _min;

  set min(double value) {
    if (value < 0) {
      _min = 0.0;
    } else {
      _min = value;
    }
  }

  double get max => _max;

  set max(double value) {
    if (value < 0) {
      _max = 0.0;
    } else {
      _max = value;
    }
  }

  double get length => _max - _min;

  Line(double min, double max) {
    this.min = min;
    this.max = max;
  }

  void combine(Line line) {
    min = math.min(min, line.min);
    max = math.max(max, line.max);
  }

  /// Return true if there is some overlap with the target interval.
  bool overlap(Line line) {
    final start = math.min(line.min, min);
    final end = math.max(line.max, max);
    return line.length + length - (end - start) >= 0;
  }
}

class RenderInfo {
  Offset offset;
  Size size;

  RenderInfo(this.offset, this.size);
}
