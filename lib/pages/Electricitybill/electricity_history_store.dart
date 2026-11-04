import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';

/// 已绑定宿舍账户的本地存储。
///
/// 账户名/余额不属于机密，放 [SharedPreferences]；token 仍然只走
/// `CredentialStore`，这里不碰。
class ElectricityHistoryStore {
  static const String accountsKey = 'electricity.history.accounts';
  static const String selectedKey = 'electricity.history.selected';

  Future<List<ElectricityAccount>> loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    return decodeAccounts(prefs.getString(accountsKey));
  }

  Future<String?> loadSelectedId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(selectedKey);
    return (value == null || value.trim().isEmpty) ? null : value;
  }

  Future<void> saveAccounts(List<ElectricityAccount> accounts) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(accountsKey, encodeAccounts(accounts));
  }

  Future<void> selectAccount(String acguid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(selectedKey, acguid);
  }

  /// 绑定账户：同 `acguid` 覆盖，新账户插到最前面，并选中它。
  Future<List<ElectricityAccount>> upsertAccount(
    ElectricityAccount account,
  ) async {
    final accounts = await loadAccounts();
    final next = upsertAccountInList(accounts, account);
    await saveAccounts(next);
    await selectAccount(account.acguid);
    return next;
  }

  /// 解绑账户；若删掉的是当前选中项，自动回退到列表首个。
  Future<List<ElectricityAccount>> removeAccount(String acguid) async {
    final accounts = await loadAccounts();
    final next = removeAccountFromList(accounts, acguid);
    await saveAccounts(next);

    final resolved = resolveSelectedId(next, await loadSelectedId());
    if (resolved == null) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(selectedKey);
    } else {
      await selectAccount(resolved);
    }
    return next;
  }

  // ---------------------------------------------------------------------------
  // 纯函数部分（单测直接调这些）
  // ---------------------------------------------------------------------------

  static String encodeAccounts(List<ElectricityAccount> accounts) {
    return jsonEncode(accounts.map((account) => account.toJson()).toList());
  }

  static List<ElectricityAccount> decodeAccounts(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];
      final accounts = <ElectricityAccount>[];
      for (final item in decoded) {
        if (item is! Map) continue;
        final account = ElectricityAccount.fromJson(
          Map<String, dynamic>.from(item),
        );
        if (account.isValid) accounts.add(account);
      }
      return accounts;
    } catch (_) {
      return const [];
    }
  }

  static List<ElectricityAccount> upsertAccountInList(
    List<ElectricityAccount> accounts,
    ElectricityAccount account,
  ) {
    if (!account.isValid) return List<ElectricityAccount>.from(accounts);
    final index = accounts.indexWhere(
      (item) => item.acguid == account.acguid,
    );
    if (index < 0) return [account, ...accounts];
    final next = List<ElectricityAccount>.from(accounts);
    next[index] = account;
    return next;
  }

  static List<ElectricityAccount> removeAccountFromList(
    List<ElectricityAccount> accounts,
    String acguid,
  ) {
    return accounts
        .where((account) => account.acguid != acguid)
        .toList(growable: false);
  }

  /// 选中的账户被解绑后回退到列表首个；列表为空返回 `null`。
  static String? resolveSelectedId(
    List<ElectricityAccount> accounts,
    String? selectedId,
  ) {
    if (accounts.isEmpty) return null;
    if (selectedId != null &&
        accounts.any((account) => account.acguid == selectedId)) {
      return selectedId;
    }
    return accounts.first.acguid;
  }
}
