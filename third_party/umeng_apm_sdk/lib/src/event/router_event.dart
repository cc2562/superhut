import 'package:flutter/widgets.dart';
import 'package:umeng_apm_sdk/src/event/base_event.dart';

enum RouterEventType { pop, push, remove, replace, paused }

class RouterEvent extends BaseEvent {
  final RouterEventType eventType;
  final Route? route;
  final Route? previousRoute;

  RouterEvent(
    this.eventType,
    this.route,
    this.previousRoute, {
    Map<dynamic, dynamic>? params,
  }) : super(params: params);

  get transitionDuration => null;
}
