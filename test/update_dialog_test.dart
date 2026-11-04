import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/update/update_dialog.dart';
import 'package:superhut/utils/app_update_service.dart';

AppUpdateInfo _info({bool isForced = false}) {
  return AppUpdateInfo(
    hasUpdate: true,
    latestVersion: '2.0.0',
    description: '修复若干问题',
    isForced: isForced,
    downloadUrl: 'https://example.com/app.apk',
  );
}

Widget _host(AppUpdateInfo info) {
  return MaterialApp(
    home: Builder(
      builder: (BuildContext context) => Scaffold(
        body: Center(
          child: TextButton(
            onPressed: () => showAppUpdateDialog(context: context, info: info),
            child: const Text('打开'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  testWidgets('普通更新提供三个按钮，点「本版本不再提醒」会记住该版本', (tester) async {
    await tester.pumpWidget(_host(_info()));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('新版本可用：2.0.0'), findsOneWidget);
    expect(find.text('稍后更新'), findsOneWidget);
    expect(find.text('立即更新'), findsOneWidget);
    expect(find.text('本版本不再提醒'), findsOneWidget);

    await tester.tap(find.text('本版本不再提醒'));
    await tester.pumpAndSettle();

    expect(find.text('新版本可用：2.0.0'), findsNothing);
    expect(await AppUpdateService.skippedVersion(), '2.0.0');
    expect(find.textContaining('已忽略 2.0.0'), findsOneWidget);
    // 记住之后，下一次自动检查就不该再提醒这个版本。
    expect(AppUpdateService.shouldNotify(_info(), '2.0.0'), isFalse);
  });

  testWidgets('强制更新不提供忽略与稍后', (tester) async {
    await tester.pumpWidget(_host(_info(isForced: true)));
    await tester.tap(find.text('打开'));
    await tester.pumpAndSettle();

    expect(find.text('新版本可用：2.0.0'), findsOneWidget);
    expect(find.text('本版本不再提醒'), findsNothing);
    expect(find.text('稍后更新'), findsNothing);
    expect(find.text('立即更新'), findsOneWidget);
  });
}
