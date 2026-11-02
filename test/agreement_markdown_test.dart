import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:superhut/agreement/agreement_documents.dart';
import 'package:superhut/agreement/agreement_markdown_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('解析标题层级、加粗段落、无序列表与空行分段', () {
    const String source = '''
# 超级包菜 用户协议

**发布日期：2026年11月2日**

## 1. 服务说明

- 第一条
- 第二条

正文 [项目主页](https://github.com/cc2562/superhut) 结束
''';

    final List<AgreementBlock> blocks = parseAgreementMarkdown(source);

    expect(blocks.length, 6);
    expect(blocks[0], isA<AgreementHeading>());
    expect((blocks[0] as AgreementHeading).level, 1);
    expect(blocks[0].text, '超级包菜 用户协议');

    expect(blocks[1], isA<AgreementParagraph>());
    expect(blocks[1].text, '**发布日期：2026年11月2日**');

    expect((blocks[2] as AgreementHeading).level, 2);
    expect(blocks[2].text, '1. 服务说明');

    expect((blocks[3] as AgreementBullet).text, '第一条');
    expect((blocks[4] as AgreementBullet).text, '第二条');

    expect(blocks[5], isA<AgreementParagraph>());
    expect(blocks[5].text, contains('项目主页'));
  });

  test('连续多行合并成同一个段落', () {
    final List<AgreementBlock> blocks = parseAgreementMarkdown(
      '第一行\n第二行\n\n新段落',
    );

    expect(blocks.length, 2);
    expect(blocks[0].text, '第一行 第二行');
    expect(blocks[1].text, '新段落');
  });

  test('未支持的语法按纯文本保留，不丢内容', () {
    final List<AgreementBlock> blocks = parseAgreementMarkdown(
      '| 表格 | 不支持 |\n> 引用也不支持',
    );

    expect(blocks.length, 1);
    expect(blocks.single, isA<AgreementParagraph>());
    expect(blocks.single.text, contains('表格'));
    expect(blocks.single.text, contains('引用'));
  });

  test('两份真实协议都能解析出足够多的块且以标题开头', () async {
    for (final AgreementDocument document in AgreementDocuments.all) {
      final String markdown = await rootBundle.loadString(document.assetPath);
      final List<AgreementBlock> blocks = parseAgreementMarkdown(markdown);

      expect(
        blocks.length,
        greaterThan(10),
        reason: '${document.assetPath} 解析出的块太少，可能是 md 结构变了',
      );
      expect(blocks.first, isA<AgreementHeading>(), reason: document.assetPath);
      expect(blocks.first.text, contains('超级包菜'), reason: document.assetPath);
    }
  });
}
