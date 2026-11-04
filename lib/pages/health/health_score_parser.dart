import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;
import 'package:superhut/pages/health/health_score_models.dart';

/// 页面结构与预期不符时抛出，由 API 层转成用户可读的失败提示。
class HealthParseException implements Exception {
  const HealthParseException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// main.jsp 表单里的隐藏字段。
class HealthMainForm {
  const HealthMainForm({required this.stuNo, required this.schoolId});

  /// 服务端下发的 base64 学号，查询时原样回传。
  final String stuNo;

  final String schoolId;
}

/// 历年表列名别名。
///
/// 只做「列 → 字段」映射，不做项目名匹配，男女项目差异由行序承载。
const Map<String, List<String>> _termColumnAliases = <String, List<String>>{
  'label': <String>['学年学期', '学年', '学年度', '学期', '年份'],
  'grade': <String>['年级'],
  'bonus': <String>['加分', '附加分'],
  'score': <String>['得分', '总分', '分数', '成绩'],
  'level': <String>['等级', '评定等级', '评定'],
  'detail': <String>['详情', '操作', '查看'],
};

/// 详情表列名别名。
const Map<String, List<String>> _detailColumnAliases = <String, List<String>>{
  'item': <String>['测试项目', '项目名称', '项目', '指标', '测试内容', '内容'],
  'value': <String>['测试成绩', '成绩', '实测值', '测试结果', '结果', '数据', '数值'],
  'score': <String>['单项得分', '得分', '分数', '评分'],
  'level': <String>['评定等级', '等级', '评定', '评级'],
  'remark': <String>['备注', '说明'],
};

/// 详情表无可用表头时的兜底列名。
const List<String> _positionalColumns = <String>['项目', '成绩', '得分', '等级', '备注'];

/// 清洗单元格文本：去零宽字符、`&nbsp;`、换行与多余空白。
String normalizeHealthCellText(String raw) {
  var text = raw
      .replaceAll('\u200b', '')
      .replaceAll('\ufeff', '')
      .replaceAll('\u00a0', ' ')
      .replaceAll('\r', ' ')
      .replaceAll('\n', ' ')
      .replaceAll('\t', ' ');
  text = text.replaceAll(RegExp(r'\s+'), ' ').trim();
  return text;
}

/// 解析 main.jsp 的隐藏域；找不到 stuNo 时返回 null。
HealthMainForm? parseMainForm(String html) {
  if (html.trim().isEmpty) return null;
  final Document doc = html_parser.parse(html);

  String stuNo = '';
  String schoolId = '';
  for (final Element input in doc.querySelectorAll('input[name]')) {
    final String name = (input.attributes['name'] ?? '').trim().toLowerCase();
    final String value = (input.attributes['value'] ?? '').trim();
    if (name == 'stuno' && value.isNotEmpty) stuNo = value;
    if (name == 'schoolid' && value.isNotEmpty) schoolId = value;
  }
  if (stuNo.isEmpty) return null;
  return HealthMainForm(
    stuNo: stuNo,
    schoolId: schoolId.isEmpty ? kHealthDefaultSchoolId : schoolId,
  );
}

/// 从页面标题「学号：20230001」读取明文[学号]，读不到返回空串。
String parseHealthStudentNo(String html) {
  if (html.trim().isEmpty) return '';
  final Document doc = html_parser.parse(html);
  final String text = doc.body?.text ?? doc.documentElement?.text ?? '';
  final RegExpMatch? match = RegExp(
    r'学号\s*[:：]\s*([0-9A-Za-z_-]{4,})',
  ).firstMatch(text);
  return match?.group(1)?.trim() ?? '';
}

/// 解析历年成绩表。
///
/// 页面可能是「一张总表」，也可能是「每学年一张小表」；这里遍历所有带
/// 学年/得分表头的表并合并结果。行严格按服务端顺序返回。
/// 识别不到成绩表时抛 [HealthParseException]，但页面明确写了「暂无」时返回空表。
List<HealthTermRecord> parseTermRecords(String html) {
  if (html.trim().isEmpty) {
    throw const HealthParseException('体测页面为空');
  }
  final Document doc = html_parser.parse(html);
  final List<HealthTermRecord> records = <HealthTermRecord>[];
  var matchedTable = false;

  for (final Element table in doc.querySelectorAll('table')) {
    final _Header header = _readHeader(table);
    if (header.cells.isEmpty) continue;
    final Map<String, int> index = _mapHeader(header.cells, _termColumnAliases);
    if (!index.containsKey('label')) continue;
    if (!index.containsKey('score') && !index.containsKey('level')) continue;

    matchedTable = true;
    for (final Element row in _dataRows(table, headerRow: header.row)) {
      final HealthTermRecord? record = _parseTermRow(row, index);
      if (record != null) records.add(record);
    }
  }

  if (!matchedTable) {
    final String text = doc.body?.text ?? '';
    if (text.contains('暂无') || text.contains('没有体测') || text.contains('无记录')) {
      return const <HealthTermRecord>[];
    }
    throw const HealthParseException('未找到体测成绩表格');
  }

  return records;
}

HealthTermRecord? _parseTermRow(Element row, Map<String, int> index) {
  final List<Element> cells = _cells(row);
  if (cells.length < 2) return null;

  final String label = _cellText(cells, index['label']);
  final String grade = _cellText(cells, index['grade']);
  final String bonus = _cellText(cells, index['bonus']);
  final String scoreText = _cellText(cells, index['score']);
  final String level = _cellText(cells, index['level']);

  if (label.isEmpty && grade.isEmpty && scoreText.isEmpty && level.isEmpty) {
    return null;
  }

  // 详情链接比表头文字更可靠：链接里的 year/term 就是详情请求参数。
  String year = '';
  String term = '';
  final Element? detailCell = _cellAt(cells, index['detail']);
  final Element? link = detailCell?.querySelector('a[href]');
  if (link != null) {
    final Uri? uri = Uri.tryParse(link.attributes['href'] ?? '');
    if (uri != null) {
      year = (uri.queryParameters['year'] ?? '').trim();
      term = (uri.queryParameters['term'] ?? '').trim();
    }
  }

  final RegExpMatch? labelMatch = RegExp(
    r'^(\d{4})\s*[-—]\s*(\d{4})(?:\s*[-—]\s*(\d+))?',
  ).firstMatch(label);
  if (year.isEmpty && labelMatch != null) {
    year = '${labelMatch.group(1)}-${labelMatch.group(2)}';
    term = labelMatch.group(3) ?? '';
  }

  final String displayLabel =
      label.isNotEmpty ? label : (term.isEmpty ? year : '$year-$term');

  return HealthTermRecord(
    year: year,
    term: term,
    label: displayLabel,
    grade: grade,
    bonus: bonus,
    score: _parseScore(scoreText),
    level: level,
  );
}

/// 解析学年详情页的项目表。
///
/// 真实页面用 colspan 把表头分成「体测项目 / 成绩 / 得分 / 等级」四组，
/// 每组可能占 1–2 列（例如成绩列后面跟单位、得分列后面跟进度条）。
/// 这里先按 colspan 展开表头，再按组确定列位置；项目名与行序完全来自
/// 服务端，不预设男女项目清单。
HealthDetailTable parseDetailTable(String html) {
  if (html.trim().isEmpty) {
    throw const HealthParseException('体测详情页为空');
  }
  final Document doc = html_parser.parse(html);
  final List<Element> tables = doc.querySelectorAll('table').toList();
  if (tables.isEmpty) {
    throw const HealthParseException('详情页未找到项目表格');
  }

  for (final Element table in tables) {
    final List<Element> rows = _ownRows(table).toList();
    for (int i = 0; i < rows.length; i++) {
      final List<String> header = _expandRow(rows[i]);
      final List<String?> keys = header
          .map((cell) => _matchColumn(cell, _detailColumnAliases))
          .toList();
      final bool hasItem = keys.contains('item');
      final bool hasValue =
          keys.contains('value') || keys.contains('score');
      if (!hasItem || !hasValue) continue;

      final _DetailLayout? layout = _DetailLayout.fromHeader(header, keys);
      if (layout == null) continue;
      return _buildDetailTable(layout, rows.skip(i + 1));
    }
  }

  // 没有可识别的表头：保持位置模式，首列当项目名，其余列按顺序展示。
  return _parseDetailPositional(tables);
}

HealthDetailTable _buildDetailTable(
  _DetailLayout layout,
  Iterable<Element> rows,
) {
  final List<List<String>> data = <List<String>>[];
  for (final Element row in rows) {
    final List<Element> rawCells = _cells(row);
    // 整行合并的说明/图例行（例如底部的颜色图例）不当作项目。
    if (rawCells.length == 1) {
      final int span =
          int.tryParse(rawCells.first.attributes['colspan'] ?? '') ?? 1;
      if (span >= layout.columnCount) continue;
    }

    final List<String> cells = _expandRow(row);
    final String item = _textAt(cells, layout.itemIndex);
    final String value = _textAt(cells, layout.valueIndex);
    final String unit =
        layout.unitIndex == null ? '' : _textAt(cells, layout.unitIndex!);
    final String score =
        layout.scoreIndex == null ? '' : _textAt(cells, layout.scoreIndex!);
    final String level =
        layout.levelIndex == null ? '' : _textAt(cells, layout.levelIndex!);

    if (item.isEmpty && value.isEmpty && score.isEmpty && level.isEmpty) {
      continue;
    }
    // 只剩图例文字、没有项目名与分数的行直接跳过。
    if (item.isEmpty && score.isEmpty && level.isEmpty) continue;

    data.add(<String>[
      item,
      value,
      if (layout.unitIndex != null) unit,
      if (layout.scoreIndex != null) score.isEmpty ? '-' : score,
      if (layout.levelIndex != null) level,
    ]);
  }

  return HealthDetailTable(
    columns: layout.columns,
    rows: data,
    positional: false,
  );
}

HealthDetailTable _parseDetailPositional(List<Element> tables) {
  Element? selected;
  var maxCells = 0;
  for (final Element table in tables) {
    for (final Element row in _ownRows(table)) {
      final int count = _cells(row).length;
      if (count > maxCells) {
        maxCells = count;
        selected = table;
      }
    }
  }
  if (selected == null || maxCells < 2) {
    throw const HealthParseException('详情页未找到项目表格');
  }

  final int columnCount = maxCells;
  final List<String> columns = List<String>.generate(columnCount, (i) {
    if (i < _positionalColumns.length) return _positionalColumns[i];
    return '列${i + 1}';
  });

  final _Header header = _readHeader(selected);
  final List<List<String>> data = <List<String>>[];
  for (final Element row in _ownRows(selected)) {
    if (header.row != null && identical(row, header.row)) continue;
    final List<String> cells = _cells(row)
        .map((cell) => normalizeHealthCellText(cell.text))
        .toList();
    if (cells.every((text) => text.isEmpty)) continue;
    data.add(cells);
  }
  if (data.isEmpty) {
    throw const HealthParseException('详情页未找到项目数据');
  }

  return HealthDetailTable(columns: columns, rows: data, positional: true);
}

/// 详情表列布局：表头按 colspan 展开后，各组取哪一列。
class _DetailLayout {
  const _DetailLayout({
    required this.itemIndex,
    required this.valueIndex,
    required this.unitIndex,
    required this.scoreIndex,
    required this.levelIndex,
    required this.columnCount,
    required this.columns,
  });

  final int itemIndex;
  final int valueIndex;
  final int? unitIndex;
  final int? scoreIndex;
  final int? levelIndex;
  final int columnCount;
  final List<String> columns;

  static _DetailLayout? fromHeader(
    List<String> header,
    List<String?> keys,
  ) {
    final List<int> itemIndexes = <int>[];
    final List<int> valueIndexes = <int>[];
    final List<int> scoreIndexes = <int>[];
    final List<int> levelIndexes = <int>[];
    for (int i = 0; i < keys.length; i++) {
      switch (keys[i]) {
        case 'item':
          itemIndexes.add(i);
        case 'value':
          valueIndexes.add(i);
        case 'score':
          scoreIndexes.add(i);
        case 'level':
          levelIndexes.add(i);
      }
    }
    // 项目与成绩是必需组；得分/等级允许缺失（部分页面只有两列）。
    if (itemIndexes.isEmpty) return null;
    if (valueIndexes.isEmpty && scoreIndexes.isEmpty) return null;

    final int valueIndex =
        valueIndexes.isNotEmpty ? valueIndexes.first : scoreIndexes.first;
    final int? unitIndex =
        valueIndexes.length >= 2 ? valueIndexes.last : null;
    // 项目列可能分两列：第一列是图标，第二列才是项目名。
    final int itemIndex = itemIndexes.length >= 2
        ? itemIndexes.last
        : itemIndexes.first;
    final int? scoreIndex = scoreIndexes.isEmpty ? null : scoreIndexes.first;
    final int? levelIndex = levelIndexes.isEmpty ? null : levelIndexes.first;

    final List<String> columns = <String>[
      '项目',
      '成绩',
      if (unitIndex != null) '单位',
      if (scoreIndex != null) '得分',
      if (levelIndex != null) '等级',
    ];

    return _DetailLayout(
      itemIndex: itemIndex,
      valueIndex: valueIndex,
      unitIndex: unitIndex,
      scoreIndex: scoreIndex,
      levelIndex: levelIndex,
      columnCount: header.length,
      columns: columns,
    );
  }
}

String _textAt(List<String> cells, int index) {
  if (index < 0 || index >= cells.length) return '';
  return cells[index];
}

/// 按 colspan 展开一行的单元格文字，让表头与数据行对齐。
List<String> _expandRow(Element row) {
  final List<String> texts = <String>[];
  for (final Element cell in _cells(row)) {
    final String text = normalizeHealthCellText(cell.text);
    final int span = int.tryParse(cell.attributes['colspan'] ?? '') ?? 1;
    for (var i = 0; i < span; i++) {
      texts.add(text);
    }
  }
  return texts;
}

/// 表头：所在行（用于排除）与单元格文字。
class _Header {
  const _Header({required this.row, required this.cells});

  final Element? row;
  final List<String> cells;
}

/// 读取表头：优先 thead，其次第一个所有子单元都是 th 的行。
_Header _readHeader(Element table) {
  Element? headerRow;

  final Element? head = _firstChildByTag(table, 'thead');
  if (head != null) {
    headerRow = _ownRows(head).firstOrNull;
  }
  if (headerRow == null) {
    for (final Element row in _ownRows(table)) {
      final List<Element> cells = _cells(row);
      if (cells.length >= 2 && cells.every((cell) => cell.localName == 'th')) {
        headerRow = row;
        break;
      }
    }
  }
  if (headerRow == null) {
    // 有些页面用 <td> 当表头：前两行里命中两个以上列名才认，避免把
    // 「2025-2026-1 | 43 | 0 | 31.0 | 不及格」这种数据行当表头。
    for (final Element row in _ownRows(table).take(2)) {
      final List<Element> cells = _cells(row);
      if (cells.length < 2) continue;
      var matched = 0;
      for (final Element cell in cells) {
        final String text = normalizeHealthCellText(cell.text);
        if (_matchColumn(text, _termColumnAliases) != null ||
            _matchColumn(text, _detailColumnAliases) != null) {
          matched++;
        }
      }
      if (matched >= 2) {
        headerRow = row;
        break;
      }
    }
  }
  if (headerRow == null) {
    return const _Header(row: null, cells: <String>[]);
  }

  return _Header(
    row: headerRow,
    cells:
        _cells(
          headerRow,
        ).map((cell) => normalizeHealthCellText(cell.text)).toList(),
  );
}

Map<String, int> _mapHeader(
  List<String> header,
  Map<String, List<String>> aliases,
) {
  final Map<String, int> index = <String, int>{};
  for (int i = 0; i < header.length; i++) {
    final String? key = _matchColumn(header[i], aliases);
    if (key == null || index.containsKey(key)) continue;
    index[key] = i;
  }
  return index;
}

String? _matchColumn(String raw, Map<String, List<String>> aliases) {
  final String text = normalizeHealthCellText(raw).replaceAll(' ', '');
  if (text.isEmpty) return null;
  for (final MapEntry<String, List<String>> entry in aliases.entries) {
    for (final String alias in entry.value) {
      if (text == alias || text.contains(alias)) return entry.key;
    }
  }
  return null;
}

/// 表格自身的行；嵌套表格的行不算。
Iterable<Element> _ownRows(Element table) {
  return table.querySelectorAll('tr').where((row) {
    Node? node = row.parent;
    while (node != null) {
      if (node is Element && node.localName == 'table') {
        return identical(node, table);
      }
      node = node.parent;
    }
    return false;
  });
}

List<Element> _dataRows(Element table, {Element? headerRow}) {
  final List<Element> rows = <Element>[];
  for (final Element row in _ownRows(table)) {
    if (headerRow != null && identical(row, headerRow)) continue;
    final List<Element> cells = _cells(row);
    if (cells.isEmpty) continue;
    // 多行表头：全 th 的行不当作数据。
    if (cells.every((cell) => cell.localName == 'th')) continue;
    rows.add(row);
  }
  return rows;
}

List<Element> _cells(Element row) {
  return row.children
      .where((child) => child.localName == 'td' || child.localName == 'th')
      .toList();
}

Element? _firstChildByTag(Element parent, String tag) {
  for (final Element child in parent.children) {
    if (child.localName == tag) return child;
  }
  return null;
}

String _cellText(List<Element> cells, int? index) {
  if (index == null || index < 0 || index >= cells.length) return '';
  return normalizeHealthCellText(cells[index].text);
}

Element? _cellAt(List<Element> cells, int? index) {
  if (index == null || index < 0 || index >= cells.length) return null;
  return cells[index];
}

double? _parseScore(String raw) {
  final String text = raw.replaceAll(',', '').trim();
  if (text.isEmpty) return null;
  final RegExpMatch? match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(text);
  if (match == null) return null;
  return double.tryParse(match.group(0)!);
}
