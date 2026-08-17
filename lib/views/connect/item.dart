import 'package:fl_clash/common/common.dart';
import 'package:fl_clash/enum/enum.dart';
import 'package:fl_clash/hgfast/models/node.dart';
import 'package:fl_clash/widgets/widgets.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'hero.dart';

class NodeItem extends StatelessWidget {
  final NodeSpec node;

  const NodeItem({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    final colorScheme = context.colorScheme;
    final subtitle = node.rate == '1'
        ? node.routeLabel
        : '${node.routeLabel} · ${node.rate}x';
    final isPremium = node.category != NodeCategory.standard;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: CommonCard(
        type: CommonCardType.filled,
        onPressed: null,
        radius: hgCardRadius,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: hgGradientStart.withValues(alpha: 0.18),
              child: const Icon(Icons.public, size: 18, color: hgGradientStart),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    node.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isPremium) ...[
              const SizedBox(width: 8),
              _CategoryBadge(category: node.category),
            ],
          ],
        ),
      ),
    );
  }
}

class _CategoryBadge extends StatelessWidget {
  final NodeCategory category;

  const _CategoryBadge({required this.category});

  @override
  Widget build(BuildContext context) {
    final isVip = category == NodeCategory.vip;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: isVip ? hgBrandGradient : null,
        color: isVip ? null : hgGradientStart.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(hgPillRadius),
      ),
      child: Text(
        Intl.message(category.name),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isVip ? Colors.white : hgGradientStart,
        ),
      ),
    );
  }
}
