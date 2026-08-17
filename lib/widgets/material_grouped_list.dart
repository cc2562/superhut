import 'package:flutter/material.dart';

/// Material 3 grouped list with a shared rounded outline and tonal seams.
class MaterialGroupedList extends StatelessWidget {
  const MaterialGroupedList({
    super.key,
    required this.children,
    this.borderRadius = 24,
    this.gap = 2,
  });

  final List<Widget> children;
  final double borderRadius;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(borderRadius),
      clipBehavior: Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) SizedBox(height: gap),
            children[index],
          ],
        ],
      ),
    );
  }
}

/// Tonal surface used by an item inside [MaterialGroupedList].
class MaterialGroupedListItem extends StatelessWidget {
  const MaterialGroupedListItem({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerLow,
      child: child,
    );
  }
}
