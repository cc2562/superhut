import 'package:umeng_apm_sdk/src/event/base_event.dart';
import 'package:umeng_apm_sdk/src/utils/utils.dart';
import 'package:umeng_apm_sdk/src/core/apm_event_observer.dart';

/// APM性能事件中心
class ApmPerformanceEventCenter {
  ApmPerformanceEventCenter() {
    _instance = this;
  }

  static ApmPerformanceEventCenter? _instance;

  static ApmPerformanceEventCenter get singleInstance =>
      _instance ??= ApmPerformanceEventCenter();

  final Map<Type, Set<ApmEventObserver>> _listeners =
      <Type, Set<ApmEventObserver>>{};

  /// 分发事件
  void dispatchEvent(BaseEvent event) {
    nativeTryCatch(handler: () {
      final Set<ApmEventObserver>? observerSet = _listeners[event.runtimeType];
      if (observerSet != null) {
        for (ApmEventObserver observer in observerSet) {
          observer.onReceivedEvent(event);
        }
      }
    });
  }

  /// 订阅事件
  void subscribe(
      ApmEventObserver apmEventObserver, List<Type> subscribedEventList) {
    if (subscribedEventList.isNotEmpty) {
      for (Type type in subscribedEventList) {
        Set<ApmEventObserver> observerSet = Set();
        if (_listeners.containsKey(type)) {
          observerSet = _listeners[type]!;
        } else {
          _listeners[type] = observerSet;
        }
        observerSet.add(apmEventObserver);
      }
    }
  }
}
