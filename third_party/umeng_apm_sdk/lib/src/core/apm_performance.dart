import 'package:umeng_apm_sdk/src/core/apm_performance_event_center.dart';
import 'package:umeng_apm_sdk/src/event/base_event.dart';

class ApmPerformance {
  ApmPerformance() {
    _instance = this;
  }

  static ApmPerformance? _instance;

  static ApmPerformance get singleInstance => _instance ??= ApmPerformance();

  void pushEvent(BaseEvent event) {
    ApmPerformanceEventCenter.singleInstance.dispatchEvent(event);
  }
}
