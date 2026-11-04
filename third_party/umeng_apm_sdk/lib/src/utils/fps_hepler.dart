import 'dart:async';

import 'package:umeng_apm_sdk/src/store/global.dart';
import 'package:umeng_apm_sdk/src/core/apm_shared.dart';
import 'package:umeng_apm_sdk/src/utils/fps_calculate.dart';

class ApmFpsHelper {
  /// 路由
  int? pageHashCode;

  bool isFirstPage;

  Function callback;

  /// 指示是否正在追踪
  bool _tracing = false;

  /// 计数器
  int _counter = 0;

  /// 定时器
  Timer? _timer;

  // 页面访问下最大采集时间周期 默认30s
  int _maxTrackingTimerPeriodic = 30;

  // 采集帧总数
  int _recordFrameCount = 50;

  // ui绘制计数器
  int uiPaintCount = 0;

  // 最近一次记录ui绘制总数
  int _lastRecordUiPaintCount = 0;

  List<String> _recordFps = [];

  /// 平均计算初始化帧率
  double _computeInitFpsAvg = 0;

  /// 平均计算滚动帧率
  double _computeScrollFpsAvg = 0;

  /// 平均计算其他状态下帧率
  double _computeOtherFpsAvg = 0;

  // 应用状态
  int _appStatus = 0;

  bool _inited = false;

  ApmFpsHelper(this.pageHashCode, this.isFirstPage, this.callback);

  // 启动定时器
  void _startTimer() {
    const oneSec = const Duration(seconds: 1);
    _timer = Timer.periodic(
      oneSec,
      (Timer timer) {
        if (_counter == _maxTrackingTimerPeriodic) {
          stop();
        } else {
          _counter++;
          if (uiPaintCount != _lastRecordUiPaintCount) {
            _lastRecordUiPaintCount = uiPaintCount;
            _recordFpsToList([1, 2]);
          }
        }
      },
    );
  }

  // 停止定时器
  void _stopTimer() {
    _timer?.cancel();
    _counter = 0;
    uiPaintCount = 0;
    _lastRecordUiPaintCount = 0;
  }

  // 获取应用状态
  int _getAppStatus() {
    return GlobalStore.singleInstance.getStore[KEY_APP_STATUS];
  }

  void addRecordFps(int appStatus, double fps) {
    if (fps != 0.00) {
      // 帧率保留2位小数
      _recordFps.add('$appStatus-${fps.toStringAsFixed(2)}');
    }
  }

  // 将记录的帧率添加到列表中
  void _recordFpsToList(List<int> appStatus) {
    _appStatus = _getAppStatus();
    if (appStatus.contains(_appStatus)) {
      // 0 初始化 1 滚动 2其他
      if (_appStatus != 0 && !_inited) {
        // 统计初始化状态应用状态变更前帧率作为初始化帧率记录
        addRecordFps(0, _computeInitFpsAvg);
        _inited = true;
      }
      if (_appStatus == 1) {
        addRecordFps(_appStatus, _computeScrollFpsAvg);
        _computeScrollFpsAvg = 0.0;
      }
      if (_appStatus == 2) {
        addRecordFps(_appStatus, _computeOtherFpsAvg);
        _computeOtherFpsAvg = 0.0;
      }
    }
  }

  // 注册回调函数
  void _registerCallBack(fps, dropCount) {
    _appStatus = _getAppStatus();
    switch (_appStatus) {
      // 0 初始化帧率
      case 0:
        _computeInitFpsAvg =
            _computeInitFpsAvg == 0 ? fps : (fps + _computeInitFpsAvg) / 2;
        break;
      // 1 滚动帧率
      case 1:
        _computeScrollFpsAvg =
            _computeScrollFpsAvg == 0 ? fps : (fps + _computeScrollFpsAvg) / 2;
        break;
      // // 2 其他操作下帧率
      case 2:
        _computeOtherFpsAvg =
            _computeOtherFpsAvg == 0 ? fps : (fps + _computeOtherFpsAvg) / 2;
        break;
      default:
    }

    uiPaintCount++;
  }

  // 注册fps定时函数
  _registerFpsTimings() {
    Fps.instance.registerCallBack(_registerCallBack);
  }

  // 启动帧率追踪
  void start() {
    if (_tracing) {
      return;
    }
    _registerFpsTimings();
    _startTimer();
    _tracing = true;
  }

  // 停止帧率追踪
  void stop() {
    if (!_tracing) {
      return null;
    }
    _tracing = false;
    _inited = false;
    _stopTimer();
    Fps.instance.unregisterCallBack(_registerCallBack);

    final List<String> frames = _recordFps.sublist(
        0,
        _recordFps.length >= _recordFrameCount
            ? _recordFrameCount
            : _recordFps.length);
    _recordFps.clear();
    // 跳转或应用后台状态下日志上报

    callback(pageHashCode, isFirstPage, frames);
  }
}
