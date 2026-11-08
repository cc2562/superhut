/// 校园卡充值入口 URL 构建。
///
/// 逆向结论（brief Source coverage S12–S15，2026-11-08 真机动态分析）：
/// 官方 App 在 WKWebView 中打开完美校园（17wanxiao）校园卡轻应用，入口为
/// `hub.17wanxiao.com/bsacs/light.action?flag=<学校标识>&ecardFunc=index&token=<X-Id-Token>`，
/// 其中 token 与 portal / 热水等接口使用的 `X-Id-Token` 为同一凭证。
/// 金额输入、支付方式（微信 / 农行掌银）与收银台均由该 H5 内建提供。
class CampusCardApi {
  const CampusCardApi._();

  /// 学校专属标识（官方 App 同款常量）。
  static const String schoolFlag = 'supwisdomapp_hngydxsw';

  /// 完美校园轻应用入口地址。
  static const String entryBaseUrl =
      'https://hub.17wanxiao.com/bsacs/light.action';

  /// 原支付宝小程序充值兜底入口（既有路径，保留作回落）。
  static const String alipayFallbackUrl =
      'alipays://platformapi/startapp?appId=2019030163398604&page=pages/index/index';

  /// 用当前登录态 [token] 构建校园卡 H5 入口 URL。
  ///
  /// [token] 为空或纯空白时抛出 [CampusCardTokenMissingException]。
  static Uri buildEntryUrl(String token) {
    final trimmed = token.trim();
    if (trimmed.isEmpty) {
      throw const CampusCardTokenMissingException();
    }
    return Uri.parse(entryBaseUrl).replace(
      queryParameters: <String, String>{
        'flag': schoolFlag,
        'ecardFunc': 'index',
        'token': trimmed,
      },
    );
  }
}

/// 登录态缺失（无法取得 X-Id-Token）时构建入口 URL 的异常。
class CampusCardTokenMissingException implements Exception {
  const CampusCardTokenMissingException();

  @override
  String toString() => 'CampusCardTokenMissingException: X-Id-Token is empty';
}
