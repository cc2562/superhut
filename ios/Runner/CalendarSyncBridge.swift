import EventKit
import Flutter
import UIKit

/// 系统日历读写桥（单向：超级包菜 → 系统日历）。
///
/// 只管理本 App 创建的「超级包菜课表」日历；不读取用户其它日历内容，
/// 日历 App 里的修改也不会回流到 App。
final class CalendarSyncBridge {
  static let channelName = "com.superhut.rice.superhut/calendar_sync"

  private let channel: FlutterMethodChannel
  private let store = EKEventStore()

  /// EventKit 的批量写入会阻塞线程，放串行队列里执行，结果回主线程。
  private let queue = DispatchQueue(
    label: "com.superhut.rice.calendar",
    qos: .userInitiated
  )

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(
      name: Self.channelName,
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
  }

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "hasPermission":
      result(hasCalendarPermission())
    case "requestPermission":
      requestPermission(result: result)
    case "ensureCalendar", "writeEvents", "deleteEvents", "deleteCalendar":
      queue.async { [weak self] in
        guard let self = self else {
          DispatchQueue.main.async { result(nil) }
          return
        }
        var value: Any?
        switch call.method {
        case "ensureCalendar":
          value = self.ensureCalendar(call)
        case "writeEvents":
          value = self.writeEvents(call)
        case "deleteEvents":
          value = self.deleteEvents(call)
        default:
          value = self.deleteCalendar(call)
        }
        DispatchQueue.main.async { result(value) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: - 权限

  /// 写入新日历需要完整访问权限；iOS 17 起没有 `.authorized`。
  private func hasCalendarPermission() -> Bool {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *) {
      return status == .fullAccess
    }
    return status == .authorized
  }

  private func requestPermission(result: @escaping FlutterResult) {
    if hasCalendarPermission() {
      result(true)
      return
    }

    if #available(iOS 17.0, *) {
      store.requestFullAccessToEvents { granted, error in
        if let error = error {
          NSLog("CalendarSync permission error: %@", error.localizedDescription)
        }
        DispatchQueue.main.async { result(granted) }
      }
    } else {
      store.requestAccess(to: .event) { granted, error in
        if let error = error {
          NSLog("CalendarSync permission error: %@", error.localizedDescription)
        }
        DispatchQueue.main.async { result(granted) }
      }
    }
  }

  // MARK: - 日历

  private func ensureCalendar(_ call: FlutterMethodCall) -> Any? {
    let arguments = call.arguments as? [String: Any]
    let name = arguments?["name"] as? String ?? "超级包菜课表"
    let colorValue = arguments?["color"] as? NSNumber

    if let existing = store.calendars(for: .event).first(where: { $0.title == name }) {
      return existing.calendarIdentifier
    }

    // 优先挂到系统默认日历的账号；没有默认账号时退回 local source。
    guard let source = defaultSource() else { return nil }
    return createCalendar(name: name, source: source, color: colorValue)
  }

  private func defaultSource() -> EKSource? {
    if let source = store.defaultCalendarForNewEvents?.source {
      return source
    }
    return store.sources.first(where: { $0.sourceType == .local })
  }

  private func createCalendar(name: String, source: EKSource, color: NSNumber?) -> String? {
    let calendar = EKCalendar(for: .event, eventStore: store)
    calendar.title = name
    calendar.source = source
    if let color = color {
      calendar.cgColor = Self.uiColor(fromARGB: color.intValue).cgColor
    }

    do {
      try store.saveCalendar(calendar, commit: true)
      return calendar.calendarIdentifier
    } catch {
      NSLog("CalendarSync create calendar failed: %@", error.localizedDescription)
      return nil
    }
  }

  private func deleteCalendar(_ call: FlutterMethodCall) -> Any? {
    let arguments = call.arguments as? [String: Any]
    guard let identifier = arguments?["calendarId"] as? String,
      let calendar = store.calendar(withIdentifier: identifier)
    else {
      return false
    }

    do {
      try store.removeCalendar(calendar, commit: true)
      return true
    } catch {
      NSLog("CalendarSync delete calendar failed: %@", error.localizedDescription)
      return false
    }
  }

  // MARK: - 事件

  private func writeEvents(_ call: FlutterMethodCall) -> Any? {
    let arguments = call.arguments as? [String: Any]
    guard let calendarId = arguments?["calendarId"] as? String,
      let calendar = store.calendar(withIdentifier: calendarId)
    else {
      // 日历被用户在系统里删掉了：返回空数组，由 Dart 侧重置簿记后重建。
      return [Any]()
    }

    let rawEvents = arguments?["events"] as? [[String: Any]] ?? []
    var saved: [(index: Int, event: EKEvent)] = []
    var identifiers = [Any](repeating: NSNull(), count: rawEvents.count)

    for (index, raw) in rawEvents.enumerated() {
      let event: EKEvent
      if let existingId = raw["eventId"] as? String,
        let existing = store.event(withIdentifier: existingId)
      {
        event = existing
      } else {
        event = EKEvent(eventStore: store)
      }

      event.calendar = calendar
      event.title = raw["title"] as? String ?? ""
      event.location = raw["location"] as? String
      event.notes = raw["description"] as? String

      let start = (raw["startMillis"] as? NSNumber)?.doubleValue ?? 0
      let end = (raw["endMillis"] as? NSNumber)?.doubleValue ?? 0
      event.startDate = Date(timeIntervalSince1970: start / 1000)
      event.endDate = Date(timeIntervalSince1970: end / 1000)

      let reminderMinutes = (raw["reminderMinutes"] as? NSNumber)?.intValue ?? 0
      if reminderMinutes > 0 {
        event.alarms = [EKAlarm(relativeOffset: -Double(reminderMinutes) * 60)]
      } else {
        event.alarms = []
      }

      do {
        try store.save(event, span: .thisEvent, commit: false)
        saved.append((index, event))
      } catch {
        NSLog("CalendarSync save event failed: %@", error.localizedDescription)
      }
    }

    if !saved.isEmpty {
      do {
        try store.commit()
      } catch {
        NSLog("CalendarSync commit failed: %@", error.localizedDescription)
      }
      for entry in saved {
        identifiers[entry.index] = entry.event.eventIdentifier ?? NSNull()
      }
    }

    return identifiers
  }

  private func deleteEvents(_ call: FlutterMethodCall) -> Any? {
    let arguments = call.arguments as? [String: Any]
    let identifiers = arguments?["eventIds"] as? [String] ?? []
    var deleted = 0

    for identifier in identifiers {
      guard let event = store.event(withIdentifier: identifier) else { continue }
      do {
        try store.remove(event, span: .thisEvent, commit: false)
        deleted += 1
      } catch {
        NSLog("CalendarSync remove event failed: %@", error.localizedDescription)
      }
    }

    if deleted > 0 {
      do {
        try store.commit()
      } catch {
        NSLog("CalendarSync delete commit failed: %@", error.localizedDescription)
      }
    }
    return deleted
  }

  // MARK: - 颜色

  private static func uiColor(fromARGB value: Int) -> UIColor {
    let alpha = CGFloat((value >> 24) & 0xFF) / 255
    let red = CGFloat((value >> 16) & 0xFF) / 255
    let green = CGFloat((value >> 8) & 0xFF) / 255
    let blue = CGFloat(value & 0xFF) / 255
    return UIColor(
      red: red,
      green: green,
      blue: blue,
      alpha: alpha == 0 ? 1 : alpha
    )
  }
}
