class CommonData {
  // 日志类型（error、pv）
  String? logType;
  // Flutter 页面URL
  String? url;
  // 追踪页面的生命周期
  String? pvId;
  // 是否自动发送 Y|N
  String? auto;
  // 网络是WiFi还是移动网络
  String? access;
  // 移动网络下，判断具体的移动制式
  String? accessSubtype;
  // 前后台状态 fg ｜bg
  String? state;
  // 设备电量
  dynamic battery;
  // 电池温度
  dynamic temperature;
  // 磁盘可用占比
  dynamic diskRatio;
  // SD卡可用占比
  dynamic sdRatio;
  // 日志客户端生成时间
  int ctime;
  // native session id
  String? sid;

  CommonData({
    required this.logType,
    this.url = '-',
    this.pvId = '-',
    this.auto = 'Y',
    this.access = '-',
    this.accessSubtype = '-',
    this.state = 'fp',
    this.battery = '-',
    this.temperature = '-',
    this.diskRatio = '-',
    this.sdRatio = '-',
    this.ctime = 0,
    this.sid = '-',
  }) {
    ctime = DateTime.now().millisecondsSinceEpoch;
  }
  Map<String, dynamic> getPreproccessTypeLog() {
    return {
      'logType': logType,
      'url': url,
      'pvId': pvId,
      'auto': auto,
      'access': access,
      'accessSubtype': accessSubtype,
      'state': state,
      'battery': battery,
      'temperature': temperature,
      'diskRatio': diskRatio,
      'sdRatio': sdRatio,
      'ctime': ctime,
      'sid': sid
    };
  }

  String? getSendTypeLog() {
    List arr = [
      logType ?? '-',
      url ?? '-',
      pvId ?? '-',
      ctime,
      auto ?? '-',
      access ?? '-',
      accessSubtype ?? '-',
      state ?? '-',
      battery ?? '-',
      temperature ?? '-',
      diskRatio ?? '-',
      sdRatio ?? '-',
      sid ?? '-'
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
