import 'package:flutter/material.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:superhut/pages/Electricitybill/electricity_account_sheet.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_api.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_chart.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_models.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_store.dart';
import 'package:superhut/pages/Electricitybill/electricity_history_table.dart';
import 'package:superhut/theme/glass/glass_scaffold.dart';
import 'package:superhut/theme/glass/glass_segmented.dart';
import 'package:superhut/theme/glass/glass_top_bar.dart';

/// 用电历史：独立页面，从电费充值页进入。
///
/// 数据来自智慧工大网页版电费子系统（`hq-nygk.hut.edu.cn`），与 v8mobile 的
/// 充值链路互相独立。
class ElectricityHistoryPage extends StatefulWidget {
  const ElectricityHistoryPage({super.key});

  @override
  State<ElectricityHistoryPage> createState() => _ElectricityHistoryPageState();
}

class _ElectricityHistoryPageState extends State<ElectricityHistoryPage> {
  static const Duration _cacheTtl = Duration(minutes: 5);

  final ElectricityHistoryApi _api = ElectricityHistoryApi();
  final ElectricityHistoryStore _store = ElectricityHistoryStore();
  final Map<String, _UsageCache> _cache = {};

  List<ElectricityAccount> _accounts = const [];
  String? _selectedId;
  UsageRangePreset _preset = UsageRangePreset.last30Days;
  UsageMetric _metric = UsageMetric.kwh;
  List<UsageRecord> _records = const [];
  UsageSummary _summary = UsageSummary.empty;
  DateTime? _highlighted;
  String? _error;
  bool _booting = true;
  bool _loading = false;
  int _requestSeq = 0;

  ElectricityAccount? get _currentAccount {
    final id = _selectedId;
    if (id != null) {
      for (final account in _accounts) {
        if (account.acguid == id) return account;
      }
    }
    return _accounts.isEmpty ? null : _accounts.first;
  }

  double get _balance {
    final account = _currentAccount;
    if (_summary.days > 0) return _summary.latestBalance;
    return account?.balance ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final accounts = await _store.loadAccounts();
    final storedId = await _store.loadSelectedId();
    final resolved = ElectricityHistoryStore.resolveSelectedId(
      accounts,
      storedId,
    );
    if (!mounted) return;
    setState(() {
      _accounts = accounts;
      _selectedId = resolved;
      _booting = false;
    });
    if (resolved != null) {
      await _loadUsage();
    }
  }

  Future<void> _loadUsage({bool force = false}) async {
    final account = _currentAccount;
    if (account == null) {
      if (!mounted) return;
      setState(() {
        _records = const [];
        _summary = UsageSummary.empty;
        _loading = false;
        _error = null;
      });
      return;
    }

    final range = UsageRange.of(_preset);
    final cacheKey =
        '${account.acguid}|${range.startParam}|${range.endParam}';
    final cached = _cache[cacheKey];
    if (!force &&
        cached != null &&
        DateTime.now().difference(cached.createdAt) < _cacheTtl) {
      setState(() {
        _records = cached.records;
        _summary = UsageSummary.fromRecords(cached.records);
        _error = null;
        _loading = false;
      });
      return;
    }

    final seq = ++_requestSeq;
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final records = await _api.fetchUsage(
        acguid: account.acguid,
        range: range,
      );
      if (!mounted || seq != _requestSeq) return;
      _cache[cacheKey] = _UsageCache(records, DateTime.now());
      setState(() {
        _records = records;
        _summary = UsageSummary.fromRecords(records);
        _highlighted = null;
      });
      await _syncBalance(account, records);
    } on ElectricityHistoryAuthException catch (error) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _error = error.message);
    } on ElectricityHistoryException catch (error) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _error = error.message);
    } catch (_) {
      if (!mounted || seq != _requestSeq) return;
      setState(() => _error = '加载失败，请稍后重试');
    } finally {
      if (mounted && seq == _requestSeq) {
        setState(() => _loading = false);
      }
    }
  }

  /// 明细里最后一天的余额才是真实余额，顺手写回本地缓存。
  Future<void> _syncBalance(
    ElectricityAccount account,
    List<UsageRecord> records,
  ) async {
    if (records.isEmpty) return;
    final latest = records.last.balance;
    if ((latest - account.balance).abs() < 0.005) return;
    final accounts = await _store.upsertAccount(
      account.copyWith(balance: latest),
    );
    if (!mounted) return;
    setState(() => _accounts = accounts);
  }

  Future<void> _selectAccount(String acguid) async {
    if (acguid == _selectedId) return;
    setState(() {
      _selectedId = acguid;
      _records = const [];
      _summary = UsageSummary.empty;
      _highlighted = null;
      _error = null;
    });
    await _store.selectAccount(acguid);
    await _loadUsage();
  }

  Future<void> _selectPreset(UsageRangePreset preset) async {
    if (preset == _preset) return;
    setState(() {
      _preset = preset;
      _highlighted = null;
      // 清掉上一个区间的数字，避免加载失败时指标与区间名对不上。
      _records = const [];
      _summary = UsageSummary.empty;
      _error = null;
    });
    await _loadUsage();
  }

  Future<void> _openAccountPicker() async {
    final selected = await showElectricityAccountPicker(
      context: context,
      api: _api,
      store: _store,
      selectedId: _selectedId,
    );
    final accounts = await _store.loadAccounts();
    final resolved = ElectricityHistoryStore.resolveSelectedId(
      accounts,
      selected ?? _selectedId,
    );
    if (!mounted) return;
    final changed = resolved != _selectedId;
    setState(() {
      _accounts = accounts;
      if (!changed) _selectedId = resolved;
    });
    if (changed) {
      if (resolved == null) {
        setState(() {
          _selectedId = null;
          _records = const [];
          _summary = UsageSummary.empty;
          _highlighted = null;
          _error = null;
        });
      } else {
        await _selectAccount(resolved);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return GlassScaffold(
      title: '用电历史',
      backgroundColor: scheme.surface,
      actions: [
        GlassControlButton(
          icon: Icons.refresh_rounded,
          tooltip: '刷新',
          semanticLabel: '刷新',
          onTap: _booting || _loading ? null : () => _loadUsage(force: true),
        ),
      ],
      body: RefreshIndicator(
        onRefresh: () => _loadUsage(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            glassTopInset(context) + 8,
            16,
            32,
          ),
          children: _buildChildren(context, scheme),
        ),
      ),
    );
  }

  List<Widget> _buildChildren(BuildContext context, ColorScheme scheme) {
    if (_booting) {
      return [
        _card(
          scheme,
          child: SizedBox(
            height: 180,
            child: Center(
              child: LoadingAnimationWidget.inkDrop(
                color: scheme.primary,
                size: 34,
              ),
            ),
          ),
        ),
      ];
    }

    if (_accounts.isEmpty) {
      return [_buildNoAccountCard(context, scheme)];
    }

    return [
      _buildAccountCard(context, scheme),
      const SizedBox(height: 12),
      _buildAccountSwitcher(context, scheme),
      const SizedBox(height: 12),
      GlassSegmented<UsageRangePreset>(
        segments: [
          for (final preset in UsageRangePreset.values)
            GlassSegment<UsageRangePreset>(
              value: preset,
              label: preset.label,
            ),
        ],
        selected: _preset,
        expand: true,
        height: 36,
        onChanged: _selectPreset,
      ),
      const SizedBox(height: 12),
      _buildKpiRow(scheme),
      const SizedBox(height: 12),
      if (_error != null)
        _buildErrorCard(context, scheme)
      else if (_loading && _records.isEmpty)
        _card(
          scheme,
          child: SizedBox(
            height: 200,
            child: Center(
              child: LoadingAnimationWidget.inkDrop(
                color: scheme.primary,
                size: 34,
              ),
            ),
          ),
        )
      else ...[
        UsageChartCard(
          records: _records,
          metric: _metric,
          onMetricChanged: (metric) => setState(() => _metric = metric),
          highlightedDate: _highlighted,
        ),
        const SizedBox(height: 12),
        UsageTableCard(
          records: sortUsageDesc(_records),
          highlightedDate: _highlighted,
          onSelect: (record) {
            setState(() {
              _highlighted =
                  _highlighted?.isAtSameMomentAs(record.statTime) == true
                      ? null
                      : record.statTime;
            });
          },
        ),
      ],
    ];
  }

  // ---------------------------------------------------------------------------
  // 顶部账户区
  // ---------------------------------------------------------------------------

  Widget _buildNoAccountCard(BuildContext context, ColorScheme scheme) {
    return _card(
      scheme,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.electric_meter_outlined,
              color: scheme.onPrimaryContainer,
              size: 22,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '绑定宿舍账户',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '绑定后可以查看每天的用电量、消费与余额变化，下次进入无需重新搜索。',
            style: TextStyle(
              fontSize: 13,
              height: 1.55,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _openAccountPicker,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('搜索宿舍账户'),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountCard(BuildContext context, ColorScheme scheme) {
    final account = _currentAccount;
    if (account == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  account.name.isEmpty ? account.acid : account.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openAccountPicker,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: scheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                child: const Text('更换'),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                _balance.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 34,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'CNY',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w300,
                    color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '单价 ¥${account.price.toStringAsFixed(4)}/kWh · 账户 ${account.acid}',
            style: TextStyle(
              fontSize: 11.5,
              color: scheme.onPrimaryContainer.withValues(alpha: 0.75),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountSwitcher(BuildContext context, ColorScheme scheme) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _accounts.length + 1,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == _accounts.length) {
            return _SwitcherChip(
              scheme: scheme,
              selected: false,
              dashed: true,
              label: '添加',
              icon: Icons.add_rounded,
              onTap: _openAccountPicker,
            );
          }
          final account = _accounts[index];
          return _SwitcherChip(
            scheme: scheme,
            selected: account.acguid == _selectedId,
            label: account.name.isEmpty ? account.acid : account.name,
            onTap: () => _selectAccount(account.acguid),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 指标与状态
  // ---------------------------------------------------------------------------

  Widget _buildKpiRow(ColorScheme scheme) {
    final hasData = _summary.days > 0;
    return Row(
      children: [
        Expanded(
          child: _kpi(
            scheme,
            label: '用电量',
            value: hasData ? _summary.totalKwh.toStringAsFixed(1) : '-',
            unit: 'kWh',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpi(
            scheme,
            label: '消费',
            value: hasData ? '¥${_summary.totalCost.toStringAsFixed(2)}' : '-',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _kpi(
            scheme,
            label: '日均用电',
            value: hasData ? _summary.avgKwh.toStringAsFixed(2) : '-',
            unit: 'kWh',
          ),
        ),
      ],
    );
  }

  Widget _kpi(
    ColorScheme scheme, {
    required String label,
    required String value,
    String? unit,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              if (unit != null)
                Padding(
                  padding: const EdgeInsets.only(left: 3, bottom: 2),
                  child: Text(
                    unit,
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(BuildContext context, ColorScheme scheme) {
    final isAuth = _error?.contains('登录') ?? false;
    return _card(
      scheme,
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: scheme.errorContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isAuth ? Icons.lock_outline_rounded : Icons.cloud_off_rounded,
              color: scheme.onErrorContainer,
              size: 26,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            isAuth ? '登录状态已失效' : '暂时无法加载',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            _error ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.55,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed:
                  _loading ? null : () => _loadUsage(force: true),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('重试'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(ColorScheme scheme, {required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: child,
    );
  }
}

class _SwitcherChip extends StatelessWidget {
  const _SwitcherChip({
    required this.scheme,
    required this.selected,
    required this.label,
    required this.onTap,
    this.icon,
    this.dashed = false,
  });

  final ColorScheme scheme;
  final bool selected;
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final foreground =
        selected ? scheme.onSecondaryContainer : scheme.onSurfaceVariant;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(maxWidth: 180, minWidth: 54),
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color:
                selected
                    ? scheme.secondaryContainer
                    : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(19),
            border:
                dashed
                    ? Border.all(
                      color: scheme.outlineVariant,
                      width: 1,
                      style: BorderStyle.solid,
                    )
                    : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: foreground),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight:
                        selected ? FontWeight.w600 : FontWeight.w500,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageCache {
  const _UsageCache(this.records, this.createdAt);

  final List<UsageRecord> records;
  final DateTime createdAt;
}
