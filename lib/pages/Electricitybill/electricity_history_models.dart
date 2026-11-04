import 'package:flutter/foundation.dart';

/// 把接口返回的字符串金额/电量安全转成 double。
///
/// 接口里所有数值都是字符串（`"0.9630"`、`"51.71"`），也可能返回 `null` 或空串。
double parseAmount(Object? value) {
  if (value == null) return 0;
  if (value is num) return value.toDouble();
  final text = value.toString().trim();
  if (text.isEmpty) return 0;
  return double.tryParse(text) ?? 0;
}

/// 与接口约定的日期格式 `yyyy-MM-dd`。
String formatApiDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year.toString().padLeft(4, '0')}-$month-$day';
}

/// 只保留年月日，避免时分秒参与比较。
DateTime dateOnly(DateTime value) => DateTime(value.year, value.month, value.day);

/// 智慧工大电费子系统（hq-nygk）里的宿舍账户。
@immutable
class ElectricityAccount {
  const ElectricityAccount({
    required this.acguid,
    required this.acid,
    required this.name,
    this.balance = 0,
    this.price = 0,
  });

  /// 账户 GUID，明细接口的 `acid` 参数要传它。
  final String acguid;

  /// 账户号（`HNGD002863`），仅用于展示/兜底。
  final String acid;

  /// 房间名，例如「河西西苑08栋402」。
  final String name;

  /// 账户余额（元）。
  final double balance;

  /// 单价（元/kWh）。
  final double price;

  bool get isValid => acguid.trim().isNotEmpty;

  /// 解析 `/Home/GetAccountInfo` 的 rows 元素（字段是大写）。
  factory ElectricityAccount.fromApiRow(Map<String, dynamic> json) {
    return ElectricityAccount(
      acguid: (json['ACGUID'] ?? '').toString().trim(),
      acid: (json['ACID'] ?? '').toString().trim(),
      name: (json['ACNAME'] ?? '').toString().trim(),
      balance: parseAmount(json['ACSUM']),
      price: parseAmount(json['price']),
    );
  }

  /// 解析本地缓存。
  factory ElectricityAccount.fromJson(Map<String, dynamic> json) {
    return ElectricityAccount(
      acguid: (json['acguid'] ?? '').toString().trim(),
      acid: (json['acid'] ?? '').toString().trim(),
      name: (json['name'] ?? '').toString().trim(),
      balance: parseAmount(json['balance']),
      price: parseAmount(json['price']),
    );
  }

  Map<String, dynamic> toJson() => {
    'acguid': acguid,
    'acid': acid,
    'name': name,
    'balance': balance,
    'price': price,
  };

  ElectricityAccount copyWith({double? balance, double? price, String? name}) {
    return ElectricityAccount(
      acguid: acguid,
      acid: acid,
      name: name ?? this.name,
      balance: balance ?? this.balance,
      price: price ?? this.price,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ElectricityAccount &&
      other.acguid == acguid &&
      other.name == name &&
      other.balance == balance &&
      other.price == price;

  @override
  int get hashCode => Object.hash(acguid, name, balance, price);
}

/// 某一天的电费日结记录。
@immutable
class UsageRecord {
  const UsageRecord({
    required this.statTime,
    required this.kwh,
    required this.cost,
    required this.recharge,
    required this.balance,
  });

  /// 统计日期（只保留年月日）。
  final DateTime statTime;

  /// 当天用电量（kWh），接口字段 `f_01_d`。
  final double kwh;

  /// 当天消费金额（元），接口字段 `usesum`。
  final double cost;

  /// 当天充值金额（元），接口字段 `paysum`。
  final double recharge;

  /// 当天账户余额（元），接口字段 `acsum`。
  final double balance;

  String get dateKey => formatApiDate(statTime);

  /// 解析 `/Home/GetAcData` 的 rows 元素（字段是小写）。
  factory UsageRecord.fromApiRow(Map<String, dynamic> json) {
    final parsed = DateTime.tryParse(
      (json['stattime'] ?? '').toString().trim(),
    );
    return UsageRecord(
      statTime: parsed == null ? DateTime(1970) : dateOnly(parsed),
      kwh: parseAmount(json['f_01_d']),
      cost: parseAmount(json['usesum']),
      recharge: parseAmount(json['paysum']),
      balance: parseAmount(json['acsum']),
    );
  }
}

/// 图表/详情指标。
enum UsageMetric { kwh, cost, balance }

extension UsageMetricX on UsageMetric {
  String get label => switch (this) {
    UsageMetric.kwh => '用电量',
    UsageMetric.cost => '消费',
    UsageMetric.balance => '余额',
  };

  String get unit => switch (this) {
    UsageMetric.kwh => 'kWh',
    _ => '元',
  };

  double valueOf(UsageRecord record) => switch (this) {
    UsageMetric.kwh => record.kwh,
    UsageMetric.cost => record.cost,
    UsageMetric.balance => record.balance,
  };

  /// 明细/气泡里的展示文本。
  String format(double value) => switch (this) {
    UsageMetric.kwh => value.toStringAsFixed(2),
    _ => '¥${value.toStringAsFixed(2)}',
  };

  /// 纵轴刻度用的紧凑文本。
  String formatAxis(double value) => switch (this) {
    UsageMetric.kwh => value >= 100
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(1),
    _ => value.toStringAsFixed(0),
  };
}

/// 时间范围快捷选项。
enum UsageRangePreset { last7Days, last30Days, thisMonth }

extension UsageRangePresetX on UsageRangePreset {
  String get label => switch (this) {
    UsageRangePreset.last7Days => '近 7 天',
    UsageRangePreset.last30Days => '近 30 天',
    UsageRangePreset.thisMonth => '本月',
  };
}

/// 具体的查询区间，首尾都包含。
@immutable
class UsageRange {
  const UsageRange({required this.start, required this.end});

  final DateTime start;
  final DateTime end;

  String get startParam => formatApiDate(start);
  String get endParam => formatApiDate(end);

  /// [now] 只在测试里注入，业务代码不传。
  factory UsageRange.of(UsageRangePreset preset, {DateTime? now}) {
    final today = dateOnly(now ?? DateTime.now());
    return switch (preset) {
      UsageRangePreset.last7Days => UsageRange(
        start: DateTime(today.year, today.month, today.day - 6),
        end: today,
      ),
      UsageRangePreset.last30Days => UsageRange(
        start: DateTime(today.year, today.month, today.day - 29),
        end: today,
      ),
      UsageRangePreset.thisMonth => UsageRange(
        start: DateTime(today.year, today.month, 1),
        end: today,
      ),
    };
  }
}

/// 区间概览数字。
@immutable
class UsageSummary {
  const UsageSummary({
    required this.totalKwh,
    required this.totalCost,
    required this.totalRecharge,
    required this.latestBalance,
    required this.days,
  });

  final double totalKwh;
  final double totalCost;
  final double totalRecharge;

  /// 区间最后一天的余额。
  final double latestBalance;

  /// 有记录的天数。
  final int days;

  double get avgKwh => days == 0 ? 0 : totalKwh / days;

  static const UsageSummary empty = UsageSummary(
    totalKwh: 0,
    totalCost: 0,
    totalRecharge: 0,
    latestBalance: 0,
    days: 0,
  );

  /// [records] 需要按日期升序，`latestBalance` 取最后一条。
  factory UsageSummary.fromRecords(List<UsageRecord> records) {
    if (records.isEmpty) return UsageSummary.empty;
    var kwh = 0.0;
    var cost = 0.0;
    var recharge = 0.0;
    for (final record in records) {
      kwh += record.kwh;
      cost += record.cost;
      recharge += record.recharge;
    }
    return UsageSummary(
      totalKwh: kwh,
      totalCost: cost,
      totalRecharge: recharge,
      latestBalance: records.last.balance,
      days: records.length,
    );
  }
}

/// 按日期升序（折线图从左到右）。
List<UsageRecord> sortUsageAsc(Iterable<UsageRecord> records) {
  return records.toList()..sort((a, b) => a.statTime.compareTo(b.statTime));
}

/// 按日期降序（明细表从上到下）。
List<UsageRecord> sortUsageDesc(Iterable<UsageRecord> records) {
  return records.toList()..sort((a, b) => b.statTime.compareTo(a.statTime));
}

/// 合并多页结果：同一天只保留一条，最终升序。
List<UsageRecord> mergeUsageRecords(Iterable<UsageRecord> records) {
  final byDate = <String, UsageRecord>{};
  for (final record in records) {
    byDate[record.dateKey] = record;
  }
  return sortUsageAsc(byDate.values);
}
