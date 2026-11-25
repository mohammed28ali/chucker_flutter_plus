import 'package:flutter/material.dart';

import '../../../../config/theme/inspector_colors.dart';
import '../../../../core/core.dart';
import '../../domain/entities/network_transaction.dart';
import 'method_chip.dart';

/// Compact dashboard metrics for the captured request history.
class SummaryHeader extends StatelessWidget {
  const SummaryHeader({super.key, required this.transactions});
  final List<NetworkTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) return const SizedBox.shrink();
    final total = transactions.length;
    final successes = transactions.where((t) => t.succeeded).length;
    final errors = total - successes;
    final average =
        transactions
            .map((t) => t.duration.inMilliseconds)
            .fold<int>(0, (sum, ms) => sum + ms) ~/
        total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 420;
          final items = [
            _Metric(
              'Total',
              '$total',
              Icons.swap_vert_rounded,
              InspectorColors.primary,
            ),
            _Metric(
              'Successful',
              '$successes',
              Icons.check_circle_outline,
              InspectorColors.success,
            ),
            _Metric(
              'Failed',
              '$errors',
              Icons.error_outline,
              InspectorColors.error,
            ),
            _Metric(
              'Avg. latency',
              '${average}ms',
              Icons.bolt_outlined,
              InspectorColors.secondary,
            ),
          ];
          return GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: compact ? 2 : 4,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: 66,
            ),
            itemBuilder: (context, index) => _MetricCard(metric: items[index]),
          );
        },
      ),
    );
  }
}

class _Metric {
  const _Metric(this.label, this.value, this.icon, this.color);
  final String label;
  final String value;
  final IconData icon;
  final Color color;
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.metric});
  final _Metric metric;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: metric.color.withValues(alpha: 0.11),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(metric.icon, color: metric.color, size: 17),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  metric.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The method + status breakdown bar shown below the summary.
class MethodBreakdownRow extends StatelessWidget {
  const MethodBreakdownRow({super.key, required this.transactions});
  final List<NetworkTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final methods = <String, int>{};
    for (final t in transactions) {
      methods[t.method] = (methods[t.method] ?? 0) + 1;
    }
    if (methods.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSizes.paddingLg,
        AppSizes.gap8,
        AppSizes.paddingLg,
        0,
      ),
      child: Wrap(
        spacing: AppSizes.gap6,
        runSpacing: AppSizes.gap4,
        children: methods.entries
            .map(
              (e) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  MethodChip(e.key, small: true),
                  const SizedBox(width: AppSizes.gap4),
                  AppText.caption(
                    '${e.value}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            )
            .toList(),
      ),
    );
  }
}
