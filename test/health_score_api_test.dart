import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/health/health_score_api.dart';

const String _mainPage =
    '<form><input type="hidden" name="stuNo" value="MjAyMzAwMDE=">'
    '<input type="hidden" name="schoolid" value="100001"></form>';

void main() {
  group('CAS 入口', () {
    test('service 指向 tzcs 的 sso 入口，targetUrl 指向 sso/index.jsp', () {
      final service = buildHealthServiceUrl();
      final serviceUri = Uri.parse(service);
      expect(serviceUri.host, 'tzcs.hut.edu.cn');
      expect(serviceUri.path, kHealthSsoPath);
      expect(
        serviceUri.queryParameters['targetUrl'],
        '$kHealthBaseUrl$kHealthSsoIndexPath',
      );
    });

    test('CAS 登录地址带 idToken 与 token，service 单次解码可还原', () {
      final url = buildHealthCasLoginUrl(idToken: 'abc123');
      final uri = Uri.parse(url);
      expect(uri.host, 'mycas.hut.edu.cn');
      expect(uri.path, '/cas/login');
      expect(uri.queryParameters['idToken'], 'abc123');
      expect(uri.queryParameters['token'], 'abc123');
      expect(uri.queryParameters['service'], buildHealthServiceUrl());
    });

    test('门户服务地址可以覆盖默认 service', () {
      const custom = 'https://tzcs.hut.edu.cn/sso/login.jsp?targetUrl=x';
      final uri = Uri.parse(
        buildHealthCasLoginUrl(idToken: 't', serviceUrl: custom),
      );
      expect(uri.queryParameters['service'], custom);
    });
  });

  group('会话辅助', () {
    test('Cookie 头按名称排序', () {
      expect(
        buildHealthCookieHeader({'JSESSIONID': 'b', 'CASTGC': 'a'}),
        'CASTGC=a; JSESSIONID=b',
      );
      expect(buildHealthCookieHeader({}), '');
    });

    test('学号 base64 与抓包一致', () {
      expect(encodeHealthStudentNo('20230001'), 'MjAyMzAwMDE=');
      expect(encodeHealthStudentNo('  '), '');
    });

    test('登录页判定覆盖 CAS / SSO / 密码框 / 过期文案', () {
      expect(looksLikeHealthLoginPage('<input type="password">'), isTrue);
      expect(
        looksLikeHealthLoginPage(
          '<html><body>location.href="/cas/login?service=x"</body></html>',
        ),
        isTrue,
      );
      expect(looksLikeHealthLoginPage('<html>登录已过期</html>'), isTrue);
      expect(looksLikeHealthLoginPage(_mainPage), isFalse);
      expect(
        looksLikeHealthLoginPage(
          '<table><tr><th>学年</th><th>得分</th></tr></table>',
        ),
        isFalse,
      );
    });

    test('未登录访问 spQuery 的「暂未开放」页要单独识别', () {
      expect(
        looksLikeHealthUnavailablePage(
          '<html><title>体测查询</title><body>暂未开放查询</body></html>',
        ),
        isTrue,
      );
      expect(
        looksLikeHealthUnavailablePage(
          '<table><tr><th>学年</th><th>得分</th></tr></table>',
        ),
        isFalse,
      );
    });
  });
}
