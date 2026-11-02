import 'package:flutter/foundation.dart';

/// 一份协议的元信息。
///
/// 正文只有一份真源：`assets/*.md`。这里只放「标题 + 资源路径」，
/// 页面在运行时用 `rootBundle` 读取，避免把长文硬编码进 Dart。
@immutable
class AgreementDocument {
  const AgreementDocument({required this.title, required this.assetPath});

  /// 协议名，同时用作阅读页标题与同意页里的可点击名称。
  final String title;

  /// Markdown 资源路径（`pubspec.yaml` 的 `assets: - assets/` 已覆盖）。
  final String assetPath;
}

/// 应用内的全部协议与当前版本号。
///
/// 版本号是「是否已同意」的判据：`agreement.acceptedVersion` 与
/// [AgreementDocuments.version] 相等才算同意过。协议内容改版时，
/// 只需把这里的 [version] 与两份 md 文首的「版本」行同步改掉，
/// 用户下次启动就会重新看到同意页。
class AgreementDocuments {
  const AgreementDocuments._();

  /// 当前协议版本（与 `assets/UserAgreement.md`、`assets/PrivacyAgreement.md`
  /// 文首的版本行必须一致）。
  static const String version = '2026-11-02';

  static const AgreementDocument userAgreement = AgreementDocument(
    title: '用户协议',
    assetPath: 'assets/UserAgreement.md',
  );

  static const AgreementDocument privacyPolicy = AgreementDocument(
    title: '隐私政策',
    assetPath: 'assets/PrivacyAgreement.md',
  );

  /// 同意页按此顺序展示入口。
  static const List<AgreementDocument> all = [userAgreement, privacyPolicy];
}
