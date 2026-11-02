import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/hut_cas_login_page.dart';
import 'package:superhut/security/credential_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearCachedSession removes the academic-system session only', () async {
    // 凭据都在系统安全存储里，清除教务会话不应波及 HUT 短信会话。
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'token': 'old-account-token',
      'my_client_ticket': 'old-account-ticket',
      'hutToken': 'new-sms-session',
    });
    CredentialStore.instance.clearCacheForTest();

    await HutCasTokenRetriever.clearCachedSession();

    expect(await CredentialStore.instance.read('token'), isNull);
    expect(await CredentialStore.instance.read('my_client_ticket'), isNull);
    expect(await CredentialStore.instance.read('hutToken'), 'new-sms-session');
  });
}
