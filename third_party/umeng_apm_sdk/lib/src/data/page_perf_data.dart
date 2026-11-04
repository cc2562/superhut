enum PagePerfLog {
  tdStartTimestamp,
  tdEndTimestamp,
  fpTimestamp,
  fcpTimestamp,
  ttiTimestamp
}

class PagePerfData {
  int? tdStartTimestamp;
  int? tdEndTimestamp;
  int? fpTimestamp;
  int? fcpTimestamp;
  int? ttiTimestamp;
  bool? isFirstPage;

  PagePerfData(
    this.isFirstPage, {
    this.tdStartTimestamp,
    this.tdEndTimestamp,
    this.fpTimestamp,
    this.fcpTimestamp,
    this.ttiTimestamp,
  });

  Map<String, dynamic> getPreproccessTypeLog() {
    return {
      "tdStartTime": tdStartTimestamp,
      "tdEndTime": tdEndTimestamp,
      "fpTime": fpTimestamp,
      "fcpTime": fcpTimestamp,
      "ttiTime": ttiTimestamp,
      "isFirstPage": isFirstPage
    };
  }

  void setLog(PagePerfLog type, int timestamp) {
    switch (type) {
      case PagePerfLog.tdStartTimestamp:
        this.tdStartTimestamp = timestamp;
        break;
      case PagePerfLog.tdEndTimestamp:
        this.tdEndTimestamp = timestamp;
        break;
      case PagePerfLog.fpTimestamp:
        this.fpTimestamp = timestamp;
        break;
      case PagePerfLog.fcpTimestamp:
        this.fcpTimestamp = timestamp;
        break;
      case PagePerfLog.ttiTimestamp:
        this.ttiTimestamp = timestamp;
        break;
      default:
    }
  }

  String getSendTypeLog() {
    List arr = [
      tdStartTimestamp ?? '-',
      tdEndTimestamp ?? '-',
      fpTimestamp ?? '-',
      fcpTimestamp ?? '-',
      ttiTimestamp ?? '-',
      isFirstPage != null && isFirstPage! ? 'Y' : 'N'
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
