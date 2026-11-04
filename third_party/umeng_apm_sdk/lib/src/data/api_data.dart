class ApiData {
  String? uri;
  String? method;
  int? statusCode;
  int? spend;
  int? reqSize;
  int? resSize;
  int? type;
  String? message;

  ApiData(
      this.uri,
      this.method,
      this.statusCode,
      this.spend,
      this.reqSize,
      this.resSize,
      this.type,
      this.message
      );

  Map<String, dynamic> getPreproccessTypeLog() {
    return {
      "uri": uri,
      "method": method,
      "statusCode": statusCode,
      "spend": spend,
      "reqSize": reqSize,
      "resSize": resSize,
      "type":type,
      "message":message
    };
  }

  String getSendTypeLog() {
    List arr = [
      uri ?? '-',
      method ?? '-',
      statusCode ?? '-',
      spend ?? '-',
      reqSize ?? '-',
      resSize ?? '-',
      type ?? '-',
      message ?? '-'
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