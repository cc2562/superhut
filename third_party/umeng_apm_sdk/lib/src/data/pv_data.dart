class PvData {
  String? enableException;
  String? pagePerf;
  String? pageFps;

  PvData(
      {required this.enableException,
      required this.pagePerf,
      required this.pageFps});

  Map<String, dynamic>? getPreproccessTypeLog() {
    return {
      "enableException": enableException,
      "pagePerf": pagePerf,
      "pageFps": pageFps,
    };
  }

  String getSendTypeLog() {
    return [enableException, pagePerf, pageFps].join('|');
  }
}
