import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../theme/glass/glass_overlays.dart';
import '../../utils/app_update_service.dart';

/// 展示更新弹窗。
///
/// [allowSkip] 为 false 时（强制更新、或手动检查到强制更新）不提供「本版本不再提醒」，
/// 避免用户把必须升级的版本永久忽略掉。
Future<void> showAppUpdateDialog({
  required BuildContext context,
  required AppUpdateInfo info,
  bool allowSkip = true,
}) async {
  final bool canSkip = allowSkip && !info.isForced;
  final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(context);

  await showGlassDialog<void>(
    context: context,
    barrierDismissible: !info.isForced,
    title: Text('新版本可用：${info.latestVersion}'),
    content: Text(
      info.description.isEmpty ? '建议更新到最新版本以获得更好的体验。' : info.description,
    ),
    actions: <Widget>[
      if (canSkip)
        TextButton(
          onPressed: () async {
            await AppUpdateService.skipVersion(info.latestVersion);
            if (!context.mounted) return;
            Navigator.of(context).pop();
            messenger?.showSnackBar(
              SnackBar(content: Text('已忽略 ${info.latestVersion} 版本，可在「我的 - 检查更新」重新查看')),
            );
          },
          child: const Text('本版本不再提醒'),
        ),
      if (!info.isForced)
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('稍后更新'),
        ),
      TextButton(
        onPressed: () async {
          final Uri? uri = Uri.tryParse(info.downloadUrl);
          if (uri != null) {
            await launchUrl(uri);
          }
          // 强制更新必须升级，先退出当前版本，避免用户停留在旧版本继续使用。
          if (info.isForced) {
            SystemNavigator.pop();
          }
        },
        child: const Text('立即更新'),
      ),
    ],
  );
}
