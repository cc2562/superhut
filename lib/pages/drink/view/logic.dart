import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/drink/login/view.dart';

import '../api/drink_api.dart';
import 'state.dart';

class FunctionDrinkLogic extends GetxController {
  final FunctionDrinkState state = FunctionDrinkState();
  final drinkApi = DrinkApi();

  /// 状态轮询上限，避免异常情况下定时器长时间驻留
  static const Duration _pollingLimit = Duration(minutes: 30);

  bool _starting = false;
  bool _ending = false;
  bool _navigatingToLogin = false;
  int _pollingStartAt = 0;

  @override
  void onInit() {
    super.onInit();
    drinkApi.onSessionExpired = _handleSessionExpired;
    checkLogin();
    // 获取token
    drinkApi.getToken().then((value) {
      state.tokenController.text = value;
    });
  }

  @override
  void onClose() {
    // GetX 在 Get.delete 时调用 onClose，这里统一回收定时器与回调
    drinkApi.onSessionExpired = null;
    state.deviceStatusTimer?.cancel();
    state.deviceStatusTimer = null;
    state.tokenController.dispose();
    super.onClose();
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    final isLogin = prefs.getBool("hui798IsLogin") ?? false;
    if (!isLogin) {
      Get.off(DrinkLoginPage());
      return;
    }
    await getDeviceList();
  }

  /// 获取喝水设备列表
  Future<void> getDeviceList() async {
    final result = await drinkApi.deviceList();
    if (isClosed) return;

    if (!result.success) {
      if (result.isSessionExpired) {
        await _expireLogin();
        return;
      }
      _toast('获取设备失败', result.msg);
      return;
    }

    state.deviceList.value = result.data ?? [];
    setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
    update();
  }

  /// 收藏或取消收藏设备
  Future<bool> favoDevice(String id, bool isUnFavo) async {
    final result = await drinkApi.favoDevice(id: id, isUnFavo: isUnFavo);
    if (isClosed) return false;

    if (!result.success) {
      if (result.isSessionExpired) {
        await _expireLogin();
      } else if (result.msg.isNotEmpty) {
        Get.snackbar(
          '操作失败',
          result.msg,
          snackPosition: SnackPosition.BOTTOM,
          margin: const EdgeInsets.all(10),
          borderRadius: 10,
          duration: const Duration(seconds: 3),
        );
      }
      return false;
    }
    return true;
  }

  /// 扫码添加设备：先用二维码内容换取设备 ID，再收藏
  Future<bool> addDeviceByQr(String rawCode) async {
    var id = rawCode.contains("/") ? rawCode.split("/").last : rawCode;
    final resolved = await drinkApi.resolveQrDevice(id: id);
    if (isClosed) return false;

    if (resolved.success) {
      final deviceId = resolved.data ?? "";
      if (deviceId.isNotEmpty) {
        id = deviceId;
      }
    } else if (resolved.isSessionExpired) {
      await _expireLogin();
      return false;
    } else {
      // 解析失败时退回二维码末段，尽量保持原有的添加能力
      debugPrint("[drink] 二维码解析失败: ${resolved.msg}");
    }

    return favoDevice(id, false);
  }

  /// 格式化设备名称
  String formatDeviceName(String name) {
    if (name.contains("栋")) {
      return name.replaceAll("栋", "-");
    } else {
      return name;
    }
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    state.choiceDevice.value = device;
    update();
  }

  /// 开始喝水
  Future<void> startDrink(BuildContext context) async {
    if (_starting) return;

    final device = _currentDevice();
    if (device == null) return;

    final id = device["id"].toString();
    _starting = true;
    try {
      final statusResult = await drinkApi.deviceStatus(id: id);
      if (isClosed || !context.mounted) return;

      if (!statusResult.success) {
        if (statusResult.isSessionExpired) {
          await _expireLogin();
          return;
        }
        _showError(context, '开启失败', statusResult.msg);
        return;
      }

      final status = statusResult.data;
      if (status != null) {
        if (status.isOffline) {
          _showError(context, '设备离线', '设备当前不在线，请稍后再试');
          return;
        }
        if (status.isDisabled) {
          _showError(context, '设备禁用', '设备已被禁用，请联系管理员');
          return;
        }
        if (!status.isAvailable) {
          // 设备正在运行，同步为可结算状态，避免用户重复发起启动
          state.drinkStatus.value = true;
          update();
          _startStatusPolling(id);
          _showError(context, '设备使用中', '设备正在使用中，可点击结算结束本次使用');
          return;
        }
      }

      // 优先钱包支付（91），失败回退支付宝免密（21）
      var result = await drinkApi.startDrink(id: id, ptype: 91);
      if (isClosed) return;
      if (!result.success && !result.isSessionExpired) {
        result = await drinkApi.startDrink(id: id, ptype: 21);
        if (isClosed || !context.mounted) return;
      }

      if (!result.success) {
        if (result.isSessionExpired) {
          await _expireLogin();
          return;
        }
        if (!context.mounted) return;
        _showError(context, '开启失败', result.msg);
        return;
      }

      state.drinkStatus.value = true;
      update();
      _startStatusPolling(id);
    } finally {
      _starting = false;
    }
  }

  /// 结束喝水
  Future<void> endDrink(BuildContext context) async {
    if (_ending) return;

    final device = _currentDevice();
    if (device == null) return;

    _ending = true;
    try {
      final result = await drinkApi.endDrink(id: device["id"].toString());
      if (isClosed || !context.mounted) return;

      if (!result.success) {
        if (result.isSessionExpired) {
          await _expireLogin();
          return;
        }
        _showError(context, '结算失败', result.msg);
        return;
      }

      state.deviceStatusTimer?.cancel();
      state.deviceStatusTimer = null;
      state.drinkStatus.value = false;
      update();
    } finally {
      _ending = false;
    }
  }

  /// 删除相对应的device
  void removeDeviceByName(String name) {
    state.deviceList.removeWhere((element) => element["name"] == name);
    update();
  }

  /// 设置token
  void setToken(String token) {
    drinkApi.setToken(token: token).then((_) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool("hui798IsLogin", true);
      await getDeviceList();
      update();
    });
  }

  Map<String, dynamic>? _currentDevice() {
    final index = state.choiceDevice.value;
    if (index < 0 || index >= state.deviceList.length) return null;
    final device = state.deviceList[index];
    if (device is! Map) return null;
    return Map<String, dynamic>.from(device);
  }

  /// 轮询设备状态，设备自动停水后在前端收起「正在接水中」
  void _startStatusPolling(String id) {
    state.deviceStatusTimer?.cancel();
    _pollingStartAt = DateTime.now().millisecondsSinceEpoch;
    var availableCount = 0;

    state.deviceStatusTimer = Timer.periodic(const Duration(seconds: 1), (
      timer,
    ) async {
      if (isClosed ||
          DateTime.now().millisecondsSinceEpoch - _pollingStartAt >
              _pollingLimit.inMilliseconds) {
        timer.cancel();
        return;
      }

      final result = await drinkApi.deviceStatus(id: id);
      if (isClosed) {
        timer.cancel();
        return;
      }

      if (!result.success) {
        if (result.isSessionExpired) {
          timer.cancel();
          await _expireLogin();
        }
        return;
      }

      final status = result.data;
      if (status == null) return;

      if (status.isAvailable) {
        availableCount++;
        // 启动瞬间设备状态可能仍是空闲，连续确认后再收起
        if (availableCount > 3) {
          timer.cancel();
          state.deviceStatusTimer = null;
          state.drinkStatus.value = false;
          update();
        }
      } else {
        availableCount = 0;
      }
    });
  }

  void _handleSessionExpired() {
    _expireLogin();
  }

  /// 清除本地登录态并回到登录页
  Future<void> _expireLogin() async {
    if (_navigatingToLogin) return;
    _navigatingToLogin = true;

    await drinkApi.clearLoginState();

    state.deviceStatusTimer?.cancel();
    state.deviceStatusTimer = null;
    state.drinkStatus.value = false;
    state.deviceList.clear();
    state.choiceDevice.value = -1;
    if (!isClosed) update();

    Get.off(DrinkLoginPage());
    Future.delayed(const Duration(seconds: 1), () {
      _navigatingToLogin = false;
    });
  }

  /// 不依赖页面主题的轻量提示
  void _toast(String title, String message) {
    if (message.isEmpty) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
    );
  }

  void _showError(BuildContext context, String title, String message) {
    if (message.isEmpty) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Theme.of(context).colorScheme.errorContainer,
      colorText: Theme.of(context).colorScheme.onErrorContainer,
      duration: const Duration(seconds: 3),
      margin: const EdgeInsets.all(10),
      borderRadius: 10,
      icon: Icon(
        Icons.error,
        color: Theme.of(context).colorScheme.onErrorContainer,
      ),
    );
  }
}
