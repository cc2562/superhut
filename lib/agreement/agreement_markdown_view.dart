import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 协议正文的极简 Markdown 渲染。
///
/// 只支持本项目两份协议实际用到的语法：
/// * `#` / `##` 标题
/// * `**加粗**`
/// * `- ` 无序列表
/// * 空行分段
/// * `[文字](url)` 链接（用 `url_launcher` 在外部浏览器打开）
///
/// 其它语法一律按纯文本渲染，不会吞掉内容。**新增协议条款时请勿超出该子集**，
/// 否则需要同步扩展 [parseAgreementMarkdown] 与 [_AgreementMarkdownView]。
///
/// 之所以不引入 `flutter_markdown`：它已停止维护，为一个静态协议页引入社区
/// 分支或自建完整解析器都不划算，这四类语法已覆盖协议排版需求。
List<AgreementBlock> parseAgreementMarkdown(String source) {
  final List<AgreementBlock> blocks = <AgreementBlock>[];
  final List<String> paragraph = <String>[];

  void flushParagraph() {
    if (paragraph.isEmpty) return;
    blocks.add(AgreementParagraph(paragraph.join(' ')));
    paragraph.clear();
  }

  for (final String rawLine in source.split('\n')) {
    final String line = rawLine.trim();
    if (line.isEmpty) {
      flushParagraph();
      continue;
    }
    if (line.startsWith('## ')) {
      flushParagraph();
      blocks.add(AgreementHeading(line.substring(3).trim(), 2));
      continue;
    }
    if (line.startsWith('# ')) {
      flushParagraph();
      blocks.add(AgreementHeading(line.substring(2).trim(), 1));
      continue;
    }
    if (line.startsWith('- ')) {
      flushParagraph();
      blocks.add(AgreementBullet(line.substring(2).trim()));
      continue;
    }
    paragraph.add(line);
  }
  flushParagraph();
  return blocks;
}

/// 解析后的一个块。用 sealed 保证渲染处穷尽所有类型。
sealed class AgreementBlock {
  const AgreementBlock(this.text);

  final String text;
}

class AgreementHeading extends AgreementBlock {
  const AgreementHeading(super.text, this.level);

  /// 1 = 文档标题，2 = 小节标题。
  final int level;
}

class AgreementParagraph extends AgreementBlock {
  const AgreementParagraph(super.text);
}

class AgreementBullet extends AgreementBlock {
  const AgreementBullet(super.text);
}

/// 把 Markdown 文本渲染成可滚动的正文组件（自身不滚动，由外层列表负责）。
class AgreementMarkdownView extends StatelessWidget {
  const AgreementMarkdownView({super.key, required this.markdown});

  final String markdown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final List<AgreementBlock> blocks = parseAgreementMarkdown(markdown);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final AgreementBlock block in blocks)
          _buildBlock(context, theme, block),
      ],
    );
  }

  Widget _buildBlock(
    BuildContext context,
    ThemeData theme,
    AgreementBlock block,
  ) {
    switch (block) {
      case AgreementHeading(level: 1):
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Text.rich(
            TextSpan(
              children: _inlineSpans(
                context,
                theme,
                block.text,
                theme.textTheme.headlineSmall,
              ),
            ),
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        );
      case AgreementHeading():
        return Padding(
          padding: const EdgeInsets.only(top: 24, bottom: 10),
          child: Text.rich(
            TextSpan(
              children: _inlineSpans(
                context,
                theme,
                block.text,
                theme.textTheme.titleMedium,
              ),
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        );
      case AgreementParagraph():
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text.rich(
            TextSpan(
              children: _inlineSpans(
                context,
                theme,
                block.text,
                theme.textTheme.bodyMedium,
              ),
            ),
            style: theme.textTheme.bodyMedium?.copyWith(
              height: 1.7,
              color: theme.colorScheme.onSurface,
            ),
          ),
        );
      case AgreementBullet():
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(top: 1, right: 8),
                child: Text(
                  '•',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: _inlineSpans(
                      context,
                      theme,
                      block.text,
                      theme.textTheme.bodyMedium,
                    ),
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.7,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
        );
    }
  }

  /// 行内解析：`**加粗**` 与 `[文字](url)`，其余按纯文本。
  ///
  /// 链接用 [WidgetSpan] 而不是 `TapGestureRecognizer`，避免为每个链接维护
  /// 手势识别器的生命周期（忘了 dispose 就会泄漏）。
  List<InlineSpan> _inlineSpans(
    BuildContext context,
    ThemeData theme,
    String text,
    TextStyle? baseStyle,
  ) {
    final List<InlineSpan> spans = <InlineSpan>[];
    final RegExp pattern = RegExp(r'\*\*(.+?)\*\*|\[([^\]]+)\]\(([^)]+)\)');
    int cursor = 0;

    for (final RegExpMatch match in pattern.allMatches(text)) {
      if (match.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, match.start)));
      }
      final String? bold = match.group(1);
      if (bold != null) {
        spans.add(
          TextSpan(
            text: bold,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        );
      } else {
        final String label = match.group(2) ?? '';
        final String url = match.group(3) ?? '';
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: GestureDetector(
              onTap: () => _openLink(context, url),
              child: Text(
                label,
                style: (baseStyle ?? theme.textTheme.bodyMedium)?.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                  decorationColor: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        );
      }
      cursor = match.end;
    }

    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return spans;
  }

  Future<void> _openLink(BuildContext context, String url) async {
    // 先取 messenger，避免 await 之后再用 context（异步间隙里页面可能已销毁）。
    final ScaffoldMessengerState? messenger = ScaffoldMessenger.maybeOf(
      context,
    );
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) return;
    try {
      final bool opened = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!opened) {
        messenger?.showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
      }
    } catch (error) {
      debugPrint('打开协议链接失败：$error');
      messenger?.showSnackBar(SnackBar(content: Text('无法打开链接：$url')));
    }
  }
}
