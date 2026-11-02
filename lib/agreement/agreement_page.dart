import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../theme/glass/glass_scaffold.dart';
import 'agreement_documents.dart';
import 'agreement_markdown_view.dart';

/// 协议阅读页：从 `assets/*.md` 读正文，按极简 Markdown 渲染。
///
/// 同时被启动同意页与「我的」页的入口复用。
class AgreementPage extends StatefulWidget {
  const AgreementPage({super.key, required this.document});

  final AgreementDocument document;

  @override
  State<AgreementPage> createState() => _AgreementPageState();
}

class _AgreementPageState extends State<AgreementPage> {
  late Future<String> _markdown;

  @override
  void initState() {
    super.initState();
    _markdown = _load();
  }

  Future<String> _load() => rootBundle.loadString(widget.document.assetPath);

  void _retry() => setState(() => _markdown = _load());

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      title: widget.document.title,
      body: FutureBuilder<String>(
        future: _markdown,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final String? markdown = snapshot.data;
          if (snapshot.hasError ||
              markdown == null ||
              markdown.trim().isEmpty) {
            return _buildError(context, snapshot.error);
          }
          return ListView(
            // 顶部留出悬浮顶栏的位置，正文可以滚到玻璃下方形成 scroll edge。
            padding: EdgeInsets.fromLTRB(
              20,
              12 + glassTopInset(context),
              20,
              48,
            ),
            children: <Widget>[
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      AgreementMarkdownView(markdown: markdown),
                      const SizedBox(height: 16),
                      Text(
                        '版本：${AgreementDocuments.version}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Object? error) {
    final ThemeData theme = Theme.of(context);
    if (error != null) {
      debugPrint('协议 ${widget.document.assetPath} 读取失败：$error');
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.description_outlined,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text('协议加载失败', style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              '请检查网络或重新安装后重试',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(onPressed: _retry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}
