import 'dart:collection';
import 'dart:ui';
import 'package:umeng_apm_sdk/src/core/apm_method_channel.dart';
import 'package:flutter/scheduler.dart';

class FpsPlugin {
  static Future<double> get getRefreshRate async {
    final double fpsHz = await ApmMethodChannel.getNativeFPS() ?? 60.0;
    return fpsHz;
  }
}

typedef FpsCallback = void Function(double fps, double dropCount);

class Fps {
  static Fps get instance {
    if (_instance == null) {
      _instance = Fps._();
    }
    return _instance!;
  }

  static Fps? _instance;

  static const _maxFrames = 120;
  final lastFrames = ListQueue<FrameTiming>(_maxFrames);
  TimingsCallback? _timingsCallback;
  List<FpsCallback> _callBackList = [];

  Fps._() {
    _timingsCallback = (List<FrameTiming> timings) {
      //异步计算fps
      _computeFps(timings);
    };
    SchedulerBinding.instance!.addTimingsCallback(_timingsCallback!);
  }

  registerCallBack(FpsCallback back) {
    _callBackList.add(back);
  }

  unregisterCallBack(FpsCallback back) {
    _callBackList.remove(back);
  }

  cancel() {
    if (_timingsCallback == null) {
      return;
    }
    SchedulerBinding.instance!.removeTimingsCallback(_timingsCallback!);
  }

  double? _fpsHz;

  Duration? _frameInterval;

  Future<void> _computeFps(List<FrameTiming> timings) async {
    for (FrameTiming timing in timings) {
      lastFrames.addFirst(timing);
    }

    while (lastFrames.length > _maxFrames) {
      lastFrames.removeLast();
    }

    var lastFramesSet = <FrameTiming>[];

    if (_fpsHz == null) {
      _fpsHz = await FpsPlugin.getRefreshRate;
    }

    if (_frameInterval == null) {
      _frameInterval =
          Duration(microseconds: Duration.microsecondsPerSecond ~/ _fpsHz!);
    }

    for (FrameTiming timing in lastFrames) {
      if (lastFramesSet.isEmpty) {
        lastFramesSet.add(timing);
      } else {
        var lastStart =
            lastFramesSet.last.timestampInMicroseconds(FramePhase.buildStart);
        var interval =
            lastStart - timing.timestampInMicroseconds(FramePhase.rasterFinish);
        if (interval > (_frameInterval!.inMicroseconds * 2)) {
          break;
        }
        lastFramesSet.add(timing);
      }
    }

    var drawFramesCount = lastFramesSet.length;

    int? droppedCount = 0; //丢帧数

    // 计算总的帧数
    var costCount = lastFramesSet.map((frame) {
      int droppedCount =
          (frame.totalSpan.inMicroseconds ~/ _frameInterval!.inMicroseconds);
      return droppedCount + 1;
    }).fold(0, (dynamic a, b) => a + b);

    //丢帧数=总帧数-绘制帧数
    droppedCount = costCount - drawFramesCount;
    double fps = drawFramesCount * _fpsHz! / costCount;

    lastFrames.clear();
    _callBackList.forEach((callBack) {
      callBack(fps, droppedCount!.toDouble());
    });
  }
}
