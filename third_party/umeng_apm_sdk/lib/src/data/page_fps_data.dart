class PageFpsData {
  String? frames;
  int? deviceMaxFps;
  bool? isFirstPage;

  PageFpsData(this.frames, this.deviceMaxFps, this.isFirstPage);

  Map<String, dynamic> getPreproccessTypeLog() {
    return {
      "frames": frames,
      "deviceMaxFps": deviceMaxFps,
      "isFirstPage": isFirstPage
    };
  }

  String getSendTypeLog() {
    List arr = [
      frames ?? '-',
      deviceMaxFps ?? '-',
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
