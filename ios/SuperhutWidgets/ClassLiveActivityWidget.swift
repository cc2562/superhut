import ActivityKit
import SwiftUI
import WidgetKit

/// 课程实时活动：灵动岛（紧凑/展开/最小）+ 锁屏卡片。
///
/// 倒计时统一交给 `Text(timerInterval:)`，由系统逐秒刷新，
/// App 不需要为了走秒而反复 update 活动。
///
/// 「课前 / 上课中」的阶段也由时间轴自己推进：App 在锁屏后被挂起时跑不到
/// Dart 侧的切换定时器，阶段只能由 `startDate` / `endDate` 推导。
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
          ClassTimedCountdown(state: context.state)
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
        ClassTimedPhaseIcon(state: context.state)
      } compactTrailing: {
        ClassTimedCountdown(state: context.state)
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

// MARK: - 系统时间轴

/// 用系统时间轴驱动「课前 / 上课中」的切换。
///
/// 这两个阶段本来由 App 内的 Dart 定时器触发，但手机锁屏后 iOS 会挂起进程，
/// 定时器跑不到上课时刻，倒计时就会一直指着上课时间（上课后反而显示「已下课」）。
/// 这里改用 `.explicit` 时间轴：系统只在 `startDate` 与 `endDate` 两个时刻各重建
/// 一次视图，既不需要 App 在前台，也不用为了阶段切换做每秒刷新（走秒仍由
/// `Text(timerInterval:)` 负责）。
private struct ClassTimed<Content: View>: View {
  let state: ClassLiveActivityAttributes.ContentState

  private let content: (Date) -> Content

  init(
    state: ClassLiveActivityAttributes.ContentState,
    @ViewBuilder content: @escaping (Date) -> Content
  ) {
    self.state = state
    self.content = content
  }

  var body: some View {
    TimelineView(.explicit([state.startDate, state.endDate])) { context in
      content(context.date)
    }
  }
}

/// 跟随时间轴切换的阶段图标：课前是铃铛，上课中是书本。
private struct ClassTimedPhaseIcon: View {
  let state: ClassLiveActivityAttributes.ContentState

  var body: some View {
    ClassTimed(state: state) { now in
      Image(systemName: now < state.startDate ? "bell.fill" : "book.closed.fill")
        .foregroundStyle(Color.accentColor)
    }
  }
}

/// 跟随时间轴的倒计时文本。
private struct ClassTimedCountdown: View {
  let state: ClassLiveActivityAttributes.ContentState

  var body: some View {
    ClassTimed(state: state) { now in
      ClassCountdownText(state: state, now: now)
    }
  }
}

/// 锁屏 / 通知中心的实时活动卡片。
private struct ClassLockScreenView: View {
  let context: ActivityViewContext<ClassLiveActivityAttributes>

  var body: some View {
    ClassTimed(state: context.state) { now in
      let preClass = now < context.state.startDate
      VStack(alignment: .leading, spacing: 10) {
        HStack(alignment: .firstTextBaseline) {
          Label(
            preClass ? "距上课" : "距下课",
            systemImage: "clock"
          )
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
          Spacer(minLength: 8)
          ClassCountdownText(state: context.state, now: now)
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
}

/// 课前倒计时到上课时间，上课中倒计时到下课时间。
///
/// 目标时间由 [now] 与该课的起止时间推导，不再读 `phase`：拿不到 App 更新时
/// `phase` 会一直停在「课前」。
private struct ClassCountdownText: View {
  let state: ClassLiveActivityAttributes.ContentState
  let now: Date

  private var target: Date {
    now < state.startDate ? state.startDate : state.endDate
  }

  var body: some View {
    if target > now {
      Text(timerInterval: now...target, countsDown: true)
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
