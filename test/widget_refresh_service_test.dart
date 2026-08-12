import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/widget_refresh_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'com.superhut.rice.superhut/coursetable_widget',
  );

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('missing widget plugin does not fail the course refresh', () async {
    expect(await WidgetRefreshService.refreshCourseTableWidget(), isFalse);
  });

  test('native widget refresh result is forwarded', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          expect(call.method, 'refreshCourseTableWidget');
          return true;
        });

    expect(await WidgetRefreshService.refreshCourseTableWidget(), isTrue);
  });
}
