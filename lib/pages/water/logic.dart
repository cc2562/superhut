import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../login/hut/view.dart';
import '../../utils/hut_user_api.dart';
import 'state.dart';

class FunctionHotWaterLogic extends GetxController {
  final FunctionHotWaterState state = FunctionHotWaterState();
  final hutUserApi = HutUserApi();
  
  // Local storage for user information
  final Map<String, dynamic> _hutUserInfo = {
    "hutIsLogin": false,
    "username": "",
    "password": "",
    "token":"",
    "deviceId":""
  };
  
  // Local method to access user info
  Map<String, dynamic> get hutUserInfo => _hutUserInfo;
  
  // Local method to update user info
  void setHutUserInfo(String key, dynamic value) {
    _hutUserInfo[key] = value;
    // Persist to storage if needed
    saveUserInfo();
    update();
  }
  
  // Method to save user info to storage
  Future<void> saveUserInfo() async {
    // Excluding password from persistent storage for security
    Map<String, dynamic> storageInfo = Map.from(_hutUserInfo);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('hutUserInfo',storageInfo.toString());
    // Store the data securely
    // This is a simplified implementation
  }
  
  // Method to load user info from storage
  Future<void> loadUserInfo() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _hutUserInfo["token"] = prefs.getString('hutToken')??"";
      _hutUserInfo["deviceId"] = prefs.getString('deviceId')??"";
      _hutUserInfo["username"] = prefs.getString('hutUsername')??"";
      _hutUserInfo["password"] = prefs.getString('hutPassword')??"";
      _hutUserInfo["hutIsLogin"] = prefs.getBool('hutIsLogin')??false;
    //  print(_hutUserInfo["username"]);
    } catch (e) {
      // Handle errors
      print("Error loading user info: $e");
    }
  }

  @override
  void onInit() {
    super.onInit();
    loadUserInfo();
    checkLogin();
    // 初始化时设置设备检查状态为未完成
    state.deviceCheckComplete.value = false;
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    _hutUserInfo["token"] = prefs.getString('hutToken')??"";
    _hutUserInfo["deviceId"] = prefs.getString('deviceId')??"";
    _hutUserInfo["username"] = prefs.getString('hutUsername')??"";
    _hutUserInfo["password"] = prefs.getString('hutPassword')??"";
    _hutUserInfo["hutIsLogin"] = prefs.getBool('hutIsLogin')??false;

    if (_hutUserInfo["hutIsLogin"]==false) {

     Future.delayed(const Duration(milliseconds: 100), () {
       Get.off(HutLoginPage(),);
     });
    } else {
      //setHutUserInfo("hutIsLogin", true);
      getDeviceList();
    }
  }

  /// 获取喝水设备列表
  ///
  /// 此函数负责从服务器获取用户的热水设备列表，并处理登录状态和设备信息更新。
  /// 如果设备列表获取失败（code为500），则尝试重新登录并重新获取设备信息。
  /// 若登录失败或设备列表为空，则重置相关状态并检查登录状态。
  ///
  /// 返回: 无返回值，通过状态管理更新UI。
  Future<void> getDeviceList() async {
  //  bool isV =await hutUserApi.checkTokenValidity();
   // await hutUserApi.userLogin(username: _hutUserInfo["username"], password: _hutUserInfo["password"]);
   // print("LLLLLLLLLLLLLLLLLLLLLLLLLL:$isV");
    // 尝试首次获取设备列表
    await hutUserApi.getHotWaterDevice().then((value) async {
     // print(value);

      if (value["code"] == 500) {
        // 处理登录失效情况：尝试自动重新登录
        if (_hutUserInfo["hutIsLogin"]) {
          bool isLogin = await hutUserApi.userLogin(username: _hutUserInfo["username"], password: _hutUserInfo["password"]);
          if (isLogin) {
            // 重新登录成功后再次获取设备列表
            await hutUserApi.getHotWaterDevice().then((value) async {
              if (value["code"] != 500) {
                // 更新设备列表及关联状态
                state.deviceList.value = value["data"];
                setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
                await checkHotWaterDevice();
                await getBalance();
                update();
              }
            });
            return;
          }
        }
        // 登录失败处理：重置登录状态并清除设备信息
        setHutUserInfo("hutIsLogin", false);
        state.deviceList.clear();
        setChoiceDevice(-1);
        state.waterStatus.value = false;
        update();
        checkLogin();
      } else {
        // 正常获取到设备列表时更新状态
        state.deviceList.value = value["data"];
        setChoiceDevice(state.deviceList.isNotEmpty ? 0 : -1);
        await checkHotWaterDevice();
        await getBalance();
        update();
      }
    });
  }

  /// 获取余额
  Future<void> getBalance() async {
    await hutUserApi.getCardBalance().then((value) {
      state.balance.value = value;
      update();
    });
  }

  /// 检查是否有未关闭的设备
  Future<void> checkHotWaterDevice() async {
    // 开始检查前设置检查状态为未完成
    state.deviceCheckComplete.value = false;
    update();
    
    await hutUserApi.checkHotWaterDevice().then((value) {
      print(value);
      if (value.isNotEmpty) {
        state.waterStatus.value = true;
        state.choiceDevice.value = state.deviceList
            .indexWhere((element) => element["poscode"] == value.first);
        Get.snackbar(
          '提示',
          '您有设备未关闭！',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        update();
      }
      
      // 设置检查状态为已完成
      state.deviceCheckComplete.value = true;
      update();
    }).catchError((error) {
      // 发生错误时也标记为已完成，避免用户无法使用功能
      state.deviceCheckComplete.value = true;
      update();
    });
  }

  /// 改变选中的设备值
  void setChoiceDevice(int device) {
    state.choiceDevice.value = device;
    update();
  }

  /// 开始洗澡
  Future<void> startWater() async {
    state.isLoading.value = true;
    update();
    
    hutUserApi
        .startHotWater(
            device: state.deviceList[state.choiceDevice.value]["poscode"])
        .then((value) {
      state.isLoading.value = false;
      if (value) {
        Get.snackbar(
          '提示',
          '开启设备成功！',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        state.waterStatus.value = true;
        update();
      } else {
        Get.snackbar(
          '提示',
          '开启设备失败',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
      }
      update();
    }).catchError((error) {
      state.isLoading.value = false;
      Get.snackbar(
        '提示',
        '发生错误，请稍后再试',
        backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
        margin: EdgeInsets.only(
          top: 30,
          left: 50,
          right: 50,
        ),
      );
      update();
    });
  }

  /// 结束洗澡
  void endWater() {
    state.isLoading.value = true;
    update();
    
    hutUserApi
        .stopHotWater(
            device: state.deviceList[state.choiceDevice.value]["poscode"])
        .then((value) {
      state.isLoading.value = false;
      if (value) {
        Get.snackbar(
          '提示',
          '关闭设备成功！',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        state.waterStatus.value = false;
        update();
      } else {
        Get.snackbar(
          '提示',
          '关闭设备失败',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
      }
      update();
    }).catchError((error) {
      state.isLoading.value = false;
      Get.snackbar(
        '提示',
        '发生错误，请稍后再试',
        backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
        margin: EdgeInsets.only(
          top: 30,
          left: 50,
          right: 50,
        ),
      );
      update();
    });
  }
  
  /// 添加热水设备
  /// [deviceCode] 6位设备号
  Future<bool> addDevice(String deviceCode) async {
    if (deviceCode.length != 6 || int.tryParse(deviceCode) == null) {
      Get.snackbar(
        '提示',
        '设备号必须是6位数字',
        backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
        margin: EdgeInsets.only(
          top: 30,
          left: 50,
          right: 50,
        ),
      );
      return false;
    }
    
    return await hutUserApi.addWaterDevice(deviceCode).then((value) {
      if (value['result']) {
        Get.snackbar(
          '提示',
          '添加设备成功！',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        getDeviceList(); // 刷新设备列表
        return true;
      } else {
        Get.snackbar(
          '提示',
          '添加设备失败：${value['msg']}',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        return false;
      }
    });
  }
  
  /// 删除热水设备
  /// [deviceCode] 设备号
  Future<bool> deleteDevice(String deviceCode) async {
    return await hutUserApi.delWaterDevice(deviceCode).then((value) {
      if(value['result']){
  //      print(value);
     //   print("DEEEEEEEEEEEEE");
        Get.snackbar(
          '提示',
          '删除设备成功！',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        getDeviceList();

        return true;
      }else{
        Get.snackbar(
          '提示',
          '删除设备失败：${value['msg']}',
          backgroundColor: Theme.of(Get.context!).colorScheme.primaryContainer,
          margin: EdgeInsets.only(
            top: 30,
            left: 50,
            right: 50,
          ),
        );
        return false;
      }

    });
  }
}
