class ExceptionData {
  // 异常摘要
  String? msg;
  // 异常堆栈
  String? stack;
  // 异常类型
  String? type;
  // 异常级别
  String? level;
  // 重复次数
  int? frequency;
  //自定义属性
  String? extra;

  ExceptionData({
    required this.msg,
    required this.stack,
    required this.type,
    required this.level,
    this.frequency = 1,
    this.extra = '-',
  });

  void setFrequency() {
    frequency = (frequency ?? 1) + 1;
  }

  Map<String, dynamic> getPreproccessTypeLog() {
    return {
      "msg": msg,
      "stack": stack,
      "type": type,
      "level": level,
      "frequency": frequency,
      "extra": extra
    };
  }

  String getSendTypeLog() {
    List arr = [
      msg ?? '-',
      stack ?? '-',
      type ?? '-',
      level ?? '-',
      frequency ?? '-',
      extra ?? '-'
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
