class ApmFlutterError implements Exception {
  final dynamic message;
  final dynamic stackTrace;

  ApmFlutterError(this.message, [this.stackTrace]);

  @override
  String toString() {
    return 'ApmFlutterError: $message';
  }

  Map<String, dynamic> get errorDetail =>
      {'exception': this.message, 'stackTrace': this.stackTrace};
}
