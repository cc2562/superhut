import 'package:flutter/widgets.dart';
import 'package:flutter/rendering.dart';
import 'package:umeng_apm_sdk/src/event/base_event.dart';

enum ApmRenderEventType { startFrame, endFrame }

class ApmRenderEvent extends BaseEvent {
  final ApmRenderEventType eventType;
  final RenderObject? renderObject;
  final Map<dynamic, dynamic>? params;

  ApmRenderEvent(this.eventType, {this.renderObject, this.params})
      : super(params: params);
}
