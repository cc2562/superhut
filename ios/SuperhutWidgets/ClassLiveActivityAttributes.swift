import ActivityKit
import Foundation

/// 课程实时活动的数据模型。
///
/// 这份文件同时加入 Runner 与 SuperhutWidgets 两个 target 的 Compile Sources。
/// 两个 target 各自编译一份，类型名与成员顺序必须完全一致，
/// 否则 ActivityKit 无法把 App 启动的活动与 Widget 的 UI 关联起来。
@available(iOS 16.1, *)
struct ClassLiveActivityAttributes: ActivityAttributes {
  struct ContentState: Codable, Hashable {
    /// 阶段："pre"（上课前 10 分钟）或 "inClass"（上课中）。
    var phase: String
    var courseName: String
    var location: String
    var startDate: Date
    var endDate: Date
  }

  /// 课程标识（日期 + 节次 + 课程名），用于结束或更新同一场活动。
  var courseId: String
}
