import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/home/coursetable/schedule/schedule_block.dart';
import 'package:superhut/home/coursetable/schedule/schedule_timeline.dart';
import 'package:superhut/utils/course/coursemain.dart';

void main() {
  group('时间窗口', () {
    test('没有内容时回退到 08:00–20:40', () {
      final TimelineWindow window = buildTimelineWindow(
        const <TimelineEntry>[],
      );
      expect(window.startMinute, 8 * 60);
      expect(window.endMinute, 20 * 60 + 40);
    });

    test('按内容并集收缩，上下各留 15 分钟', () {
      final TimelineWindow window = buildTimelineWindow(<TimelineEntry>[
        const TimelineEntry(600, 700),
      ]);
      // 600-15=585 / 700+15=715，但窗口不足 180 分钟会对称补足。
      expect(window.startMinute, 560);
      expect(window.endMinute, 740);
      expect(window.durationMinutes, 180);
    });

    test('内容多时不会补足，只保留真实范围', () {
      final TimelineWindow window = buildTimelineWindow(<TimelineEntry>[
        const TimelineEntry(480, 1240),
      ]);
      expect(window.startMinute, 465);
      expect(window.endMinute, 1255);
    });

    test('窗口不会越过当天边界', () {
      final TimelineWindow window = buildTimelineWindow(<TimelineEntry>[
        const TimelineEntry(0, 30),
      ]);
      expect(window.startMinute, 0);
      expect(window.durationMinutes, greaterThanOrEqualTo(180));
      expect(window.endMinute, lessThanOrEqualTo(kMinutesPerDay));
    });

    test('跨零点的事件画到 24:00', () {
      final TimelineEntry entry = const TimelineEntry(23 * 60, 30).normalized();
      expect(entry.startMinute, 23 * 60);
      expect(entry.endMinute, kMinutesPerDay);

      final TimelineWindow window = buildTimelineWindow(<TimelineEntry>[entry]);
      expect(window.endMinute, kMinutesPerDay);
    });
  });

  group('分钟到像素', () {
    test('一节课（45 分钟）恒为 60px，与改造前一致', () {
      final TimelineWindow window = buildTimelineWindow(<TimelineEntry>[
        const TimelineEntry(480, 525),
      ]);
      expect(window.pixelsPerMinute, closeTo(60 / 45, 0.0001));
      expect(window.heightForRange(480, 525), closeTo(60, 0.0001));
    });

    test('跨两节的课程包含中间课间，比 120px 略高', () {
      final TimelineWindow window = TimelineWindow(
        startMinute: 480,
        endMinute: 1240,
      );
      // 10:00–11:40 含 10 分钟课间。
      expect(window.heightForRange(600, 700), closeTo(100 * 60 / 45, 0.0001));
    });

    test('topFor 越界时钳到窗口边界', () {
      final TimelineWindow window = TimelineWindow(
        startMinute: 480,
        endMinute: 780,
      );
      expect(window.topFor(400), 0);
      expect(window.topFor(900), window.height);
    });

    test('区间部分越界时只算可见部分', () {
      final TimelineWindow window = TimelineWindow(
        startMinute: 480,
        endMinute: 600,
      );
      expect(window.heightForRange(570, 700), closeTo(30 * 60 / 45, 0.0001));
      expect(window.heightForRange(400, 480), 0);
    });

    test('窗口最低高度保证块不会缩成一条线', () {
      final TimelineWindow window = buildTimelineWindow(<TimelineEntry>[
        const TimelineEntry(500, 520),
      ]);
      expect(window.height, greaterThanOrEqualTo(kMinTimelineHeight));
    });
  });

  group('重叠聚类', () {
    int startOf(TimelineEntry entry) => entry.startMinute;
    int endOf(TimelineEntry entry) => entry.endMinute;

    test('不重叠的条目各自成簇', () {
      final List<TimelineCluster<TimelineEntry>> clusters =
          clusterTimelineItems(
            const <TimelineEntry>[
              TimelineEntry(600, 660),
              TimelineEntry(700, 720),
              TimelineEntry(800, 820),
            ],
            startOf: startOf,
            endOf: endOf,
          );
      expect(clusters, hasLength(3));
    });

    test('首尾相接不算重叠', () {
      final List<TimelineCluster<TimelineEntry>> clusters =
          clusterTimelineItems(
            const <TimelineEntry>[
              TimelineEntry(600, 660),
              TimelineEntry(660, 700),
            ],
            startOf: startOf,
            endOf: endOf,
          );
      expect(clusters, hasLength(2));
    });

    test('传递重叠合并成一簇', () {
      final List<TimelineCluster<TimelineEntry>> clusters =
          clusterTimelineItems(
            const <TimelineEntry>[
              TimelineEntry(600, 620),
              TimelineEntry(610, 700),
              TimelineEntry(690, 720),
              TimelineEntry(800, 820),
            ],
            startOf: startOf,
            endOf: endOf,
          );
      expect(clusters, hasLength(2));
      expect(clusters.first.items, hasLength(3));
      expect(clusters.first.startMinute, 600);
      expect(clusters.first.endMinute, 720);
    });
  });

  group('重叠扇出步长', () {
    test('窄列里缩进一层后仍留可读宽度', () {
      // 手机日列约 47dp：缩进 20px 后最上层留 27dp。
      expect(cascadeStep(columnWidth: 47), 20);
    });

    test('宽列里步长封顶，不会错开太远', () {
      expect(cascadeStep(columnWidth: 200), 20);
    });

    test('列宽不足时不错开', () {
      expect(cascadeStep(columnWidth: 10), 0);
    });
  });

  group('节次与窗口交集', () {
    test('窗口内的节次按顺序返回', () {
      final List<TimelineSection> sections = sectionsInsideWindow(
        const TimelineWindow(startMinute: 480, endMinute: 720),
      );
      expect(
        sections.map((TimelineSection section) => section.section),
        <int>[1, 2, 3, 4],
      );
    });

    test('部分可见的节次也算在内', () {
      final List<TimelineSection> sections = sectionsInsideWindow(
        const TimelineWindow(startMinute: 490, endMinute: 500),
      );
      expect(sections.single.section, 1);
    });
  });

  group('周视图固定窗口与空档折叠', () {
    test('固定覆盖第 1 节到第 12 节，并折叠午休与晚饭', () {
      final TimelineWindow window = TimelineWindow.weekGrid();
      expect(window.startMinute, 8 * 60);
      expect(window.endMinute, 22 * 60 + 40);
      expect(
        window.folds.map((TimelineFold fold) => fold.startMinute),
        <int>[11 * 60 + 40, 17 * 60 + 40],
      );
      expect(
        window.folds.map((TimelineFold fold) => fold.endMinute),
        <int>[14 * 60, 19 * 60],
      );
    });

    test('午休不占高度：第 5 节紧贴第 4 节结束', () {
      final TimelineWindow window = TimelineWindow.weekGrid();
      expect(
        window.topFor(14 * 60),
        closeTo(window.topFor(11 * 60 + 40), 0.0001),
      );
    });

    test('晚饭不占高度：第 9 节紧贴第 8 节结束', () {
      final TimelineWindow window = TimelineWindow.weekGrid();
      expect(
        window.topFor(19 * 60),
        closeTo(window.topFor(17 * 60 + 40), 0.0001),
      );
    });

    test('跨越午休的日程只按上午段 + 下午段计高', () {
      final TimelineWindow window = TimelineWindow.weekGrid();
      // 11:00–15:00 跨越 11:40–14:00，应只算 40 + 60 = 100 分钟。
      expect(
        window.heightForRange(11 * 60, 15 * 60),
        closeTo(100 * 60 / 45, 0.0001),
      );
    });

    test('跨越晚饭的日程只按前后两段计高', () {
      final TimelineWindow window = TimelineWindow.weekGrid();
      // 17:00–20:00 跨越 17:40–19:00，应只算 40 + 60 = 100 分钟。
      expect(
        window.heightForRange(17 * 60, 20 * 60),
        closeTo(100 * 60 / 45, 0.0001),
      );
    });

    test('不跨空档的区间高度保持不变', () {
      final TimelineWindow window = TimelineWindow.weekGrid();
      expect(window.heightForRange(8 * 60, 8 * 60 + 45), closeTo(60, 0.0001));
    });
  });

  group('课程换算', () {
    test('课程起止分钟按节次表换算', () {
      final Course course = Course(
        name: '包装材料学',
        teacherName: '何新快',
        weekDuration: '3-10',
        location: '公共222',
        startSection: 3,
        duration: 2,
      );
      expect(courseStartMinute(course), 10 * 60);
      expect(courseEndMinute(course), 11 * 60 + 40);
    });
  });
}
