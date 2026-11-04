import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/health/health_score_api.dart';
import 'package:superhut/pages/health/health_score_detail_page.dart';
import 'package:superhut/pages/health/health_score_models.dart';
import 'package:superhut/pages/health/health_score_page.dart';

class _FakeHealthScoreApi extends HealthScoreApi {
  _FakeHealthScoreApi({
    required this.snapshot,
    this.detail,
    this.error,
    this.detailError,
  });

  final HealthScoreSnapshot snapshot;
  final HealthDetailTable? detail;
  final Object? error;
  final Object? detailError;

  @override
  Future<HealthScoreSnapshot> fetchSnapshot() async {
    final Object? failure = error;
    if (failure != null) throw failure;
    return snapshot;
  }

  @override
  Future<HealthDetailTable> fetchDetail(HealthTermRecord record) async {
    final Object? failure = detailError;
    if (failure != null) throw failure;
    final HealthDetailTable? table = detail;
    if (table == null) {
      throw const HealthScoreException('没有详情数据');
    }
    return table;
  }
}

const HealthTermRecord _term2025 = HealthTermRecord(
  year: '2025-2026',
  term: '1',
  label: '2025-2026-1',
  grade: '43',
  bonus: '0',
  score: 31,
  level: '不及格',
);

const HealthTermRecord _term2026 = HealthTermRecord(
  year: '2026-2027',
  term: '1',
  label: '2026-2027-1',
  grade: '44',
  bonus: '0',
  score: 82,
  level: '良好',
);

HealthScoreSnapshot _snapshot(List<HealthTermRecord> records) {
  return HealthScoreSnapshot(
    studentNo: '20230001',
    schoolId: '100001',
    records: records,
  );
}

Future<void> _pumpPage(WidgetTester tester, HealthScoreApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: HealthScorePage(api: api),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _pumpDetail(WidgetTester tester, HealthScoreApi api) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(useMaterial3: true),
      home: HealthScoreDetailPage(api: api, record: _term2025),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  testWidgets('主页展示总览、趋势与历年记录', (tester) async {
    await _pumpPage(
      tester,
      _FakeHealthScoreApi(
        snapshot: _snapshot(<HealthTermRecord>[_term2025, _term2026]),
      ),
    );

    expect(find.text('体测查询'), findsOneWidget);
    expect(find.text('最近一次'), findsOneWidget);
    expect(find.text('82'), findsWidgets);
    expect(find.text('良好'), findsWidgets);
    expect(find.text('历年总分趋势'), findsOneWidget);
    expect(find.text('历年记录'), findsOneWidget);
    expect(find.text('2025-2026-1'), findsOneWidget);
  });

  testWidgets('点击记录进入详情并按行序渲染项目', (tester) async {
    await _pumpPage(
      tester,
      _FakeHealthScoreApi(
        snapshot: _snapshot(<HealthTermRecord>[_term2025, _term2026]),
        detail: const HealthDetailTable(
          columns: <String>['项目', '成绩', '得分', '等级'],
          rows: <List<String>>[
            <String>['身高', '162', '100', '优秀'],
            <String>['800米跑', "3'50\"", '76', '及格'],
            <String>['仰卧起坐', '42', '80', '良好'],
          ],
          positional: false,
        ),
      ),
    );

    await tester.ensureVisible(find.text('2025-2026-1'));
    await tester.pump();
    await tester.tap(find.text('2025-2026-1'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(HealthScoreDetailPage), findsOneWidget);
    expect(find.text('体测详情'), findsOneWidget);
    expect(find.text('项目明细'), findsOneWidget);
    expect(find.text('800米跑'), findsOneWidget);
    expect(find.text('仰卧起坐'), findsOneWidget);
    expect(find.text('引体向上'), findsNothing);
  });

  testWidgets('空数据显示空态', (tester) async {
    await _pumpPage(
      tester,
      _FakeHealthScoreApi(snapshot: _snapshot(const <HealthTermRecord>[])),
    );

    expect(find.text('暂无体测记录'), findsOneWidget);
    expect(find.text('刷新'), findsOneWidget);
  });

  testWidgets('登录失效时只给返回入口', (tester) async {
    await _pumpPage(
      tester,
      _FakeHealthScoreApi(
        snapshot: _snapshot(const <HealthTermRecord>[]),
        error: const HealthScoreAuthException(),
      ),
    );

    expect(find.text('登录状态已失效'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    // 入口已经走过 renewToken，页内不再提供原地重新登录。
    expect(find.text('重新登录'), findsNothing);
    expect(find.text('重试'), findsNothing);
  });

  testWidgets('详情登录失效时同样只给返回入口', (tester) async {
    await _pumpDetail(
      tester,
      _FakeHealthScoreApi(
        snapshot: _snapshot(const <HealthTermRecord>[]),
        detailError: const HealthScoreAuthException(),
      ),
    );

    expect(find.text('登录状态已失效'), findsOneWidget);
    expect(find.text('返回'), findsOneWidget);
    expect(find.text('重新登录'), findsNothing);
  });
}
