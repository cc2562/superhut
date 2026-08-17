import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/login/hut_login_system.dart';

void main() {
  test('empty CAS credentials mean authentication is required', () {
    expect(
      isHutCasAuthenticationPage(
        'https://mycas.hut.edu.cn/cas/login?idToken=&service='
        'https%3A%2F%2Fjwxtsj.hut.edu.cn%2Fnjwhd%2FloginSso&token=',
      ),
      isTrue,
    );
  });

  test(
    'a CAS login page that finishes loading still requires authentication',
    () {
      expect(
        isHutCasAuthenticationPage(
          'https://mycas.hut.edu.cn/cas/login?idToken=valid&service='
          'https%3A%2F%2Fjwxtsj.hut.edu.cn%2Fnjwhd%2FloginSso&token=valid',
        ),
        isTrue,
      );
    },
  );

  test('academic system callback is not a CAS login form', () {
    expect(
      isHutCasAuthenticationPage(
        'https://jwxtsj.hut.edu.cn/njwhd/loginSso?token=valid',
      ),
      isFalse,
    );
  });
}
