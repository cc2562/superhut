import 'package:get/get.dart';

class FunctionHotWaterState {
  // 设备列表
  RxList deviceList = [].obs;
  // 选中的设备值
  RxInt choiceDevice = (-1).obs;
  // 洗澡按钮状态
  RxBool waterStatus = false.obs;
  // 余额
  RxString balance = "null".obs;
  // 加载状态
  RxBool isLoading = false.obs;
  // 设备检查状态（是否完成检查未关闭设备）
  RxBool deviceCheckComplete = false.obs;

  FunctionHotWaterState();
}
