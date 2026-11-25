import 'dart:async';

import 'package:chucker_flutter_plus/src/config/theme/inspector_colors.dart';
import 'package:chucker_flutter_plus/src/core/core.dart';
import 'package:flutter/material.dart';

import '../../../../config/dependency_injection/chucker_dependencies.dart';
import '../../domain/entities/network_transaction.dart';
import '../chucker_flutter.dart';
import '../widgets/empty_state.dart';
import '../widgets/method_chip.dart';
import '../widgets/status_badge.dart';
import '../widgets/share_text.dart';
import '../widgets/summary_header.dart';

// ── Sort options ────────────────────────────────────────────────────────────

enum _SortMode { newest, slowest, largest }

// ── Main list page ──────────────────────────────────────────────────────────

class NetworkInspectorPage extends StatefulWidget {
  const NetworkInspectorPage({
    required this.dependencies,
    this.initiallySelectedId,
    this.onClose,
    super.key,
  });
  final ChuckerDependencies dependencies;
  final String? initiallySelectedId;
  final VoidCallback? onClose;

  @override
  State<NetworkInspectorPage> createState() => _NetworkInspectorPageState();
}

class _NetworkInspectorPageState extends State<NetworkInspectorPage> {
  late Future<List<NetworkTransaction>> _future;
  final _searchCtrl = TextEditingController();
  String _query = '';
  String _methodFilter = AppStrings.filterAll;
  String _statusFilter =
      AppStrings.filterAll; // 'All', '2', '3', '4', '5', 'Error'
  bool _errorsOnly = false;
  _SortMode _sort = _SortMode.newest;
  bool _openedInitial = false;
  final Set<String> _selected = {};
  bool _selectMode = false;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _future = widget.dependencies.transactions.getAll();
    widget.dependencies.transactions.changes.addListener(_scheduleReload);
  }

  @override
  void dispose() {
    widget.dependencies.transactions.changes.removeListener(_scheduleReload);
    _refreshTimer?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _scheduleReload() {
    _refreshTimer ??= Timer(const Duration(milliseconds: 250), () {
      _refreshTimer = null;
      _reload();
    });
  }

  void _reload() =>
      setState(() => _future = widget.dependencies.transactions.getAll());

  Future<void> _clearAll() async {
    final ok = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text(AppStrings.clearLogsTitle),
        content: const Text(AppStrings.clearLogsMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text(AppStrings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text(AppStrings.clearAll),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _changeHistory(widget.dependencies.transactions.clear);
  }

  Future<void> _changeHistory(Future<void> Function() change) async {
    try {
      await change();
      if (!mounted) return;
      _selected.clear();
      _selectMode = false;
      _reload();
    } catch (_) {
      if (mounted) context.errorSnackBar('Unable to update request history');
    }
  }

  List<NetworkTransaction> _filter(List<NetworkTransaction> all) {
    final q = _query.trim().toLowerCase();
    final list = all.where((t) {
      final matchesQuery =
          q.isEmpty ||
          t.uri.toString().toLowerCase().contains(q) ||
          t.method.toLowerCase().contains(q) ||
          '${t.statusCode ?? ''}'.contains(q) ||
          (t.error?.toLowerCase().contains(q) ?? false) ||
          (t.rawResponseBody?.toLowerCase().contains(q) ?? false);
      final matchesMethod =
          _methodFilter == AppStrings.filterAll || t.method == _methodFilter;
      final matchesStatus =
          _statusFilter == AppStrings.filterAll ||
          (_statusFilter == AppStrings.filterError && t.error != null) ||
          '${t.statusCode ?? 0}'.startsWith(_statusFilter);
      final matchesErrors = !_errorsOnly || !t.succeeded;
      return matchesQuery && matchesMethod && matchesStatus && matchesErrors;
    }).toList();

    return switch (_sort) {
      _SortMode.newest =>
        list..sort((a, b) => b.startedAt.compareTo(a.startedAt)),
      _SortMode.slowest =>
        list..sort((a, b) => b.duration.compareTo(a.duration)),
      _SortMode.largest =>
        list..sort((a, b) => b.responseBodySize.compareTo(a.responseBodySize)),
    };
  }

  void _openDetail(BuildContext context, NetworkTransaction t) {
    context.pushNamed(Routes.requestDetail, arguments: t);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectMode ? _selectAppBar() : _normalAppBar(),
      body: FutureBuilder<List<NetworkTransaction>>(
        future: _future,
        builder: (context, snapshot) {
          final all = snapshot.data ?? const <NetworkTransaction>[];

          final loading = snapshot.connectionState != ConnectionState.done;
          final requestedId = widget.initiallySelectedId;
          if (!_openedInitial &&
              !loading &&
              !snapshot.hasError &&
              requestedId != null) {
            _openedInitial = true;
            final match = all.where((t) => t.id == requestedId).firstOrNull;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              if (match != null) {
                _openDetail(context, match);
              } else {
                context.errorSnackBar('This request is no longer in history');
              }
            });
          }

          final filtered = _filter(all);
          return CustomScrollView(
            slivers: [
              if (all.isNotEmpty)
                SliverToBoxAdapter(child: SummaryHeader(transactions: all)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search, size: 20),
                      labelText: 'Search requests',
                      hintText: 'URL, method, status, error or response body',
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              tooltip: 'Clear search',
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: _FiltersRow(
                  all: all,
                  methodFilter: _methodFilter,
                  statusFilter: _statusFilter,
                  errorsOnly: _errorsOnly,
                  sort: _sort,
                  onMethodChanged: (v) => setState(() => _methodFilter = v),
                  onStatusChanged: (v) => setState(() => _statusFilter = v),
                  onErrorsOnlyChanged: (v) => setState(() => _errorsOnly = v),
                  onSortChanged: (v) => setState(() => _sort = v),
                ),
              ),
              if (snapshot.hasError)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: TextButton(
                      onPressed: _reload,
                      child: const Text('Unable to load history. Retry'),
                    ),
                  ),
                )
              else if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: loading
                      ? const Center(child: CircularProgressIndicator())
                      : EmptyState(filtered: all.isNotEmpty),
                )
              else
                SliverList.builder(
                  itemCount: filtered.length,
                  itemBuilder: (_, index) {
                    final transaction = filtered[index];
                    return _TransactionTile(
                      key: ValueKey(transaction.id),
                      transaction: transaction,
                      selected: _selected.contains(transaction.id),
                      selectMode: _selectMode,
                      onTap: () {
                        if (!_selectMode) {
                          _openDetail(context, transaction);
                          return;
                        }
                        setState(() {
                          if (!_selected.add(transaction.id)) {
                            _selected.remove(transaction.id);
                          }
                          if (_selected.isEmpty) _selectMode = false;
                        });
                      },
                      onLongPress: () => setState(() {
                        _selectMode = true;
                        _selected.add(transaction.id);
                      }),
                    );
                  },
                ),
            ],
          );
        },
      ),
    );
  }

  AppBar _normalAppBar() => AppBar(
    leading: widget.onClose != null
        ? IconButton(
            icon: const Icon(Icons.close),
            tooltip: AppStrings.close,
            onPressed: widget.onClose,
          )
        : null,
    title: const Text(AppStrings.networkInspectorTitle),
    actions: [
      IconButton(
        icon: const Icon(Icons.refresh_rounded),
        tooltip: AppStrings.refresh,
        onPressed: _reload,
      ),
      PopupMenuButton<String>(
        icon: const Icon(Icons.more_vert),
        tooltip: AppStrings.moreOptions,
        itemBuilder: (_) => [
          const PopupMenuItem(
            value: 'settings',
            child: Text(AppStrings.settings),
          ),
          const PopupMenuItem(
            value: 'export',
            child: Text(AppStrings.exportLogs),
          ),
          const PopupMenuItem(
            value: 'clear',
            child: Text(
              AppStrings.clearAll,
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
        onSelected: (v) async {
          if (v == 'settings') {
            context.pushNamed(Routes.settings);
          } else if (v == 'export') {
            try {
              final json = await ChuckerFlutterPlus.exportLogs();
              if (mounted) await shareInspectorText(context, json);
            } catch (_) {
              if (mounted) {
                context.errorSnackBar('Unable to export history');
              }
            }
          } else if (v == 'clear') {
            await _clearAll();
          }
        },
      ),
    ],
  );

  AppBar _selectAppBar() => AppBar(
    leading: IconButton(
      icon: const Icon(Icons.close),
      tooltip: 'Exit selection',
      onPressed: () => setState(() {
        _selectMode = false;
        _selected.clear();
      }),
    ),
    title: Text('${_selected.length} selected'),
    actions: [
      IconButton(
        icon: const Icon(Icons.delete_outline),
        tooltip: AppStrings.deleteSelected,
        onPressed: () => _changeHistory(
          () => widget.dependencies.transactions.delete(Set.of(_selected)),
        ),
      ),
    ],
  );
}

// ── Filters row ─────────────────────────────────────────────────────────────

class _FiltersRow extends StatelessWidget {
  const _FiltersRow({
    required this.all,
    required this.methodFilter,
    required this.statusFilter,
    required this.errorsOnly,
    required this.sort,
    required this.onMethodChanged,
    required this.onStatusChanged,
    required this.onErrorsOnlyChanged,
    required this.onSortChanged,
  });
  final List<NetworkTransaction> all;
  final String methodFilter, statusFilter;
  final bool errorsOnly;
  final _SortMode sort;
  final ValueChanged<String> onMethodChanged, onStatusChanged;
  final ValueChanged<bool> onErrorsOnlyChanged;
  final ValueChanged<_SortMode> onSortChanged;

  @override
  Widget build(BuildContext context) {
    final methods = {AppStrings.filterAll, ...all.map((t) => t.method)};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSizes.paddingMd,
        vertical: AppSizes.paddingSm,
      ),
      child: Row(
        children: [
          // Method chips
          ...methods.map(
            (m) => Padding(
              padding: const EdgeInsets.only(right: AppSizes.gap6),
              child: _FilterChip(
                label: m,
                selected: methodFilter == m,
                color: m == AppStrings.filterAll
                    ? null
                    : InspectorColors.methodColor(m),
                onSelected: () => onMethodChanged(m),
              ),
            ),
          ),
          const SizedBox(width: AppSizes.gap4),
          // Status group chips
          ...[
            (AppStrings.filterAll, null),
            ('2xx', InspectorColors.status2xx),
            ('3xx', InspectorColors.status3xx),
            ('4xx', InspectorColors.status4xx),
            ('5xx', InspectorColors.status5xx),
          ].map((entry) {
            final label = entry.$1;
            final color = entry.$2;
            final key = label == AppStrings.filterAll
                ? AppStrings.filterAll
                : label[0];
            return Padding(
              padding: const EdgeInsets.only(right: AppSizes.gap6),
              child: _FilterChip(
                label: label,
                selected: statusFilter == key,
                color: color,
                onSelected: () => onStatusChanged(key),
              ),
            );
          }),
          const SizedBox(width: AppSizes.gap4),
          // Errors only toggle
          Padding(
            padding: const EdgeInsets.only(right: AppSizes.gap6),
            child: _FilterChip(
              label: AppStrings.filterErrorsOnly,
              selected: errorsOnly,
              color: InspectorColors.statusError,
              icon: Icons.error_outline,
              onSelected: () => onErrorsOnlyChanged(!errorsOnly),
            ),
          ),
          const SizedBox(width: AppSizes.gap4),
          // Sort
          _SortChip(current: sort, onChanged: onSortChanged),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
    this.color,
    this.icon,
  });
  final String label;
  final bool selected;
  final Color? color;
  final IconData? icon;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = color ?? theme.colorScheme.primary;
    return GestureDetector(
      onTap: onSelected,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingSm + 2,
          vertical: AppSizes.paddingXs + 1,
        ),
        decoration: BoxDecoration(
          color: selected
              ? c.withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? c : theme.colorScheme.outlineVariant,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 13,
                color: selected ? c : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                color: selected ? c : theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({required this.current, required this.onChanged});
  final _SortMode current;
  final ValueChanged<_SortMode> onChanged;

  String get _label => switch (current) {
    _SortMode.newest => AppStrings.sortNewest,
    _SortMode.slowest => AppStrings.sortSlowest,
    _SortMode.largest => AppStrings.sortLargest,
  };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopupMenuButton<_SortMode>(
      initialValue: current,
      onSelected: onChanged,
      itemBuilder: (_) => [
        const PopupMenuItem(
          value: _SortMode.newest,
          child: Text(AppStrings.newestFirst),
        ),
        const PopupMenuItem(
          value: _SortMode.slowest,
          child: Text(AppStrings.slowestFirst),
        ),
        const PopupMenuItem(
          value: _SortMode.largest,
          child: Text(AppStrings.largestFirst),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSizes.paddingMd - 2,
          vertical: 5,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort, size: AppSizes.iconXs + 3),
            const SizedBox(width: AppSizes.gap4),
            Text(
              _label,
              style: const TextStyle(
                fontSize: AppSizes.textMd,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: AppSizes.gap2),
            const Icon(Icons.arrow_drop_down, size: AppSizes.iconMd),
          ],
        ),
      ),
    );
  }
}

// ── Transaction tile ─────────────────────────────────────────────────────────

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.onTap,
    required this.onLongPress,
    super.key,
    this.selected = false,
    this.selectMode = false,
  });
  final NetworkTransaction transaction;
  final VoidCallback onTap, onLongPress;
  final bool selected, selectMode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = transaction;

    return Semantics(
      selected: selectMode ? selected : null,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Container(
          color: selected ? theme.colorScheme.primaryContainer : null,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 4,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  if (selectMode)
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                    ),
                  MethodChip(t.method),
                  StatusBadge(t.statusCode, error: t.error),
                  Text(_formatDuration(t.duration)),
                  if (t.responseBodySize > 0)
                    Text(_sizeStr(t.responseBodySize)),
                  Text(_relativeTime(t.startedAt)),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                t.uri.path.isEmpty ? '/' : t.uri.path,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall,
              ),
              Text(
                t.error == null ? t.host : '${t.host} · ${t.error}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds >= 1) {
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    }
    return '${d.inMilliseconds}ms';
  }

  String _relativeTime(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  static String _sizeStr(int bytes) => bytes < 1024
      ? '$bytes B'
      : bytes < 1024 * 1024
      ? '${(bytes / 1024).toStringAsFixed(1)} KB'
      : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
