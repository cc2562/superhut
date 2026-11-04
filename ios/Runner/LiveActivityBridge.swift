import ActivityKit
import Flutter
import UIKit

/// 课程实时活动的 Flutter 桥。
///
/// 所有方法都返回 Bool：成功为 true，系统未授权、参数缺失或系统版本过低都返回 false，
/// 由 Dart 侧当作「本次不展示」，不抛未捕获异常。
final class LiveActivityBridge {
  static let channelName = "com.zhiquxy.rice/live_activity"

  private let channel: FlutterMethodChannel

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
    // 低版本 iOS 没有 ActivityKit：统一回 false，让 Dart 侧静默跳过。
    guard #available(iOS 16.1, *) else {
      result(false)
      return
    }

    switch call.method {
    case "isSupported":
      result(ActivityAuthorizationInfo().areActivitiesEnabled)
    case "start":
      guard let request = ClassActivityRequest(call.arguments) else {
        result(false)
        return
      }
      start(request, result: result)
    case "update":
      guard let request = ClassActivityRequest(call.arguments) else {
        result(false)
        return
      }
      update(request, result: result)
    case "end":
      let arguments = call.arguments as? [String: Any]
      guard let courseId = arguments?["courseId"] as? String else {
        result(false)
        return
      }
      end(courseId: courseId, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @available(iOS 16.1, *)
  private func start(_ request: ClassActivityRequest, result: @escaping FlutterResult) {
    guard ActivityAuthorizationInfo().areActivitiesEnabled else {
      result(false)
      return
    }
    // 回调必须在主线程执行，ActivityKit 的 API 同样在主 actor 上调用最稳妥。
    Task { @MainActor in
      // 同一门课重新开始前先收掉旧活动，避免灵动岛出现两条同样的课程。
      await endActivities(courseId: request.courseId)
      do {
        let attributes = ClassLiveActivityAttributes(courseId: request.courseId)
        if #available(iOS 16.2, *) {
          let content = ActivityContent(
            state: request.state,
            staleDate: request.state.endDate
          )
          _ = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: nil
          )
        } else {
          _ = try Activity.request(
            attributes: attributes,
            contentState: request.state,
            pushType: nil
          )
        }
        result(true)
      } catch {
        NSLog("LiveActivityBridge: start failed – \(error.localizedDescription)")
        result(false)
      }
    }
  }

  @available(iOS 16.1, *)
  private func update(_ request: ClassActivityRequest, result: @escaping FlutterResult) {
    Task { @MainActor in
      var updated = false
      for activity in Activity<ClassLiveActivityAttributes>.activities
      where activity.attributes.courseId == request.courseId {
        if #available(iOS 16.2, *) {
          let content = ActivityContent(
            state: request.state,
            staleDate: request.state.endDate
          )
          await activity.update(content)
        } else {
          await activity.update(using: request.state)
        }
        updated = true
      }
      result(updated)
    }
  }

  @available(iOS 16.1, *)
  private func end(courseId: String, result: @escaping FlutterResult) {
    Task { @MainActor in
      await endActivities(courseId: courseId)
      result(true)
    }
  }

  @available(iOS 16.1, *)
  private func endActivities(courseId: String) async {
    for activity in Activity<ClassLiveActivityAttributes>.activities
    where activity.attributes.courseId == courseId {
      if #available(iOS 16.2, *) {
        await activity.end(nil, dismissalPolicy: .immediate)
      } else {
        await activity.end(dismissalPolicy: .immediate)
      }
    }
  }
}

/// 把 Flutter 传来的 Map 解析成活动参数；缺字段时返回 nil。
@available(iOS 16.1, *)
private struct ClassActivityRequest {
  let courseId: String
  let state: ClassLiveActivityAttributes.ContentState

  init?(_ arguments: Any?) {
    guard
      let args = arguments as? [String: Any],
      let courseId = args["courseId"] as? String,
      let courseName = args["courseName"] as? String,
      let location = args["location"] as? String,
      let startMs = args["startTimeMs"] as? NSNumber,
      let endMs = args["endTimeMs"] as? NSNumber,
      let phase = args["phase"] as? String
    else {
      return nil
    }

    self.courseId = courseId
    self.state = ClassLiveActivityAttributes.ContentState(
      phase: phase,
      courseName: courseName,
      location: location,
      startDate: Date(timeIntervalSince1970: startMs.doubleValue / 1000),
      endDate: Date(timeIntervalSince1970: endMs.doubleValue / 1000)
    )
  }
}
