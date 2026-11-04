import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/pages/health/health_score_models.dart';
import 'package:superhut/pages/health/health_score_parser.dart';

const String _termPage = '''
<html><head><title>历年体测查询</title></head>
<body>
  <h2 class="title ui-border-b">
    学号：20230001<a class="ui-btn" href="/weixin/main.jsp">返回首页</a>
  </h2>
  <table class="ui-table ui-border">
    <thead>
      <tr>
        <th width="30%"><b>学年</b></th>
        <th width="13%"><b>年级</b></th>
        <th width="13%"><b>加分</b></th>
        <th width="14%"><b>得分</b></th>
        <th width="15%"><b>等级</b></th>
        <th width="15%"><b>详情</b></th>
      </tr>
    </thead>
    <tbody>
      <tr>
        <td>
          2025-2026-1
        </td>
        <td>43</td><td>0</td><td>31.0</td><td>不及格</td>
        <td><a href="/spQuery?method=scoreDetails&schoolid=100001&stuNo=MjAyMzAwMDE=&year=2025-2026&term=1">查看</a></td>
      </tr>
      <tr>
        <td>2026-2027-1</td>
        <td>44</td><td>0</td><td>22.0</td><td>不及格</td>
        <td><a href="/spQuery?method=scoreDetails&schoolid=100001&stuNo=MjAyMzAwMDE=&year=2026-2027&term=1">查看</a></td>
      </tr>
    </tbody>
  </table>
</body></html>
''';

const String _mainPage = '''
<html><body>
<form name="myform" method="post" action="">
  <input type="hidden" name="method" value="" >
  <input type="hidden" name="stuNo" value="MjAyMzAwMDE=" >
  <input type="hidden" name="schoolid" value="100001" >
</form>
</body></html>
''';

const String _detailPage = '''
<html><body>
<table class="info"><tr><td>姓名</td><td>张三</td></tr></table>
<table class="ui-table">
  <thead>
    <tr>
      <th>项目</th><th>成绩</th><th>得分</th><th>等级</th>
    </tr>
  </thead>
  <tbody>
    <tr><td>身高</td><td>175.0</td><td>100</td><td>优秀</td></tr>
    <tr><td>体重</td><td>65.0</td><td>100</td><td>优秀</td></tr>
    <tr><td>肺活量</td><td>4200</td><td>90</td><td>优秀</td></tr>
    <tr><td>50米跑</td><td>7.2</td><td>80</td><td>良好</td></tr>
    <tr><td>立定跳远</td><td>2.45</td><td>78</td><td>及格</td></tr>
    <tr><td>坐位体前屈</td><td>12.5</td><td>72</td><td>及格</td></tr>
    <tr><td>1000米跑</td><td>4'10"</td><td>70</td><td>及格</td></tr>
    <tr><td>引体向上</td><td>10</td><td>60</td><td>及格</td></tr>
  </tbody>
</table>
</body></html>
''';

const String _detailFemalePage = '''
<html><body>
<table>
  <tr><th>项目</th><th>成绩</th><th>得分</th><th>等级</th></tr>
  <tr><td>身高</td><td>162</td><td>100</td><td>优秀</td></tr>
  <tr><td>800米跑</td><td>3'50"</td><td>76</td><td>及格</td></tr>
  <tr><td>仰卧起坐</td><td>42</td><td>80</td><td>良好</td></tr>
</table>
</body></html>
''';

void main() {
  group('main.jsp 表单', () {
    test('读取 base64 学号与 schoolid', () {
      final form = parseMainForm(_mainPage);
      expect(form, isNotNull);
      expect(form!.stuNo, 'MjAyMzAwMDE=');
      expect(form.schoolId, '100001');
    });

    test('缺少 stuNo 时返回 null', () {
      expect(parseMainForm('<html><body>没有表单</body></html>'), isNull);
      expect(parseMainForm(''), isNull);
    });

    test('标题学号兼容全角冒号', () {
      expect(parseHealthStudentNo(_termPage), '20230001');
      expect(parseHealthStudentNo('<div>学号: 20230001</div>'), '20230001');
    });
  });

  group('历年成绩表', () {
    test('按列名映射并保留服务端顺序', () {
      final records = parseTermRecords(_termPage);
      expect(records, hasLength(2));

      expect(records[0].label, '2025-2026-1');
      expect(records[0].year, '2025-2026');
      expect(records[0].term, '1');
      expect(records[0].grade, '43');
      expect(records[0].bonus, '0');
      expect(records[0].score, 31.0);
      expect(records[0].level, '不及格');

      expect(records[1].year, '2026-2027');
      expect(records[1].score, 22.0);
    });

    test('列顺序变化不影响解析', () {
      const html = '''
<table><thead><tr><th>等级</th><th>得分</th><th>学年</th></tr></thead>
<tbody><tr><td>良好</td><td>82</td><td>2024-2025-2</td></tr></tbody></table>
''';
      final records = parseTermRecords(html);
      expect(records.single.level, '良好');
      expect(records.single.score, 82);
      expect(records.single.year, '2024-2025');
      expect(records.single.term, '2');
    });

    test('没有详情链接时从学年文字拆 year/term', () {
      const html = '''
<table><tr><th>学年</th><th>得分</th></tr>
<tr><td>2023-2024-2</td><td>65.5</td></tr></table>
''';
      final records = parseTermRecords(html);
      expect(records.single.label, '2023-2024-2');
      expect(records.single.year, '2023-2024');
      expect(records.single.term, '2');
      expect(records.single.score, 65.5);
    });

    test('空表返回空列表，页面明确「暂无」也不抛错', () {
      const html = '''
<table><thead><tr><th>学年</th><th>得分</th><th>等级</th></tr></thead><tbody></tbody></table>
''';
      expect(parseTermRecords(html), isEmpty);
      expect(parseTermRecords('<div>暂无体测记录</div>'), isEmpty);
    });

    test('表头用 td 而不是 th 也能识别', () {
      const html = '''
<table>
  <tr><td>学年</td><td>年级</td><td>加分</td><td>得分</td><td>等级</td><td>详情</td></tr>
  <tr>
    <td>2025-2026-1</td><td>43</td><td>0</td><td>31.0</td><td>不及格</td>
    <td><a href="/spQuery?method=scoreDetails&year=2025-2026&term=1">查看</a></td>
  </tr>
</table>
''';
      final records = parseTermRecords(html);
      expect(records, hasLength(1));
      expect(records.single.label, '2025-2026-1');
      expect(records.single.score, 31);
      expect(records.single.level, '不及格');
    });

    test('每个学年一张小表时合并所有记录', () {
      const html = '''
<table>
  <tr><td>学年</td><td>得分</td><td>等级</td></tr>
  <tr><td>2024-2025-1</td><td>70</td><td>及格</td></tr>
</table>
<table>
  <tr><td>学年</td><td>得分</td><td>等级</td></tr>
  <tr><td>2025-2026-1</td><td>82</td><td>良好</td></tr>
  <tr><td>2026-2027-1</td><td>88</td><td>良好</td></tr>
</table>
''';
      final records = parseTermRecords(html);
      expect(records.map((record) => record.label).toList(), [
        '2024-2025-1',
        '2025-2026-1',
        '2026-2027-1',
      ]);
      expect(records.last.score, 88);
    });

    test('无法识别的页面抛解析异常', () {
      expect(
        () => parseTermRecords('<html><body>系统维护中</body></html>'),
        throwsA(isA<HealthParseException>()),
      );
      expect(() => parseTermRecords(''), throwsA(isA<HealthParseException>()));
    });
  });

  group('详情项目表', () {
    test('男生的项目按行序完整保留', () {
      final table = parseDetailTable(_detailPage);
      expect(table.positional, isFalse);
      expect(table.columns, ['项目', '成绩', '得分', '等级']);
      expect(table.rows, hasLength(8));
      expect(table.rows[6][0], '1000米跑');
      expect(table.rows[7][0], '引体向上');
    });

    test('女生的项目不会被过滤或改写成男生项', () {
      final table = parseDetailTable(_detailFemalePage);
      expect(table.rows.map((row) => row[0]).toList(), ['身高', '800米跑', '仰卧起坐']);
      expect(table.rows[1][1], "3'50\"");
    });

    test('没有表头时按位置模式出兜底列名', () {
      const html = '''
<table>
  <tr><td>身高</td><td>175</td><td>100</td><td>优秀</td></tr>
  <tr><td>800米跑</td><td>3'40"</td><td>78</td><td>及格</td></tr>
</table>
''';
      final table = parseDetailTable(html);
      expect(table.positional, isTrue);
      expect(table.columns.take(4).toList(), ['项目', '成绩', '得分', '等级']);
      expect(table.rows, hasLength(2));
      expect(table.rows[1][0], '800米跑');
    });

    test('真实页面：colspan 表头 + 嵌套进度条 + 整行图例', () {
      const html = '''
<table width="100%" border="0">
  <tr bgcolor="#3388CC" align="center">
    <td width="30%" colspan="2"><strong>体测项目</strong></td>
    <td width="22%" colspan="2"><strong>成绩</strong></td>
    <td width="33%" colspan="2"><strong>得分</strong></td>
    <td width="15%"><strong>等级</strong></td>
  </tr>
  <tr>
    <td><img src="score_sg.gif"></td><td>身高</td><td>172.0</td><td>厘米</td>
    <td colspan="3"></td>
  </tr>
  <tr>
    <td><img src="score_tz.gif"></td><td>体重</td><td>63.9</td><td>公斤</td>
    <td>100</td>
    <td><table><tr><td>100</td></tr></table></td>
    <td>正常</td>
  </tr>
  <tr>
    <td><img src="score_fh.gif"></td><td>肺活量</td><td>3005</td><td>毫升</td>
    <td>40</td>
    <td><table><tr><td>40</td></tr></table></td>
    <td>不及格</td>
  </tr>
  <tr>
    <td colspan="2"><strong>成绩总分</strong></td>
    <td>&nbsp;</td><td>&nbsp;</td>
    <td>22.0</td>
    <td><table><tr><td>22.0</td></tr></table></td>
    <td><strong>不及格</strong></td>
  </tr>
  <tr>
    <td colspan="7">
      <table><tr><td>不及格/肥胖</td><td>及格/超重</td></tr></table>
    </td>
  </tr>
</table>
''';
      final table = parseDetailTable(html);
      expect(table.positional, isFalse);
      expect(table.columns, ['项目', '成绩', '单位', '得分', '等级']);
      expect(table.rows, hasLength(4));
      expect(table.rows[0], ['身高', '172.0', '厘米', '-', '']);
      expect(table.rows[1], ['体重', '63.9', '公斤', '100', '正常']);
      expect(table.rows[2], ['肺活量', '3005', '毫升', '40', '不及格']);
      expect(table.rows[3], ['成绩总分', '', '', '22.0', '不及格']);
    });

    test('整行合并的说明行会被跳过', () {
      const html = '''
<table>
  <tr><th>项目</th><th>成绩</th><th>得分</th><th>等级</th></tr>
  <tr><td>身高</td><td>175</td><td>100</td><td>优秀</td></tr>
  <tr><td colspan="4">总分：78</td></tr>
</table>
''';
      final table = parseDetailTable(html);
      expect(table.positional, isFalse);
      expect(table.rows, hasLength(1));
      expect(table.rows.single.first, '身高');
    });

    test('优先选择带「项目」表头的明细表', () {
      const html = '''
<table><tr><th>姓名</th><th>学院</th></tr><tr><td>张三</td><td>计算机</td></tr></table>
<table><tr><th>项目</th><th>成绩</th></tr><tr><td>肺活量</td><td>4000</td></tr></table>
''';
      final table = parseDetailTable(html);
      expect(table.columns, ['项目', '成绩']);
      expect(table.rows, hasLength(1));
      expect(table.rows.single[0], '肺活量');
    });

    test('空白单元格被清洗，空行被丢弃', () {
      const html = '''
<table>
  <tr><th>项目</th><th>成绩</th></tr>
  <tr><td>&nbsp;\r\n 身高 </td><td> 175.0 </td></tr>
  <tr><td></td><td></td></tr>
</table>
''';
      final table = parseDetailTable(html);
      expect(table.rows, hasLength(1));
      expect(table.rows.single, ['身高', '175.0']);
    });

    test('空 HTML 或无表页面抛解析异常', () {
      expect(() => parseDetailTable(''), throwsA(isA<HealthParseException>()));
      expect(
        () => parseDetailTable('<html><body>暂无数据</body></html>'),
        throwsA(isA<HealthParseException>()),
      );
    });
  });

  group('展示辅助', () {
    test('分数格式化', () {
      expect(formatHealthScore(31), '31');
      expect(formatHealthScore(31.5), '31.5');
      expect(formatHealthScore(null), '--');
    });

    test('等级色调优先按分数判断', () {
      expect(
        healthLevelTone(score: 95, level: '不及格'),
        HealthLevelTone.excellent,
      );
      expect(healthLevelTone(score: 85), HealthLevelTone.good);
      expect(healthLevelTone(score: 60), HealthLevelTone.pass);
      expect(healthLevelTone(score: 59.9), HealthLevelTone.fail);
      expect(healthLevelTone(level: '良好'), HealthLevelTone.good);
      expect(healthLevelTone(), HealthLevelTone.unknown);
    });

    test('最新记录取学年学期最大的一条', () {
      final records = parseTermRecords(_termPage);
      final snapshot = HealthScoreSnapshot(
        studentNo: '20230001',
        schoolId: '100001',
        records: records,
      );
      expect(snapshot.latest!.label, '2026-2027-1');
      expect(snapshot.recordsByOldest.first.label, '2025-2026-1');
    });
  });
}
