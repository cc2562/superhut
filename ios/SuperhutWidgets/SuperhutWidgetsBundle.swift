import SwiftUI
import WidgetKit

/// Widget Extension 的入口。目前只承载课程实时活动（灵动岛 + 锁屏卡片）。
@main
struct SuperhutWidgetsBundle: WidgetBundle {
  var body: some Widget {
    ClassLiveActivityWidget()
  }
}
