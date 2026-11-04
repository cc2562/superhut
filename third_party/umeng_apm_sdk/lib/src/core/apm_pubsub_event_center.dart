import 'package:umeng_apm_sdk/src/core/apm_shared.dart';

class ApmPubsubEventCenter {
  factory ApmPubsubEventCenter() => _instance;

  ApmPubsubEventCenter._internal();

  static final ApmPubsubEventCenter _instance =
      ApmPubsubEventCenter._internal();

  final Map<String, dynamic> _listeners = {};

  final _replaceFlag = {};

  void setFlag(String replaceType, bool isSet) {
    if (_replaceFlag.containsKey(replaceType)) return;
    _replaceFlag[replaceType] = isSet;
  }

  bool getFlag(replaceType) {
    return _replaceFlag.containsKey(replaceType);
  }

  bool? subscribeEvent(Map<String, dynamic>? config) {
    ACTIONS type = config?[KEY_TYPE];
    String typeStr = type.toString();
    if (config is! Map || getFlag(typeStr)) return false;
    setFlag(typeStr, true);
    _listeners[typeStr] = _listeners[typeStr] ??= [];
    _listeners[typeStr].add(config?[KEY_HANDLER]);
    return true;
  }

  void dispatchEvent(ACTIONS? type, data) {
    String typeStr = type.toString();
    if (type is! ACTIONS || !_listeners.containsKey(typeStr)) return;
    _listeners[typeStr].forEach((handler) {
      handler(data);
    });
  }

  void dispatchMultiEvent(List<Map<String, dynamic>> multiEventList) {
    multiEventList.forEach((Map opt) {
      final ACTIONS type = opt[KEY_TYPE];
      final dynamic data = opt[KEY_DATA];
      dispatchEvent(type, data);
    });
  }

  Map<String, dynamic> getHandlers() {
    return _listeners;
  }
}
