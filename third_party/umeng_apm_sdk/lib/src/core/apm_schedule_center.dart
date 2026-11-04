import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/logger.dart';
import 'package:umeng_apm_sdk/src/store/global.dart';
import 'package:umeng_apm_sdk/src/core/apm_pubsub_event_center.dart';

abstract class ApmScheduleCenter extends Logger {
  Map<String, dynamic> get getStore => GlobalStore.singleInstance.getStore;

  void setStoreProperty({required String name, dynamic value}) {
    GlobalStore.singleInstance.setProperty(name: name, value: value);
  }

  void setStoreMultiProperty(List<Map<String, dynamic>>? config) {
    GlobalStore.singleInstance.setMultiProperty(config: config);
  }

  void subscribeEvent(Map<String, dynamic>? config) {
    ApmPubsubEventCenter().subscribeEvent(config);
  }

  void dispatchEvent({required ACTIONS type, Map? data}) {
    ApmPubsubEventCenter().dispatchEvent(type, data);
  }
}
