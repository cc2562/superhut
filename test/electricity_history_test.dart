import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_chart.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_page.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('解析', () {
    test('parseAmount 兼容字符串、数字、空值与脏数据', () {
      expect(parseAmount('51.714270'), closeTo(51.71427, 1e-9));
      expect(parseAmount(3), 3);
      expect(parseAmount(null), 0);
      expect(parseAmount(''), 0);
      expect(parseAmount('--'), 0);
    });

    test('账户行使用大写字段，acid 取 ACID、查询用 ACGUID', () {
      final account = ElectricityAccount.fromApiRow(const {
        'ACGUID': '4DA65C080C8048E4BD410BE271B7F81C',
        'ACID': 'HNGD002863',
        'ACNAME': '河西西苑08栋402',
        'ACSUM': '51.714270',
        'price': '0.6340',
      });

      expect(account.acguid, '4DA65C080C8048E4BD410BE271B7F81C');
      expect(account.acid, 'HNGD002863');
      expect(account.name, '河西西苑08栋402');
      expect(account.balance, closeTo(51.71427, 1e-9));
      expect(account.price, closeTo(0.634, 1e-9));
      expect(account.isValid, isTrue);
    });

    test('明细行使用小写字段，日期只保留到天', () {
      final record = UsageRecord.fromApiRow(const {
        'stattime': '2026-11-04',
        'paysum': '0',
        'usesum': '0.91',
        'f_01_d': '1.52',
        'acsum': '51.71',
      });

      expect(record.statTime, DateTime(2026, 11, 4));
      expect(record.dateKey, '2026-11-04');
      expect(record.kwh, 1.52);
      expect(record.cost, 0.91);
      expect(record.recharge, 0);
      expect(record.balance, 51.71);
    });

    test('日期字段缺失时不会抛异常', () {
      final record = UsageRecord.fromApiRow(const {});
      expect(record.kwh, 0);
      expect(record.dateKey, '1970-01-01');
    });
  });

  group('区间计算', () {
    final now = DateTime(2026, 11, 4, 15, 30);

    test('近 7 天含今天', () {
      final range = UsageRange.of(UsageRangePreset.last7Days, now: now);
      expect(range.startParam, '2026-10-29');
      expect(range.endParam, '2026-11-04');
    });

    test('近 30 天含今天', () {
      final range = UsageRange.of(UsageRangePreset.last30Days, now: now);
      expect(range.startParam, '2026-10-06');
      expect(range.endParam, '2026-11-04');
    });

    test('本月从 1 号开始', () {
      final range = UsageRange.of(UsageRangePreset.thisMonth, now: now);
      expect(range.startParam, '2026-11-01');
      expect(range.endParam, '2026-11-04');
    });
  });

  group('序列合并与统计', () {
    UsageRecord record(int day, {double kwh = 1, double cost = 0.6}) {
      return UsageRecord(
        statTime: DateTime(2026, 11, day),
        kwh: kwh,
        cost: cost,
        recharge: day == 2 ? 20 : 0,
        balance: 50 - day.toDouble(),
      );
    }

    test('分页结果按日期去重并升序', () {
      final merged = mergeUsageRecords([
        record(3),
        record(1),
        record(3, kwh: 9),
        record(2),
      ]);

      expect(merged.map((item) => item.dateKey), [
        '2026-11-01',
        '2026-11-02',
        '2026-11-03',
      ]);
      // 同一天以后到的数据为准
      expect(merged.last.kwh, 9);
    });

    test('明细表使用降序', () {
      final desc = sortUsageDesc([record(1), record(3), record(2)]);
      expect(desc.first.dateKey, '2026-11-03');
      expect(desc.last.dateKey, '2026-11-01');
    });

    test('汇总取最后一天的余额并计算日均', () {
      final summary = UsageSummary.fromRecords([record(1), record(2, kwh: 3)]);
      expect(summary.days, 2);
      expect(summary.totalKwh, 4);
      expect(summary.totalCost, closeTo(1.2, 1e-9));
      expect(summary.totalRecharge, 20);
      expect(summary.latestBalance, 48);
      expect(summary.avgKwh, 2);
    });

    test('空数据汇总全为 0', () {
      final summary = UsageSummary.fromRecords(const []);
      expect(summary.days, 0);
      expect(summary.avgKwh, 0);
      expect(summary, same(UsageSummary.empty));
    });
  });

  group('多账户存储', () {
    const accountA = ElectricityAccount(
      acguid: 'A',
      acid: 'HNGD001',
      name: '河西西苑08栋402',
      balance: 51.7,
      price: 0.634,
    );
    const accountB = ElectricityAccount(
      acguid: 'B',
      acid: 'HNGD002',
      name: '河西东苑01栋402',
      balance: 108.5,
      price: 0.634,
    );

    test('解码脏数据返回空列表', () {
      expect(ElectricityHistoryStore.decodeAccounts(null), isEmpty);
      expect(ElectricityHistoryStore.decodeAccounts('not json'), isEmpty);
      expect(ElectricityHistoryStore.decodeAccounts('{"a":1}'), isEmpty);
      expect(
        ElectricityHistoryStore.decodeAccounts('[{"acguid":""}]'),
        isEmpty,
      );
    });

    test('同 acguid 覆盖而不重复，新账户插到最前', () {
      var accounts = ElectricityHistoryStore.upsertAccountInList(
        const [],
        accountA,
      );
      expect(accounts.length, 1);

      accounts = ElectricityHistoryStore.upsertAccountInList(
        accounts,
        accountA.copyWith(balance: 10),
      );
      expect(accounts.length, 1);
      expect(accounts.single.balance, 10);

      accounts = ElectricityHistoryStore.upsertAccountInList(
        accounts,
        accountB,
      );
      expect(accounts.map((item) => item.acguid), ['B', 'A']);
    });

    test('解绑后选中项回退到首个，删空返回 null', () {
      final accounts = [accountB, accountA];
      expect(
        ElectricityHistoryStore.resolveSelectedId(accounts, 'A'),
        'A',
      );
      expect(
        ElectricityHistoryStore.resolveSelectedId(accounts, 'missing'),
        'B',
      );
      expect(ElectricityHistoryStore.resolveSelectedId(const [], 'A'), isNull);

      final removed = ElectricityHistoryStore.removeAccountFromList(
        accounts,
        'B',
      );
      expect(removed.map((item) => item.acguid), ['A']);
    });

    test('读写 SharedPreferences 并维护选中账户', () async {
      SharedPreferences.setMockInitialValues({});
      final store = ElectricityHistoryStore();

      await store.upsertAccount(accountA);
      expect((await store.loadAccounts()).length, 1);
      expect(await store.loadSelectedId(), 'A');

      await store.upsertAccount(accountB);
      expect(await store.loadSelectedId(), 'B');
      expect((await store.loadAccounts()).map((item) => item.acguid), [
        'B',
        'A',
      ]);

      await store.removeAccount('B');
      expect(await store.loadSelectedId(), 'A');

      await store.removeAccount('A');
      expect(await store.loadAccounts(), isEmpty);
      expect(await store.loadSelectedId(), isNull);
    });
  });

  group('界面冒烟', () {
    testWidgets('没有绑定账户时显示引导卡', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(
        const MaterialApp(home: ElectricityHistoryPage()),
      );
      await tester.pumpAndSettle();

      expect(find.text('绑定宿舍账户'), findsOneWidget);
      expect(find.text('搜索宿舍账户'), findsOneWidget);
    });

    testWidgets('曲线卡能渲染 30 天数据且不抛异常', (tester) async {
      final records = List.generate(30, (index) {
        return UsageRecord(
          statTime: DateTime(2026, 10, 6 + index),
          kwh: 1 + index % 5,
          cost: 0.6 * (1 + index % 5),
          recharge: index == 20 ? 20 : 0,
          balance: 60 - index.toDouble(),
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 360,
              child: UsageChartCard(
                records: records,
                metric: UsageMetric.balance,
                highlightedDate: records.last.statTime,
                onMetricChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('趋势'), findsOneWidget);
    });
  });
}
