import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/utils/app_update_service.dart';

AppUpdateInfo _info({
  bool hasUpdate = true,
  String latestVersion = '2.0.0',
  bool isForced = false,
}) {
  return AppUpdateInfo(
    hasUpdate: hasUpdate,
    latestVersion: latestVersion,
    description: '修复若干问题',
    isForced: isForced,
    downloadUrl: 'https://example.com/app.apk',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  group('shouldNotify', () {
    test('没有新版本时不提醒', () {
      expect(
        AppUpdateService.shouldNotify(_info(hasUpdate: false), null),
        isFalse,
      );
    });

    test('没有忽略记录时提醒', () {
      expect(AppUpdateService.shouldNotify(_info(), null), isTrue);
    });

    test('忽略的就是当前最新版本时不再提醒', () {
      expect(AppUpdateService.shouldNotify(_info(), '2.0.0'), isFalse);
    });

    test('忽略的是更旧的版本时仍然提醒', () {
      expect(AppUpdateService.shouldNotify(_info(), '1.9.0'), isTrue);
    });

    test('强制更新忽略标记无效，始终提醒', () {
      expect(
        AppUpdateService.shouldNotify(_info(isForced: true), '2.0.0'),
        isTrue,
      );
    });
  });

  group('忽略标记的读写', () {
    test('默认没有忽略记录', () async {
      expect(await AppUpdateService.skippedVersion(), isNull);
    });

    test('写入后能读回，空值不写入', () async {
      await AppUpdateService.skipVersion('  ');
      expect(await AppUpdateService.skippedVersion(), isNull);

      await AppUpdateService.skipVersion('2.0.0');
      expect(await AppUpdateService.skippedVersion(), '2.0.0');
    });
  });

  group('AppUpdateInfo.fromJson', () {
    test('解析标准字段', () {
      final AppUpdateInfo info = AppUpdateInfo.fromJson(<String, dynamic>{
        'is_latest': false,
        'latest_version': '2.1.0',
        'description': '新增功能',
        'is_forced': true,
        'download_url': 'https://example.com/app.apk',
      });

      expect(info.hasUpdate, isTrue);
      expect(info.latestVersion, '2.1.0');
      expect(info.description, '新增功能');
      expect(info.isForced, isTrue);
      expect(info.downloadUrl, 'https://example.com/app.apk');
    });

    test('兼容字符串/数字形式的布尔值', () {
      final AppUpdateInfo info = AppUpdateInfo.fromJson(<String, dynamic>{
        'is_latest': 0,
        'latest_version': '2.2.0',
        'is_forced': '1',
      });

      expect(info.hasUpdate, isTrue);
      expect(info.isForced, isTrue);
      expect(info.description, '');
      expect(info.downloadUrl, '');
    });

    test('is_latest 为真时没有更新', () {
      final AppUpdateInfo info = AppUpdateInfo.fromJson(<String, dynamic>{
        'is_latest': true,
        'latest_version': '1.5.1',
      });

      expect(info.hasUpdate, isFalse);
    });
  });
}
