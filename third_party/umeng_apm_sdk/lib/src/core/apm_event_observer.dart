import 'package:umeng_apm_sdk/src/event/base_event.dart';

mixin ApmEventObserver {
  void onReceivedEvent(BaseEvent event);

  List<Type> subscribedEventList();
}
