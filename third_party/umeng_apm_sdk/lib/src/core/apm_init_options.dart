import 'dart:io';
import 'dart:async';
import 'package:flutter/widgets.dart';

import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/core/apm_typedef.dart';
import 'package:umeng_apm_sdk/src/recorder/recorder.dart';
import 'package:umeng_apm_sdk/src/core/apm_report_log.dart';
import 'package:umeng_apm_sdk/src/core/apm_setup_trace.dart';
import 'package:umeng_apm_sdk/src/core/apm_schedule_center.dart';
import 'package:umeng_apm_sdk/src/core/apm_flutter_error.dart';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';
import 'package:umeng_apm_sdk/src/core/apm_cloud_config_manager.dart';
import 'package:umeng_apm_sdk/src/core/apm_widgets_flutter_binding.dart';

import 'package:umeng_apm_sdk/src/utils/helpers.dart';
import 'package:umeng_apm_sdk/src/trace/exception_trace.dart';
import 'package:umeng_apm_sdk/src/observer/navigator_observer.dart';

enum UmengApmEnv { Release, Alpha, Beta, RC, Dev }

// 记录初始化状态
bool _umengApmInited = false;

class UmengApmSdk extends ApmScheduleCenter {
  //  应用或模块名称
  String name;

  // 应用或模块版本+构建号
  String bver;

  // 运行业务环境
  UmengApmEnv? env;

  // 工程类型 app = 0 | module = 1
  int? projectType;

  // Flutter 版本
  String? flutterVersion;

  // 引擎版本
  String? engineVersion;

  // Flutter APM SDK 版本
  String sdkVersion = '2.3.7';

  // 是否开启SDK日志打印
  bool? enableLog;

  // 开启追踪页面fps
  bool? enableTrackingPageFps;

  // 开启追踪页面性能
  bool? enableTrackingPagePerf;

  // 开启网络分析
  bool? enableTrackingApi;

  //异常摘要过滤&匹配采集规则
  Map<String, dynamic>? errorFilter;

  // 带入继承ApmWidgetsFlutterBinding的覆写和初始化方法
  InitFlutterBinding? initFlutterBinding;

  // 抛出异常事件
  OnError? onError;

  UmengApmSdk(
      {required this.name,
      required this.bver,
      this.env,
      this.projectType = 0,
      this.flutterVersion = '-',
      this.enableLog = false,
      this.engineVersion = '-',
      this.errorFilter,
      this.initFlutterBinding,
      this.enableTrackingPageFps = false,
      this.enableTrackingPagePerf = false,
        this.enableTrackingApi = false,
      this.onError})
      : super() {
    nativeTryCatch(handler: () {
      // 是否开启打印日志
      if (enableLog is bool) {
        setStoreProperty(name: 'enableLog', value: enableLog);
      }
      if (!_umengApmInited) {
        setStoreMultiProperty([
          {"name": 'enableTrackingPageFps', "value": enableTrackingPageFps},
          {"name": 'enableTrackingPagePerf', "value": enableTrackingPagePerf},
          {"name": 'enableTrackingApi', "value": enableTrackingApi},
        ]);
        // 全局监听异常实例化
        ExceptionTrace.init(onError: onError);
        ApmRecorder.init();
        ApmSetupTrace();
      }
    });
  }

  callInitOptios() {
    nativeTryCatch(handler: () {
      ApmCloudConfigManager apmCloudConfigManager =
          ApmCloudConfigManager.singleInstance;
      bool enablePvLog = apmCloudConfigManager.flutterPvSamplingHit;
      if (!enablePvLog) {
        printLog('=======================================');
        errorLog('设备采样率未命中，停止初始化');
        printLog(
            '如测试设备需要集成测试，参考集成文档【运行验证】章节）https://developer.umeng.com/docs/193624/detail/2521038#WUJuw');
        printLog('=======================================');
        return;
      }
      printLog('=======================================');
      printLog('APMFlutter SDK 开始初始化配置');
      printLog('=======================================');
      //  订阅获取dart 版本
      dispatchEvent(type: ACTIONS.SET_DART_VERSION);

      // 创建 flutter session id
      dispatchEvent(type: ACTIONS.SET_SESSION_ID);

      dispatchEvent(type: ACTIONS.SET_DEVICE_MAX_FPS);

      // 验证入参字段
      bool validateResult = validateArguments();

      if (!validateResult) return;

      // 实例化并订阅发送日志事件
      final ApmReportLog reportLogInstance = ApmReportLog();
      // 订阅PV事件
      reportLogInstance.subscribePV();

      int enableExcConfig = apmCloudConfigManager.flutterDartExceptionState;
      int excCountConfig = apmCloudConfigManager.flutterDartExceptionMaxCount;
      if (enableExcConfig == 100 && excCountConfig > 0) {
        // 开始轮询扫描发送队列
        reportLogInstance.startTimerPollSendQueue();
      }

      bool enableAPIConfig = apmCloudConfigManager.flutterIsHaveAPIRateVersion;
      bool enablePageRate = apmCloudConfigManager.flutterPvDetailSamplingHit;
      bool enableAPIRate = apmCloudConfigManager.flutterAPISamplingHit;
      if (enableAPIConfig) {
        if(enablePageRate){
          // 订阅Page事件
          reportLogInstance.subscribePage();
        }
        if(enableAPIRate){
          // 订阅api事件
          reportLogInstance.subscribeAPI();
        }
      }else{
        // 订阅Page事件
        reportLogInstance.subscribePage();
      }
      // 完成初始化立即检查发送pv日志
      reportLogInstance.dispatchEvent(type: ACTIONS.SEND_PV_LOG);
    });
  }

  FutureOr<bool> waitNativeSdkInited() async {
    Map<String, dynamic>? cloudConfig =
        (await ApmMethodChannel.getCloudConfig()) ?? {};
    Map<String, dynamic>? nativeParams =
        (await ApmMethodChannel.getNativeParams()) ?? {};
    ApmCloudConfigManager apmCloudConfigManager =
        ApmCloudConfigManager.singleInstance;

    final bool isInited = nativeParams.containsKey(KEY_APPID) &&
        cloudConfig.containsKey(KEY_PV_SAMPLING_HIT) &&
        nativeParams[KEY_APPID] is String &&
        cloudConfig[KEY_PV_SAMPLING_HIT] is bool;
    if (nativeParams.containsKey(KEY_UMID_HEADER)) {
      printLog('【UMID】${nativeParams[KEY_UMID_HEADER]}');
    }
    if (nativeParams.containsKey(KEY_UMID)) {
      printLog('【UMID】${nativeParams[KEY_UMID]}');
    }

    if (isInited) {
      await apmCloudConfigManager.setCloudConfig(cloudConfig);
      await apmCloudConfigManager.initNativeStore();

      setStoreMultiProperty([
        {"name": 'baseInfo', "value": nativeParams},
        {"name": 'appid', "value": nativeParams[KEY_APPID]},
      ]);
    }
    return isInited;
  }

  init({AppRunner? appRunner}) {
    if (_umengApmInited) {
      warnLog('SDK 重复实例化，停止逻辑执行');
      return;
    }
    runZonedGuarded(() {
      nativeTryCatch(handler: () async {
        if (initFlutterBinding != null) {
          initFlutterBinding!();
        } else {
          ApmWidgetsFlutterBinding.ensureInitialized();
        }

        if (appRunner != null) {
          ApmNavigatorObserver singleInstance = getApmNavigatorObserver();
          final Widget rootWidget = await appRunner(singleInstance);
          runApp(rootWidget);
        }
        try {
          final String? nativeSdkVersion =
              await ApmMethodChannel.getNativeSdkVersion();
          if (nativeSdkVersion != null) {
            if (Platform.isAndroid) {
              printLog('SDK检查：当前Android APM SDK版本为 $nativeSdkVersion');
              printLog(
                  '提示：Android APM SDK 需在v1.9.3及以上版本才能支持Flutter监测 请自行检查 ！！！！！');
            }
            if (Platform.isIOS) {
              printLog('SDK检查：当前iOS APM SDK版本为 $nativeSdkVersion');
              printLog('提示：iOS APM SDK 需在v1.8.4及以上版本才能支持Flutter监测 请自行检查 ！！！！！');
            }
            if (Platform.operatingSystem == 'ohos') {
                printLog('SDK检查：当前HarmonyOS APM SDK版本为 $nativeSdkVersion');
                printLog('提示：HarmonyOS APM SDK 需在v1.3.0及以上版本才能支持Flutter监测 请自行检查 ！！！！！');
            }
          }
        } catch (e) {}

        bool waitResult = await waitNativeSdkInited();
        if (waitResult) {
          callInitOptios();
        } else {
          printLog('=======================================');
          printLog('===== 等待接收APM Native SDK 初始化结束状态 =====');
          printLog(
              '===== 如等待超过5s 可参考【SDK常见集成问题】https://developer.umeng.com/docs/193624/detail/2536504 =====');
          printLog('=======================================');
          Timer.periodic(Duration(milliseconds: 1000), (Timer t) async {
            bool inited = await waitNativeSdkInited();
            if (inited) {
              printLog('=======================================');
              printLog('===== 成功接收APM Native SDK 初始化状态 =====');
              printLog('=======================================');
              callInitOptios();
              t.cancel();
            }
          });
        }
      });
    }, (exception, stack) {
      if (exception is ApmFlutterError) {
        final Map<String, dynamic> errorDetail = exception.errorDetail;
        ExceptionTrace.handleApmSdkException(
            errorDetail['exception'], errorDetail['stackTrace'] ?? '');
      } else {
        ExceptionTrace.zonedGuardedErrorHandler(
            exception: exception, stack: stack);
      }
      if (onError != null) {
        onError!(exception, stack);
      }
    });

    _umengApmInited = true;
  }

  ApmNavigatorObserver getApmNavigatorObserver() {
    return ApmNavigatorObserver.singleInstance;
  }

  bool validateArguments() {
    if (name.isNotEmpty) {
      setStoreProperty(name: 'name', value: name);
    } else {
      errorLog('name 应为非空值');
      return false;
    }
    // 设置应用版本
    if (bver.isNotEmpty) {
      if (env != null) {
        String envStr = env.toString().split('.').last.toLowerCase();
        setStoreMultiProperty([
          {
            "name": 'bver',
            "value": '${bver}_$envStr',
          },
          {"name": 'env', "value": envStr}
        ]);
      } else {
        setStoreProperty(name: 'bver', value: bver);
      }
    } else {
      errorLog('bver 应为非空值');
      return false;
    }

    // 设置工程类型
    if (projectType is int && (projectType == 0 || projectType == 1)) {
      setStoreProperty(name: 'projectType', value: projectType);
    }

    // 设置flutter sdk版本
    if (flutterVersion is String && flutterVersion!.isNotEmpty) {
      setStoreProperty(name: 'flutterVersion', value: flutterVersion);
    }

    // 设置flutter 引擎版本
    if (engineVersion is String && engineVersion!.isNotEmpty) {
      setStoreProperty(name: 'engineVersion', value: engineVersion);
    }

    // 设置异常摘要过滤规则
    if (errorFilter != null) {
      if (errorFilter is Map) {
        final String? mode = errorFilter![KEY_MODE];
        final dynamic rules = errorFilter![KEY_RULES];
        if (!(mode is String) || (mode != 'ignore' && mode != 'match')) {
          errorLog('errorFilter.mode 枚举值应为ignore或match');
          return false;
        }
        if (!(rules is List)) {
          errorLog('errorFilter.rules 值应为List类型');
          return false;
        }
        // 保存异常摘要过滤规则
        setStoreProperty(name: 'errorFilter', value: errorFilter);
      } else {
        warnLog('errorFilter 应为Map类型');
      }
    }
    // 保存APM SDK版本
    setStoreProperty(name: 'sdkVersion', value: sdkVersion);

    return true;
  }
}
