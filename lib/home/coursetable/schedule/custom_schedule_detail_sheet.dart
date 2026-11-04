import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'custom_schedule_event.dart';

/// 日程详情弹层（由课表页通过 `showGlassDraggableSheet` 打开）。
class CustomScheduleDetailSheet extends StatelessWidget {
  const CustomScheduleDetailSheet({
    super.key,
    required this.event,
    required this.scrollController,
    required this.onEdit,
    required this.onDelete,
  });

  final CustomScheduleEvent event;
  final ScrollController scrollController;
  final VoidCallback onEdit;
  final Future<void> Function() onDelete;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final DateFormat timeFormat = DateFormat('HH:mm');

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
      children: <Widget>[
        Row(
          children: <Widget>[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: event.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(event.title, style: theme.textTheme.titleLarge),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _DetailRow(
          icon: Icons.event_outlined,
          text:
              '${scheduleFormatDate(event.start)}  '
              '${timeFormat.format(event.start)}–${timeFormat.format(event.end)}',
        ),
        if (event.location.isNotEmpty)
          _DetailRow(icon: Icons.place_outlined, text: event.location),
        if (event.note.isNotEmpty)
          _DetailRow(icon: Icons.notes_outlined, text: event.note),
        _DetailRow(
          icon: Icons.event_repeat_outlined,
          text: event.describeRepeat(),
        ),
        const SizedBox(height: 8),
        Row(
          children: <Widget>[
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('编辑'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () async {
                  final bool? confirmed = await showDialog<bool>(
                    context: context,
                    builder:
                        (BuildContext dialogContext) => AlertDialog(
                          title: const Text('删除日程'),
                          content: const Text('删除后不可恢复。'),
                          actions: <Widget>[
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(false),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed:
                                  () => Navigator.of(dialogContext).pop(true),
                              child: const Text('删除'),
                            ),
                          ],
                        ),
                  );
                  if (confirmed != true) return;
                  await onDelete();
                  if (context.mounted) Navigator.of(context).pop();
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: const Text('删除'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(text),
    );
  }
}
