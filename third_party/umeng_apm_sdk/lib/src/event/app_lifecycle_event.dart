import 'package:umeng_apm_sdk/src/event/base_event.dart';

enum ApmAppLifecycleState {
  resumed,
  paused,
  inactive,
}

class ApmAppLifecycleEvent extends BaseEvent {
  final ApmAppLifecycleState appLifecycleState;

  ApmAppLifecycleEvent(
    this.appLifecycleState, {
    Map<dynamic, dynamic>? params,
  }) : super(params: params);
}
