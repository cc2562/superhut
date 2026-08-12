import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/hutpages/hutmainSate.dart';

import '../../login/hut/view.dart';
import '../../utils/hut_user_api.dart';

class HutMainLogic extends GetxController {
  final HutMainState state = HutMainState();
  final api = HutUserApi();
  List funList = [];

  Future<List> getFunList() async {
    if (state.isLoad.value) {
      return funList;
    }
    try {
      funList = await api.getFunctionList();
    } on HutAuthenticationRequiredException {
      // getFunctionList explicitly reports an invalid session. Re-check the
      // persisted login flag now so this page opens the login flow immediately
      // instead of treating authentication failure as a valid empty list.
      await checkLogin();
      return const [];
    }
    state.isLoad.value = true;
    update();
    return funList;
  }

  /// 判断是否需要跳转登录
  Future<void> checkLogin() async {
    final prefs = await SharedPreferences.getInstance();
    bool hsa = prefs.getBool('hutIsLogin') ?? false;

    if (hsa == false) {
      Future.delayed(const Duration(milliseconds: 100), () {
        Get.off(HutLoginPage());
      });
    }
  }
}
