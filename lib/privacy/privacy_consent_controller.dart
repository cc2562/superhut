import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../agreement/agreement_controller.dart';

/// 行为分析（Microsoft Clarity）的单独同意状态。
///
/// 合规要点：协议同意与行为分析同意是**两件事**。
/// * 只有「已同意当前版本协议」且「单独勾选了行为分析」时才允许采集；
/// * 用户可以随时在「隐私设置」里关闭，关闭后立即停止后续采集；
/// * 撤回不影响此前已经完成的处理，历史数据的删除需要单独申请。
///
/// 状态落在 SharedPreferences：它只是「开关」，本身不含个人信息，
/// 放在安全存储里反而会让换机后无法读到、导致误采集。
class PrivacyConsentController extends GetxController {
  PrivacyConsentController({AgreementController? agreement})
    : _agreement = agreement;

  /// 协议同意状态的来源；为 `null` 时从 GetX 容器里取。
  ///
  /// 允许注入是为了单元测试可以脱离 GetX 容器构造本控制器。
  AgreementController? _agreement;

  AgreementController? get _agreementController {
    if (_agreement != null) return _agreement;
    if (Get.isRegistered<AgreementController>()) {
      _agreement = Get.find<AgreementController>();
    }
    return _agreement;
  }

  /// 是否单独勾选了行为分析。
  final RxBool _analyticsConsent = false.obs;

  bool get analyticsConsent => _analyticsConsent.value;

  /// 是否允许采集：协议已同意 **且** 单独勾选了行为分析。
  bool get analyticsAllowed =>
      analyticsConsent && (_agreementController?.accepted ?? false);

  /// 最近一次变更同意状态的时间（ISO8601），用于说明「何时撤回」。
  final RxString _updatedAt = ''.obs;

  String get updatedAt => _updatedAt.value;

  /// 读取本地状态；异常一律回落为「未同意」，宁可少采集也不误采集。
  Future<void> load() async {
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      _analyticsConsent.value = prefs.getBool(consentKey) ?? false;
      _updatedAt.value = prefs.getString(updatedAtKey) ?? '';
    } catch (error) {
      debugPrint('读取行为分析同意状态失败：$error');
      _analyticsConsent.value = false;
      _updatedAt.value = '';
    }
  }

  /// 写入同意状态。
  ///
  /// 先改内存让 UI 立刻响应，再异步落盘；落盘失败只记一行日志，
  /// 不影响本次会话里已经生效的设置。
  Future<void> setAnalyticsConsent(bool value) async {
    _analyticsConsent.value = value;
    final String now = DateTime.now().toIso8601String();
    _updatedAt.value = now;
    try {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setBool(consentKey, value);
      await prefs.setString(updatedAtKey, now);
    } catch (error) {
      debugPrint('保存行为分析同意状态失败：$error');
    }
  }

  static const String consentKey = 'privacy.analyticsConsent';
  static const String updatedAtKey = 'privacy.analyticsConsentAt';
}
