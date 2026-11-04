import 'dart:async';

import 'package:flutter/material.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_api.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_store.dart';
import 'package:superhut/theme/glass/glass_overlays.dart';

/// 打开账户弹层；返回值是用户最终选中的 `acguid`（未变更时返回原值）。
Future<String?> showElectricityAccountPicker({
  required BuildContext context,
  required ElectricityHistoryApi api,
  required ElectricityHistoryStore store,
  required String? selectedId,
}) {
  return showGlassSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder:
        (sheetContext) => _AccountPickerSheet(
          api: api,
          store: store,
          selectedId: selectedId,
        ),
  );
}

class _AccountPickerSheet extends StatefulWidget {
  const _AccountPickerSheet({
    required this.api,
    required this.store,
    required this.selectedId,
  });

  final ElectricityHistoryApi api;
  final ElectricityHistoryStore store;
  final String? selectedId;

  @override
  State<_AccountPickerSheet> createState() => _AccountPickerSheetState();
}

class _AccountPickerSheetState extends State<_AccountPickerSheet> {
  static const Duration _debounce = Duration(milliseconds: 350);

  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  List<ElectricityAccount> _bound = const [];
  List<ElectricityAccount> _results = const [];
  String _query = '';
  int _total = 0;
  int _page = 1;
  bool _searching = false;
  bool _loadingMore = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBound();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBound() async {
    final accounts = await widget.store.loadAccounts();
    if (!mounted) return;
    setState(() => _bound = accounts);
  }

  void _onQueryChanged(String value) {
    setState(() {
      _query = value.trim();
      _error = null;
    });
    _debounceTimer?.cancel();
    if (_query.isEmpty) {
      setState(() {
        _results = const [];
        _total = 0;
      });
      return;
    }
    _debounceTimer = Timer(_debounce, () => _search(page: 1));
  }

  Future<void> _search({required int page}) async {
    if (_query.isEmpty) return;
    setState(() {
      if (page == 1) {
        _searching = true;
      } else {
        _loadingMore = true;
      }
      _error = null;
    });

    try {
      final result = await widget.api.searchAccounts(_query, page: page);
      if (!mounted) return;
      setState(() {
        _page = page;
        _total = result.total;
        _results =
            page == 1 ? result.accounts : [..._results, ...result.accounts];
      });
    } on ElectricityHistoryAuthException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } on ElectricityHistoryException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = '搜索失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() {
          _searching = false;
          _loadingMore = false;
        });
      }
    }
  }

  Future<void> _bind(ElectricityAccount account) async {
    await widget.store.upsertAccount(account);
    if (!mounted) return;
    Navigator.of(context).pop(account.acguid);
  }

  Future<void> _unbind(ElectricityAccount account) async {
    final confirmed = await showGlassDialog<bool>(
      context: context,
      title: const Text('解除绑定'),
      content: Text('不再保留「${account.name}」，之后需要重新搜索绑定。'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('解除'),
        ),
      ],
    );
    if (confirmed != true) return;
    await widget.store.removeAccount(account.acguid);
    await _loadBound();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;
    // 键盘弹出时弹层还要让出空间，否则内容会超出屏幕。
    final height = (screenHeight * 0.68 - keyboard)
        .clamp(280.0, screenHeight * 0.68)
        .toDouble();

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: SizedBox(
        height: height,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '宿舍账户',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const Spacer(),
                if (_bound.isNotEmpty)
                  Text(
                    '已绑定 ${_bound.length} 个',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '搜索房间名或账户号，绑定后可直接切换查看',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _search(page: 1),
              style: TextStyle(fontSize: 14, color: scheme.onSurface),
              decoration: InputDecoration(
                hintText: '例如 402 或 河西西苑08栋',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: scheme.surfaceContainerHighest,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: scheme.error),
                ),
              ),
            const SizedBox(height: 8),
            Expanded(child: _buildList(context, scheme)),
          ],
        ),
      ),
    );
  }

  Widget _buildList(BuildContext context, ColorScheme scheme) {
    if (_query.isEmpty) {
      if (_bound.isEmpty) {
        return _Hint(
          icon: Icons.search_rounded,
          text: '还没有绑定账户\n输入房间名或账户号开始搜索',
          color: scheme.onSurfaceVariant,
        );
      }
      return ListView.builder(
        padding: EdgeInsets.zero,
        itemCount: _bound.length,
        itemBuilder: (context, index) {
          final account = _bound[index];
          final selected = account.acguid == widget.selectedId;
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            leading: Icon(
              Icons.electric_meter_outlined,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: Text(
              account.name.isEmpty ? account.acid : account.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: scheme.onSurface,
              ),
            ),
            subtitle: Text(
              '余额 ¥${account.balance.toStringAsFixed(2)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            trailing:
                selected
                    ? Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '当前',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onPrimaryContainer,
                        ),
                      ),
                    )
                    : IconButton(
                      tooltip: '解除绑定',
                      iconSize: 18,
                      icon: Icon(
                        Icons.link_off_rounded,
                        color: scheme.onSurfaceVariant,
                      ),
                      onPressed: () => _unbind(account),
                    ),
            onTap: () => Navigator.of(context).pop(account.acguid),
          );
        },
      );
    }

    if (_searching) {
      return Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.4,
            color: scheme.primary,
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return _Hint(
        icon: Icons.search_off_rounded,
        text: _error == null ? '没有找到匹配的账户' : '加载失败，请重新搜索',
        color: scheme.onSurfaceVariant,
      );
    }

    final canLoadMore = _results.length < _total;
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: _results.length + (canLoadMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _results.length) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: TextButton(
                onPressed:
                    _loadingMore ? null : () => _search(page: _page + 1),
                child:
                    _loadingMore
                        ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : Text('加载更多（${_results.length}/$_total）'),
              ),
            ),
          );
        }
        final account = _results[index];
        final bound = _bound.any((item) => item.acguid == account.acguid);
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4),
          leading: Icon(
            bound ? Icons.electric_meter : Icons.add_circle_outline,
            color: bound ? scheme.primary : scheme.onSurfaceVariant,
          ),
          title: Text(
            account.name.isEmpty ? account.acid : account.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: scheme.onSurface,
            ),
          ),
          subtitle: Text(
            '账户 ${account.acid} · 余额 ¥${account.balance.toStringAsFixed(2)}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          trailing: Text(
            bound ? '已绑定' : '绑定',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: bound ? scheme.onSurfaceVariant : scheme.primary,
            ),
          ),
          onTap: () => _bind(account),
        );
      },
    );
  }
}

class _Hint extends StatelessWidget {
  const _Hint({required this.icon, required this.text, required this.color});

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 36, color: color.withValues(alpha: 0.6)),
          const SizedBox(height: 10),
          Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12.5, height: 1.6, color: color),
          ),
        ],
      ),
    );
  }
}
