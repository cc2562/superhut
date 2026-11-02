import ActivityKit
import SwiftUI
import WidgetKit

/// 课程实时活动：灵动岛（紧凑/展开/最小）+ 锁屏卡片。
///
/// 倒计时统一交给 `Text(timerInterval:)`，由系统逐秒刷新，
/// App 不需要为了走秒而反复 update 活动。
struct ClassLiveActivityWidget: Widget {
  var body: some WidgetConfiguration {
    ActivityConfiguration(for: ClassLiveActivityAttributes.self) { context in
      ClassLockScreenView(context: context)
    } dynamicIsland: { context in
      DynamicIsland {
        DynamicIslandExpandedRegion(.leading) {
          Label {
            Text(context.state.courseName)
              .font(.subheadline.weight(.semibold))
              .lineLimit(1)
          } icon: {
            Image(systemName: "book.closed.fill")
          }
          .foregroundStyle(Color.accentColor)
        }
        DynamicIslandExpandedRegion(.trailing) {
          ClassCountdownText(state: context.state)
            .font(.title3.weight(.semibold).monospacedDigit())
        }
        DynamicIslandExpandedRegion(.bottom) {
          HStack(spacing: 12) {
            Label(context.state.location, systemImage: "mappin.and.ellipse")
            Text(ClassActivityFormat.range(context.state))
            Spacer(minLength: 0)
          }
          .font(.caption)
          .foregroundStyle(.secondary)
        }
      } compactLeading: {
        Image(
          systemName:
            context.state.phase == "pre" ? "bell.fill" : "book.closed.fill"
        )
        .foregroundStyle(Color.accentColor)
      } compactTrailing: {
        ClassCountdownText(state: context.state)
          .font(.caption2.weight(.semibold).monospacedDigit())
          // 固定宽度，避免剩余时间从 09:59 变 9:58 时灵动岛抖动。
          .frame(width: 46)
      } minimal: {
        Image(systemName: "book.closed.fill")
          .foregroundStyle(Color.accentColor)
      }
      .keylineTint(.accentColor)
    }
  }
}

/// 锁屏 / 通知中心的实时活动卡片。
private struct ClassLockScreenView: View {
  let context: ActivityViewContext<ClassLiveActivityAttributes>

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(alignment: .firstTextBaseline) {
        Label(
          context.state.phase == "pre" ? "距上课" : "距下课",
          systemImage: "clock"
        )
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        Spacer(minLength: 8)
        ClassCountdownText(state: context.state)
          .font(.title2.weight(.semibold).monospacedDigit())
      }

      Text(context.state.courseName)
        .font(.headline)
        .lineLimit(2)

      HStack(spacing: 12) {
        Label(context.state.location, systemImage: "mappin.and.ellipse")
        Text(ClassActivityFormat.range(context.state))
      }
      .font(.caption)
      .foregroundStyle(.secondary)
    }
    .padding(16)
  }
}

/// 课前倒计时到上课时间，上课中倒计时到下课时间。
private struct ClassCountdownText: View {
  let state: ClassLiveActivityAttributes.ContentState

  private var target: Date {
    state.phase == "pre" ? state.startDate : state.endDate
  }

  var body: some View {
    if target > Date() {
      Text(timerInterval: Date()...target, countsDown: true)
        .multilineTextAlignment(.trailing)
    } else {
      Text("已下课")
    }
  }
}

private enum ClassActivityFormat {
  private static let timeFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "HH:mm"
    return formatter
  }()

  static func range(_ state: ClassLiveActivityAttributes.ContentState) -> String {
    let start = timeFormatter.string(from: state.startDate)
    let end = timeFormatter.string(from: state.endDate)
    return "\(start)–\(end)"
  }
}
