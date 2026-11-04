import 'package:flutter/rendering.dart';

class RenderViewValidator {
  bool _found = false;

  bool isValid(RenderObject? curRenderObject) {
    if (_found) {
      return true;
    }
    // 包含图片
    if (curRenderObject is RenderImage) {
      _found = true;
    }

    // 包含文本节点，且不为空
    if (curRenderObject is RenderParagraph &&
        curRenderObject.text.toPlainText().isNotEmpty == true) {
      _found = true;
    }

    // Texture
    if (curRenderObject is TextureBox) {
      _found = true;
    }

    // 深度优先遍历
    if (curRenderObject != null && !_found) {
      if (curRenderObject is RenderExcludeSemantics) {
        curRenderObject = curRenderObject.child;
      }
      curRenderObject!.visitChildrenForSemantics((child) {
        if (!_found) {
          isValid(child);
        }
      });
    }

    return _found;
  }
}
