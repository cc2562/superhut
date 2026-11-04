import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';
import 'package:umeng_apm_sdk/src/core/apm_performance.dart';
import 'package:umeng_apm_sdk/src/core/apm_pubsub_event_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/data/data.dart';
import 'package:umeng_apm_sdk/src/event/event.dart';
import 'package:umeng_apm_sdk/src/processor/page_perf_data_processor.dart';
import 'package:umeng_apm_sdk/src/processor/pv_data_processor.dart';
import 'package:umeng_apm_sdk/src/recorder/base_recorder.dart';
import 'package:umeng_apm_sdk/src/store/global.dart';
import 'package:umeng_apm_sdk/src/utils/cover_caclculate.dart';
import 'package:umeng_apm_sdk/src/utils/render_view_validator.dart';
import 'package:umeng_apm_sdk/src/utils/utils.dart';

class PagePerfRecorder extends BaseRecorder {
  AnimationStatus? _status;

  /// 记录页面栈
  List pageStack = [];

  Map<int?, PagePerfData?> pagePerfDataMap = {};

  Map<int?, PagePerfDataProcessor?> pagePerfDataProcessorMap = {};

  Map<int?, bool?> ttiRecordedMap = {};

  Timer? _lastTimer;

  // 记录页面性能日志实例
  PagePerfData? pagePerfData;

  bool enableTrackingPagePerf() {
    return GlobalStore.singleInstance.getStore['enableTrackingPagePerf'];
  }

  Future<void> _addPageStack(Route? route) async {
    if (route != null) {
      ApmPubsubEventCenter().dispatchMultiEvent([
        {"type": ACTIONS.SET_PAGE_NAME, "data": route},
        {"type": ACTIONS.SET_PV_ID, "data": null}
      ]);
      String? pvId = GlobalStore.singleInstance.getStore[KEY_PVID];
      if (pvId != null) {
        pageStack.add({'route': route, 'pvId': pvId});
      }
      // 记录pv
      Map<String, dynamic>? nativeInfo =
          await ApmMethodChannel.getNativeParams();
      PvDataProcessor().push(
          pvData: PvData(enableException: 'Y', pagePerf: 'Y', pageFps: 'Y'),
          nativeInfo: nativeInfo);
      super.dispatchSendLogEvent(ACTIONS.SEND_PV_LOG);
    }
  }

  void _removePageStack(Route? route) {
    if (route != null) {
      pageStack.remove(route);
    }
  }

  Route? _selectCurrentPageStack() {
    Route? currentRoute;
    if (pageStack.length > 0) {
      pageStack.forEach((el) {
        Route? route = el!['route'];
        if (route != null) {
          bool isCurrent = route.isCurrent;
          if (isCurrent) {
            currentRoute = route;
            ApmPubsubEventCenter().dispatchMultiEvent([
              {"type": ACTIONS.SET_PAGE_NAME, "data": route},
              {"type": ACTIONS.SET_PV_ID, "data": el![KEY_PVID]}
            ]);
          }
        }
      });
    }
    return currentRoute;
  }

  void _captureFCP() {
    final RenderView renderRoot = WidgetsBinding.instance!.renderView;
    if (renderRoot.child != null &&
        RenderViewValidator().isValid(renderRoot.child)) {
      /// 采集FCP
      pagePerfData?.setLog(PagePerfLog.fcpTimestamp, getTimestamp());
    } else {
      WidgetsBinding.instance!.addPostFrameCallback((Duration callback) {
        _captureFCP();
      });
    }
  }

  Future<void> _dispatchPagePerfData(int hashcode) async {
    final PagePerfData? pagePerfData = pagePerfDataMap[hashcode];
    final PagePerfDataProcessor? pagePerfDataProcessor =
        pagePerfDataProcessorMap[hashcode];
    if (pagePerfData != null && pagePerfDataProcessor != null) {
      // 添加上一个页面性能日志队列
      pagePerfDataProcessor.push(pagePerfData: pagePerfData);
      // 上报页面性能日志
      super.dispatchSendLogEvent(ACTIONS.SEND_PAGE_PERF_LOG);
      // 发送完清空实例
      pagePerfDataMap[hashcode] = null;
      pagePerfDataProcessorMap[hashcode] = null;
    }
  }

  Future<void> _initPagePerfData(int hashCode, bool isFirstPage) async {
    pagePerfData = PagePerfData(isFirstPage);
    pagePerfDataMap[hashCode] = pagePerfData;
    Map<String, dynamic>? nativeInfo = await ApmMethodChannel.getNativeParams();
    pagePerfDataProcessorMap[hashCode] = PagePerfDataProcessor(nativeInfo);
    ttiRecordedMap[hashCode] = false;
  }

  bool calculateCoverage(RenderObject? root) {
    final List<RenderInfo> validChildren = <RenderInfo>[];
    final CoverCalculate calculate = CoverCalculate();
    final Percent percent = calculate.calculateCoverage(root, validChildren);
    final bool isValid = percent.isValid();
    return isValid;
  }

  int? getCurrentPageHashCode(Route? route) {
    if (route is Route) {
      final int? hashCode = route.hashCode;
      if (hashCode is int) return hashCode;
    }
    return null;
  }

  @override
  void onReceivedEvent(BaseEvent event) {
    if (!enableTrackingPagePerf()) return;
    if (event is ApmRenderEvent) {
      if (event.renderObject != null && event.renderObject is RenderObject) {
        Route? currentPageRoute = _selectCurrentPageStack();
        int? hashCode = getCurrentPageHashCode(currentPageRoute);
        bool? ttiRecorded = ttiRecordedMap[hashCode];
        if (hashCode is int) {
          if (ttiRecorded is bool && ttiRecorded) {
            return;
          }
        } else {
          return;
        }
        // 计算有效元素占页面比例
        final isValid = calculateCoverage(event.renderObject);
        void setTTI() {
          pagePerfData?.setLog(PagePerfLog.ttiTimestamp, getTimestamp());
          // 结束初始化状态 更新应用状态
          GlobalStore.singleInstance
              .setProperty(name: KEY_APP_STATUS, value: 2);
          ttiRecordedMap[hashCode] = true;
        }

        _lastTimer?.cancel();

        if (isValid) {
          setTTI();
        } else {
          // 兜底逻辑为，当一个页面在500ms内没有发生刷帧，则认为页面可交互
          _lastTimer = Timer(Duration(milliseconds: 500), () {
            setTTI();
          });
        }
      }
    }
    if (event is ApmAppLifecycleEvent) {
      final ApmAppLifecycleState? appLifecycleState = event.appLifecycleState;
      switch (appLifecycleState) {
        // 应用退至后台
        case ApmAppLifecycleState.paused:
          Route? currentPageRoute = _selectCurrentPageStack();
          int? hashCode = getCurrentPageHashCode(currentPageRoute);
          if (hashCode is int) {
            _dispatchPagePerfData(hashCode);

            // 同步应用下当前页面退至后台状态
            ApmPerformance.singleInstance.pushEvent(
                RouterEvent(RouterEventType.paused, currentPageRoute, null));
          }
          break;
        default:
      }
    }

    if (event is RouterEvent) {
      final Route? route = event.route;
      final Route? previousRoute = event.previousRoute;
      final int hashCode = route.hashCode;
      final int? previousHashCode = previousRoute?.hashCode;

      Duration routeTransitionDuration = Duration.zero;
      if (route is TransitionRoute) {
        routeTransitionDuration = route.transitionDuration;
      }
      if (event.eventType == RouterEventType.push ||
          event.eventType == RouterEventType.replace) {
        final isFirstPage = pagePerfData == null;
        final pageStartTimestamp = getTimestamp();
        GlobalStore.singleInstance.setProperty(name: KEY_APP_STATUS, value: 0);
        // 采集页面PV
        _addPageStack(route);

        if (!enableTrackingPagePerf()) return;

        // 判断是否存在该页面hashcode，不存在初始化日志对象实例
        if (!pagePerfDataMap.containsKey(hashCode)) {
          _initPagePerfData(hashCode, isFirstPage);
        }
        if (previousHashCode is int &&
            pagePerfDataMap.containsKey(previousHashCode)) {
          /// 跳转下一页触发添加发送页面性能日志操作
          _dispatchPagePerfData(previousHashCode);
        }

        /// 页面过渡转场开始时间
        pagePerfData?.setLog(PagePerfLog.tdStartTimestamp, pageStartTimestamp);

        if (isFirstPage) {
          // 首页无过渡转场时间直接赋值开始时间
          pagePerfData?.setLog(PagePerfLog.tdEndTimestamp, pageStartTimestamp);
        } else {
          if (route!.settings.name == null) {
            pagePerfData?.setLog(
                PagePerfLog.tdEndTimestamp, pageStartTimestamp);
          }
          if (route is TransitionRoute &&
              route.transitionDuration.inMilliseconds > 0) {
            route.animation?.addStatusListener((status) {
              if (_status == AnimationStatus.forward &&
                  status == AnimationStatus.completed) {
                /// 页面过渡转场结束时间
                pagePerfData?.setLog(
                    PagePerfLog.tdEndTimestamp, getTimestamp());
              } else {
                _status = status;
              }
            });
          }
        }

        WidgetsBinding.instance!.addPostFrameCallback((Duration callback) {
          /// 采集FP-首像素
          pagePerfData?.setLog(PagePerfLog.fpTimestamp, getTimestamp());
        });

        Future.delayed(routeTransitionDuration, () {
          /// 采集FCP
          _captureFCP();
        });
      }

      if (event.eventType == RouterEventType.pop ||
          event.eventType == RouterEventType.remove) {
        _removePageStack(route);
        _selectCurrentPageStack();

        if (!enableTrackingPagePerf()) return;
        if (route is Route) {
          /// 返回上一页面上报上页面日志
          int? hashCode = route.hashCode;
          if (pagePerfDataMap.containsKey(hashCode)) {
            _dispatchPagePerfData(hashCode);
          }
        }
      }
    }
  }

  @override
  List<Type> subscribedEventList() {
    return [RouterEvent, ApmAppLifecycleEvent, ApmRenderEvent];
  }
}
