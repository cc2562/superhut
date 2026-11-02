import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'agreement_documents.dart';

/// 协议同意状态。
///
/// 只做一件事：把「用户同意的协议版本」存进 SharedPreferences，并与
/// [AgreementDocuments.version] 比对。版本变了就自动回到「未同意」，
/// 从而实现「协议改版后重新征求同意」。
///
/// 注意：不能复用 `isFirstOpen`。那个键的语义是「尚未完成登录」
/// （登录成功置 false、退出登录置回 true），与同意状态无关。
class AgreementController extends GetxController {
  /// 已同意的协议版本号；空串表示从未同意过。
  final RxString _acceptedVersion = ''.obs;

  String get acceptedVersion => _acceptedVersion.value;

  /// 是否已同意当前版本的协议。
  bool get accepted => _acceptedVersion.value == AgreementDocuments.version;

  /// 从本地读取同意状态；任何异常都回落为「未同意」，让用户重新确认一次。
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _acceptedVersion.value = prefs.getString(_storageKey) ?? '';
    } catch (error) {
      debugPrint('读取协议同意状态失败：$error');
      _acceptedVersion.value = '';
    }
  }

  /// 记录同意（先改内存让 UI 立刻可进入，再异步落盘）。
  Future<void> accept() async {
    _acceptedVersion.value = AgreementDocuments.version;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, AgreementDocuments.version);
    } catch (error) {
      debugPrint('保存协议同意状态失败：$error');
    }
  }

  /// 撤销同意（目前没有入口，保留给将来的「撤回同意」设置项或调试使用）。
  Future<void> revoke() async {
    _acceptedVersion.value = '';
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (error) {
      debugPrint('清除协议同意状态失败：$error');
    }
  }

  static const String _storageKey = 'agreement.acceptedVersion';
}
