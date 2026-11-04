class BaseEvent {
  final DateTime createTime;

  final Map<dynamic, dynamic>? params;

  BaseEvent({this.params}) : createTime = DateTime.now();
}
