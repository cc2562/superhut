class HeaderData {
  // 应用&模块名称
  String? name;
  // 应用&模块版本（+构建版本）
  String? bver;
  // Flutter SDK 版本
  String? flutterVer;
  // Flutter 引擎版本
  String? engineVer;
  // Dart SDK 版本
  String? dartVer;
  // APM Flutter SDK版本
  String? sdkVer;
  // Flutter Sessionid
  String? fsid;
  // 工程类型
  int? projectType;
  // 业务运行环境
  String? env;
  // 使用flutter boost插件
  int? useBoostPlugin;

  HeaderData(
      {required this.name,
      required this.bver,
      this.flutterVer,
      this.engineVer,
      this.dartVer,
      this.sdkVer,
      this.fsid,
      this.projectType,
      this.env,
      this.useBoostPlugin});

  String? getSendTypeLog() {
    List arr = [
      name ?? '-',
      bver ?? '-',
      flutterVer ?? '-',
      engineVer ?? '-',
      dartVer ?? '-',
      sdkVer ?? '-',
      fsid ?? '-',
      projectType ?? 0,
      env ?? '-',
      useBoostPlugin ?? 0
    ];

    List<dynamic> result = arr.map((val) {
      if (val is String) {
        return Uri.encodeComponent(val.toString());
      }
      return val;
    }).toList();

    return result.join('|');
  }
}
