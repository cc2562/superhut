import 'package:flutter/widgets.dart';

import 'package:umeng_apm_sdk/src/event/event.dart';
import 'package:umeng_apm_sdk/src/store/global.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/fps_hepler.dart';
import 'package:umeng_apm_sdk/src/recorder/base_recorder.dart';
import 'package:umeng_apm_sdk/src/data/page_fps_data.dart';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';
import 'package:umeng_apm_sdk/src/utils/utils.dart';

import 'package:umeng_apm_sdk/src/processor/page_fps_data_processor.dart';

class PageFpsRecorder extends BaseRecorder {
  Map<int?, ApmFpsHelper?> apmPageFpsHelperMap = {};

  Map<int?, PageFpsDataProcessor?> apmPageFpsProcessorMap = {};

  void _stopApmFpsHelper(int hashCode) {
    apmPageFpsHelperMap[hashCode]?.stop();
    apmPageFpsHelperMap[hashCode] = null;
  }

  bool enableTrackingPageFps() {
    return GlobalStore.singleInstance.getStore['enableTrackingPageFps'] ??
        false;
  }

  // 采集fps完成回调
  void _captureFpsFinishedCallback(
      int? pageHashCode, bool isFirstPage, List<String> frames) async {
    if (frames.isNotEmpty && pageHashCode is int) {
      PageFpsDataProcessor? pageFpsDataProcessor =
          apmPageFpsProcessorMap[pageHashCode];
      if (pageFpsDataProcessor is PageFpsDataProcessor) {
        double maxFps = double.parse(
            GlobalStore.singleInstance.getStore[KEY_MAX_FPS].toString());
        final pageFpsData =
            PageFpsData(frames.join(','), maxFps.toInt(), isFirstPage);
        pageFpsDataProcessor.push(pageFpsData: pageFpsData);
        apmPageFpsProcessorMap[pageHashCode] = null;
        super.dispatchSendLogEvent(ACTIONS.SEND_PAGE_FPS_LOG);
      }
    }
  }

  Future<void> _initPageCommonAndFpsHelper(
      int hashCode, bool isFirstPage) async {
    nativeTryCatch(handler: () async {
      if (!apmPageFpsProcessorMap.containsKey(hashCode)) {
        Map<String, dynamic>? nativeInfo =
            await ApmMethodChannel.getNativeParams();
        apmPageFpsProcessorMap[hashCode] = PageFpsDataProcessor(nativeInfo);
        apmPageFpsHelperMap[hashCode] =
            ApmFpsHelper(hashCode, isFirstPage, _captureFpsFinishedCallback);
        apmPageFpsHelperMap[hashCode]?.start();
      }
    });
  }

  @override
  void onReceivedEvent(BaseEvent event) {
    if (event is RouterEvent && enableTrackingPageFps()) {
      final Route? route = event.route;
      final Route? previousRoute = event.previousRoute;
      final int? hashCode = route.hashCode;
      final int? previousHashCode = previousRoute?.hashCode;

      if (event.eventType == RouterEventType.paused) {
        if (route is Route &&
            hashCode is int &&
            apmPageFpsHelperMap[hashCode] is ApmFpsHelper) {
          _stopApmFpsHelper(hashCode);
        }
      }

      // 当事件类型为push或replace时
      if (event.eventType == RouterEventType.push ||
          event.eventType == RouterEventType.replace) {
        final isFirstPage = apmPageFpsHelperMap.isEmpty;
        // 初始化fps计算实例
        if (!apmPageFpsHelperMap.containsKey(route.hashCode) &&
            hashCode is int) {
          _initPageCommonAndFpsHelper(hashCode, isFirstPage);
        }
        // 上一个页面fps计算实例停止
        if (previousRoute is Route &&
            previousHashCode is int &&
            apmPageFpsHelperMap[previousHashCode] is ApmFpsHelper) {
          _stopApmFpsHelper(previousHashCode);
        }
      }

      // 当事件类型为pop或remove时
      if (event.eventType == RouterEventType.pop ||
          event.eventType == RouterEventType.remove) {
        // 返回时 停止上一个页面计算实例
        if (route is Route &&
            hashCode is int &&
            apmPageFpsHelperMap[hashCode] is ApmFpsHelper) {
          _stopApmFpsHelper(hashCode);
        }
      }
    }
  }

  @override
  List<Type> subscribedEventList() {
    return [RouterEvent];
  }
}
