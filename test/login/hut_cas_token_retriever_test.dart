import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/login/hut_cas_login_page.dart';

void main() {
  test('clearCachedSession removes the academic-system session only', () async {
    SharedPreferences.setMockInitialValues({
      'token': 'old-account-token',
      'my_client_ticket': 'old-account-ticket',
      'hutToken': 'new-sms-session',
    });

    await HutCasTokenRetriever.clearCachedSession();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('token'), isNull);
    expect(prefs.getString('my_client_ticket'), isNull);
    expect(prefs.getString('hutToken'), 'new-sms-session');
  });
}
