/// 体测平台默认学校编号；接口表单里的 `schoolid` 就是它。
const String kHealthDefaultSchoolId = '100001';

/// 体测等级色调。
///
/// 只用于展示配色：优先按分数区间判断，分数缺失时才退化为等级文字判断。
/// 解析阶段一律不使用项目名 / 等级文字做数据提取。
enum HealthLevelTone { excellent, good, pass, fail, unknown }

/// 一次体测记录（对应历年成绩表的一行）。
class HealthTermRecord {
  const HealthTermRecord({
    required this.year,
    required this.term,
    required this.label,
    this.grade = '',
    this.bonus = '',
    this.score,
    this.level = '',
  });

  /// 学年，如 `2025-2026`；详情链接缺失时可能退化为完整标题。
  final String year;

  /// 学期，如 `1`。
  final String term;

  /// 展示用学年学期，如 `2025-2026-1`。
  final String label;

  /// 年级（服务端原值，可能是 43 这种培养年级序号）。
  final String grade;

  /// 加分（服务端原值）。
  final String bonus;

  /// 总分；无法解析时为 null。
  final double? score;

  /// 等级（服务端原文）。
  final String level;

  bool get hasDetail => year.isNotEmpty;

  /// 详情页请求参数：学年学期缺失时返回 null。
  String? get detailYearTerm {
    if (year.isEmpty) return null;
    return term.isEmpty ? year : '$year-$term';
  }

  /// 学年学期升序：先比学年起始年，再比学期。
  static int compareAscending(HealthTermRecord a, HealthTermRecord b) {
    final byYear = _yearStart(a.year).compareTo(_yearStart(b.year));
    if (byYear != 0) return byYear;
    final byTerm = _termNumber(a.term).compareTo(_termNumber(b.term));
    if (byTerm != 0) return byTerm;
    return a.label.compareTo(b.label);
  }

  static int compareDescending(HealthTermRecord a, HealthTermRecord b) =>
      compareAscending(b, a);

  static int _yearStart(String year) {
    final match = RegExp(r'(\d{4})').firstMatch(year);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }

  static int _termNumber(String term) {
    final match = RegExp(r'(\d+)').firstMatch(term);
    return int.tryParse(match?.group(1) ?? '') ?? 0;
  }
}

/// 体测主页一次查询的结果。
class HealthScoreSnapshot {
  const HealthScoreSnapshot({
    required this.studentNo,
    required this.schoolId,
    required this.records,
  });

  /// 明文 [学号]，仅用于展示；为空时页面不显示。
  final String studentNo;

  final String schoolId;

  /// 服务端返回顺序（通常按时间升序）。
  final List<HealthTermRecord> records;

  bool get isEmpty => records.isEmpty;

  /// 按学年学期升序，供趋势图使用。
  List<HealthTermRecord> get recordsByOldest =>
      List<HealthTermRecord>.unmodifiable(
        <HealthTermRecord>[...records]..sort(HealthTermRecord.compareAscending),
      );

  /// 按学年学期倒序，供列表与总览使用。
  List<HealthTermRecord> get recordsByNewest =>
      List<HealthTermRecord>.unmodifiable(
        <HealthTermRecord>[...records]
          ..sort(HealthTermRecord.compareDescending),
      );

  HealthTermRecord? get latest => isEmpty ? null : recordsByNewest.first;
}

/// 学年详情页解析出的项目表。
class HealthDetailTable {
  const HealthDetailTable({
    required this.columns,
    required this.rows,
    required this.positional,
  });

  /// 表头；位置模式下为兜底列名（项目 / 成绩 / 得分 / 等级 / 列N）。
  final List<String> columns;

  /// 严格按服务端行序保留，不按项目名筛选；单元格已做过空白清洗。
  final List<List<String>> rows;

  /// true 表示表头不可用或列数不匹配，按「首列项目名 + 列位置」解析。
  final bool positional;

  bool get isEmpty => rows.isEmpty;
}

/// 体测总分展示：整数不带小数点，非整数保留一位。
String formatHealthScore(double? score) {
  if (score == null) return '--';
  final rounded = score.roundToDouble();
  if ((score - rounded).abs() < 0.05) return rounded.toStringAsFixed(0);
  return score.toStringAsFixed(1);
}

/// 展示用色调判断。分数优先；分数缺失时才看等级文字。
HealthLevelTone healthLevelTone({double? score, String level = ''}) {
  if (score != null) {
    if (score >= 90) return HealthLevelTone.excellent;
    if (score >= 80) return HealthLevelTone.good;
    if (score >= 60) return HealthLevelTone.pass;
    return HealthLevelTone.fail;
  }
  final text = level.trim();
  if (text.isEmpty) return HealthLevelTone.unknown;
  if (text.contains('优秀')) return HealthLevelTone.excellent;
  if (text.contains('良好')) return HealthLevelTone.good;
  if (text.contains('及格') || text.contains('合格')) {
    return HealthLevelTone.pass;
  }
  if (text.contains('不及格') || text.contains('不合格')) {
    return HealthLevelTone.fail;
  }
  return HealthLevelTone.unknown;
}
