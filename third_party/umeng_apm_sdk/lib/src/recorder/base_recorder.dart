import 'package:umeng_apm_sdk/src/core/apm_performance_event_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_pubsub_event_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_event_observer.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

abstract class BaseRecorder with ApmEventObserver {
  BaseRecorder() {
    ApmPerformanceEventCenter.singleInstance
        .subscribe(this, subscribedEventList());
  }
  void dispatchSendLogEvent(ACTIONS event) {
    ApmPubsubEventCenter().dispatchEvent(event, null);
  }
}
